<script setup lang="ts">
import { CalendarX, ChevronLeft, ChevronRight } from 'lucide-vue-next'
import type { CalendarDay, CalendarItem, CalendarKind, CalendarView } from '~/utils/admin-dashboard-calendar'
import type { LastPublished } from '~/services/admin/dashboard'

/** Editorial calendar (README §14.4): 2 weeks by default or the month, from 768 px; a list of days with something on phones. */
const props = defineProps<{
  view: CalendarView
  /** Range («2–15 nov 2026») or month title. */
  title: string
  lastPublished: LastPublished | null
  drafts: number
  grid: CalendarDay[]
  upcoming: CalendarDay[]
  loading: boolean
  failed: boolean
}>()
defineEmits<{ prev: []; next: []; retry: []; 'update:view': [CalendarView] }>()

const showAgenda = ref<boolean | 'indeterminate'>(true)
const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom']
const tones: Record<CalendarKind, string> = {
  pub: 'bg-adm-st-pub-bg text-adm-st-pub',
  sched: 'bg-adm-st-sched-bg text-adm-st-sched',
  rev: 'bg-adm-st-rev-bg text-adm-st-rev',
  agenda: 'text-adm-meta shadow-[inset_0_0_0_1px_var(--adm-line-strong)]',
  'agenda-todo': 'text-adm-warn shadow-[inset_0_0_0_1px_var(--adm-warn-icon)]',
}
const kindLabels: Record<CalendarKind, string> = {
  pub: 'Publicado',
  sched: 'Programado',
  rev: 'Publicado con cambios',
  agenda: 'Agenda',
  'agenda-todo': 'Agenda, por aprobar',
}
const legend: { kind: CalendarKind; label: string }[] = [
  { kind: 'pub', label: 'Publicado' },
  { kind: 'sched', label: 'Programado' },
  { kind: 'rev', label: 'Con cambios' },
  { kind: 'agenda', label: 'Agenda' },
]
const visible = (items: CalendarItem[]) => items.filter((i) => showAgenda.value !== false || !i.kind.startsWith('agenda'))
const dayLabel = (d: CalendarDay) => `${formatDayLong(d.key)}${d.today ? ', hoy' : ''}`
const hasAnyItems = computed(() => props.grid.some((d) => !d.outside && visible(d.items).length))
const listEmpty = computed(() => !props.upcoming.some((d) => visible(d.items).length))
const emptyWindow = computed(() => !props.loading && props.view === '2w' && !hasAnyItems.value)
const emptyContext = computed(() => {
  const last = props.lastPublished ? `Último publicado: «${props.lastPublished.title}», ${shortDate(props.lastPublished.publishedAt)}.` : ''
  const drafts = props.drafts ? `Tienes ${props.drafts} ${props.drafts === 1 ? 'borrador' : 'borradores'}.` : ''
  return [last, drafts].filter(Boolean).join(' ')
})
const views: { value: CalendarView; label: string }[] = [{ value: '2w', label: '2 semanas' }, { value: 'month', label: 'Mes' }]
const nav = computed(() => (props.view === 'month' ? ['Mes anterior', 'Mes siguiente'] : ['Dos semanas anteriores', 'Dos semanas siguientes']))
const ev = 'mt-1 block overflow-hidden rounded px-[5px] py-[3px] text-xs leading-[15px] break-words focus-visible:outline-2 focus-visible:outline-adm-acc'
</script>

