<script setup lang="ts">
import { ChevronLeft, ChevronRight, Plus } from 'lucide-vue-next'
import type { AdminEvent } from '~/utils/admin-events'
import { madridParts, todayMadrid } from '~/utils/admin-madrid'

/**
 * Month view of Próximos (pattern of the Inicio calendar, from 768 px). Approved events have an outline and
 * open the editor; drafts are amber ("· por aprobar") and open the inbox on them; cancelled ones are struck
 * through. The `+` of a day creates an event on that date.
 */
const props = defineProps<{ month: string; events: readonly AdminEvent[]; loading: boolean }>()
const emit = defineEmits<{ prev: []; next: []; today: []; open: [event: AdminEvent]; add: [date: string] }>()
const showDrafts = defineModel<boolean | 'indeterminate'>('showDrafts', { default: true })

const today = todayMadrid()
const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom']
const byDay = computed(() => {
  const map = new Map<string, AdminEvent[]>()
  for (const e of props.events) {
    if (e.status === 'draft' && showDrafts.value === false) continue
    const key = madridParts(e.startsAt).date
    map.set(key, [...(map.get(key) ?? []), e])
  }
  return map
})
const grid = computed(() => buildMonthGrid(props.month, today, new Map()))
const itemClass = (e: AdminEvent) =>
  e.status === 'draft'
    ? 'bg-adm-warn-soft text-adm-warn outline-1 -outline-offset-1 outline-dashed outline-adm-warn-icon'
    : 'bg-adm-elev text-adm-fg shadow-[inset_0_0_0_1px_var(--adm-line-strong)] hover:bg-adm-subtle'
const label = (e: AdminEvent) => `${e.titleEs}${e.status === 'draft' ? ', por aprobar' : e.status === 'cancelled' ? ', cancelado' : ''}`
const time = (e: AdminEvent) => (e.allDay ? '' : madridParts(e.startsAt).time)
const dayText = (key: string) => formatDayLong(key)
const legend = 'inline-flex items-center gap-1.5'
</script>

<template>
  <section class="m-4 overflow-hidden md:m-6" :class="admCard" aria-labelledby="ev-cal-h">
    <div class="flex min-h-11 flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2">
      <h2 id="ev-cal-h" class="sr-only">Calendario de la agenda</h2>
      <div class="flex items-center gap-1">
        <button type="button" :class="admIconBtn" aria-label="Mes anterior" @click="emit('prev')"><ChevronLeft aria-hidden="true" /></button>
        <span class="w-36 text-center text-sm font-medium" aria-live="polite">{{ monthTitle(month) }}</span>
        <button type="button" :class="admIconBtn" aria-label="Mes siguiente" @click="emit('next')"><ChevronRight aria-hidden="true" /></button>
      </div>
      <button type="button" :class="admBtnQuiet" @click="emit('today')">Hoy</button>
      <label class="ml-auto flex items-center gap-2 text-xs text-adm-meta">
        <AdminCheckbox v-model="showDrafts" label="Mostrar por aprobar" />Mostrar por aprobar
      </label>
    </div>

    <div class="relative" :aria-busy="loading">
      <ol class="grid grid-cols-7 border-b border-adm-line bg-adm-side font-mono text-[11px] tracking-[0.1em] text-adm-muted uppercase" aria-hidden="true">
        <li v-for="w in weekdays" :key="w" class="px-2 py-1.5">{{ w }}</li>
      </ol>
      <ol :class="['grid grid-cols-7', loading && 'opacity-60']" :aria-label="monthTitle(month)">
        <li
          v-for="d in grid"
          :key="d.key"
          :class="['group relative min-h-26 min-w-0 border-r border-b border-adm-line p-1.5 [&:nth-child(7n)]:border-r-0', d.outside && 'bg-adm-side']"
          :aria-label="d.outside ? undefined : dayText(d.key)"
        >
          <span :class="['inline-grid h-[22px] min-w-[22px] place-items-center rounded-full text-xs tabular-nums', d.today ? 'bg-adm-acc font-semibold text-white' : d.outside ? 'text-adm-muted' : 'text-adm-meta']">{{ d.day }}</span>
          <button
            v-if="!d.outside && d.key >= today"
            type="button"
            :class="[admIconBtn, 'absolute top-1 right-1 size-6! opacity-0 group-hover:opacity-100 focus-visible:opacity-100 pointer-coarse:opacity-100']"
            :aria-label="`Nuevo evento el ${dayText(d.key)}`"
            @click="emit('add', d.key)"
          ><Plus class="size-3.5!" aria-hidden="true" /></button>
          <template v-if="!d.outside">
            <button
              v-for="e in byDay.get(d.key) ?? []"
              :key="e.id"
              type="button"
              :class="['mt-1 block w-full overflow-hidden rounded px-[5px] py-[3px] text-left text-xs leading-[15px] break-words focus-visible:outline-2 focus-visible:outline-adm-acc', itemClass(e)]"
              :title="e.titleEs"
              :aria-label="label(e)"
              @click="emit('open', e)"
            >
              <span :class="['line-clamp-2', e.status === 'cancelled' && 'line-through']"><span v-if="time(e)" class="tabular-nums">{{ time(e) }}</span><template v-if="time(e)">{{ ' ' }}</template>{{ e.titleEs }}<template v-if="e.status === 'draft'"> · por aprobar</template></span>
            </button>
          </template>
        </li>
      </ol>
    </div>

    <div class="flex flex-wrap items-center gap-x-4 gap-y-1 border-t border-adm-line px-4 py-2.5 text-xs text-adm-meta">
      <span :class="legend"><span class="size-2.5 rounded-sm shadow-[inset_0_0_0_1px_var(--adm-line-strong)]" aria-hidden="true" />En la agenda</span>
      <span :class="legend"><span class="size-2.5 rounded-sm bg-adm-warn-soft outline-1 -outline-offset-1 outline-adm-warn-icon" aria-hidden="true" />Por aprobar</span>
      <span :class="legend"><span class="grid size-2.5 place-items-center rounded-sm shadow-[inset_0_0_0_1px_var(--adm-line-strong)]" aria-hidden="true"><span class="h-px w-2 bg-adm-meta" /></span><span class="line-through">Cancelado</span></span>
      <span class="ml-auto">Clic en un evento para editarlo · <span :class="admKbd">+</span> en un día crea uno con esa fecha</span>
    </div>
  </section>
</template>