<template>
  <section aria-labelledby="h-cal" :class="[admCard, 'overflow-hidden']">
    <div class="flex min-h-11 flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2">
      <h2 id="h-cal" class="text-sm font-semibold">Calendario editorial</h2>
      <div class="ml-1 flex items-center gap-1">
        <button type="button" :class="admIconBtn" :aria-label="nav[0]" @click="$emit('prev')"><ChevronLeft aria-hidden="true" /></button>
        <span class="text-center text-sm font-medium whitespace-nowrap" aria-live="polite">{{ title }}</span>
        <button type="button" :class="admIconBtn" :aria-label="nav[1]" @click="$emit('next')"><ChevronRight aria-hidden="true" /></button>
      </div>
      <div class="ml-auto flex items-center gap-3">
        <div class="hidden items-center gap-2 text-xs text-adm-meta sm:flex">
          <AdminCheckbox v-model="showAgenda" label="Mostrar la agenda en el calendario" />Agenda
        </div>
        <div role="group" aria-label="Vista del calendario" class="inline-flex rounded-md border border-adm-line-strong p-0.5">
          <button
            v-for="v in views"
            :key="v.value"
            type="button"
            :aria-pressed="view === v.value"
            :class="['h-7 rounded px-2.5 text-xs font-medium max-md:h-10', view === v.value ? 'bg-adm-subtle text-adm-fg' : 'text-adm-meta hover:text-adm-fg']"
            @click="$emit('update:view', v.value)"
          >{{ v.label }}</button>
        </div>
      </div>
    </div>

    <AdminStateBlock v-if="failed" kind="error" title="No se ha podido cargar el calendario" @retry="$emit('retry')" />
    <template v-else>
      <div v-if="emptyWindow" class="hidden min-h-14 items-center gap-3 px-4 py-3 md:flex">
        <CalendarX class="size-5 flex-none text-adm-muted" aria-hidden="true" />
        <div class="min-w-0 flex-1">
          <p class="text-[13px] font-medium">Nada programado en estas dos semanas</p>
          <p v-if="emptyContext" class="text-xs text-adm-meta">{{ emptyContext }}</p>
        </div>
        <NuxtLink :to="`${adminPath('articulos')}?estado=borrador`" :class="admBtnGhost">Programar un borrador</NuxtLink>
      </div>
      <div v-else class="relative hidden md:block" :aria-busy="loading">
        <ol v-if="view === 'month'" class="grid grid-cols-7 border-b border-adm-line bg-adm-side text-xs text-adm-muted" aria-hidden="true">
          <li v-for="w in weekdays" :key="w" class="px-2 py-1.5">{{ w }}</li>
        </ol>
        <ol :class="['grid grid-cols-7', loading && 'opacity-60']" :aria-label="title">
          <li
            v-for="d in grid"
            :key="d.key"
            :class="[view === '2w' ? 'min-h-[88px]' : 'min-h-24', 'border-r border-b border-adm-line p-1.5 [&:nth-child(7n)]:border-r-0', (d.outside || (view === '2w' && d.past)) && 'bg-adm-side']"
          >
            <span v-if="!d.outside" class="sr-only">{{ dayLabel(d) }}</span>
            <span v-if="view === '2w'" :class="['inline-flex h-[22px] items-center rounded-full text-xs tabular-nums', d.today ? 'bg-adm-acc px-2 font-semibold text-white' : 'text-adm-meta']">{{ weekdayDay(d.key) }}</span>
            <span v-else :class="['inline-grid h-[22px] min-w-[22px] place-items-center rounded-full text-xs tabular-nums', d.today ? 'bg-adm-acc font-semibold text-white' : d.outside ? 'text-adm-muted' : 'text-adm-meta']">{{ d.day }}</span>
            <template v-if="!d.outside">
              <NuxtLink v-for="item in visible(d.items)" :key="item.id" :to="item.to" :class="[ev, tones[item.kind]]" :title="item.title">
                <span class="sr-only">{{ kindLabels[item.kind] }}: {{ item.title }}</span>
                <span class="line-clamp-2" aria-hidden="true"><template v-if="item.time">{{ item.time }} </template>{{ item.title }}</span>
              </NuxtLink>
            </template>
          </li>
        </ol>
        <p v-if="!loading && view === 'month' && !hasAnyItems" class="border-t border-adm-line px-4 py-3 text-center text-xs text-adm-meta">Nada publicado ni programado este mes.</p>
      </div>

      <ol class="divide-y divide-adm-line text-sm md:hidden" aria-label="Próximos 14 días" :aria-busy="loading">
        <li v-if="loading && !upcoming.length" class="px-4 py-3 text-adm-meta">Cargando…</li>
        <li v-else-if="listEmpty" class="flex flex-col gap-3 px-4 py-4">
          <p class="flex items-start gap-3"><CalendarX class="mt-0.5 size-5 flex-none text-adm-muted" aria-hidden="true" /><span><span class="block text-[13px] font-medium">Nada programado en estas dos semanas</span><span v-if="emptyContext" class="block text-xs text-adm-meta">{{ emptyContext }}</span></span></p>
          <NuxtLink :to="`${adminPath('articulos')}?estado=borrador`" :class="admBtnGhost">Programar un borrador</NuxtLink>
        </li>
        <li v-for="d in upcoming.filter((x) => visible(x.items).length)" :key="d.key" class="flex gap-3 px-4 py-3">
          <div class="w-10 flex-none text-center">
            <p :class="['text-xs', d.today ? 'text-adm-acc' : 'text-adm-meta']">{{ d.today ? 'hoy' : formatDayLong(d.key).slice(0, 3).toLowerCase() }}</p>
            <p class="text-lg leading-6 font-semibold tabular-nums">{{ d.day }}</p>
          </div>
          <div class="min-w-0 flex-1 space-y-2">
            <div v-for="item in visible(d.items)" :key="item.id">
              <NuxtLink :to="item.to" class="line-clamp-2 font-medium">{{ item.title }}</NuxtLink>
              <p class="mt-1 flex items-center gap-2 text-xs text-adm-meta">
                <span :class="[admChip, tones[item.kind]]">{{ item.time ?? kindLabels[item.kind] }}</span>
                <span v-if="item.meta" class="truncate">{{ item.meta }}</span>
              </p>
            </div>
          </div>
        </li>
      </ol>
    </template>

    <div class="flex flex-wrap items-center gap-x-4 gap-y-1 border-t border-adm-line px-4 py-2.5 text-xs text-adm-meta">
      <span v-for="l in legend" :key="l.kind" class="inline-flex items-center gap-1.5">
        <span :class="['size-2.5 rounded-sm', tones[l.kind]]" aria-hidden="true" />{{ l.label }}
      </span>
      <button v-if="view === '2w'" type="button" class="ml-auto underline underline-offset-2 hover:text-adm-fg max-md:py-3" @click="$emit('update:view', 'month')">Ver el mes</button>
    </div>
  </section>
</template>
