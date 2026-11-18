<script setup lang="ts">
import { Check, Pencil, X } from 'lucide-vue-next'
import { placeOf, type AdminEvent } from '~/utils/admin-events'
import { dayLabel, timeLabel } from '~/utils/admin-madrid'

/** Rows of the Por aprobar inbox: checkbox, day block, title, place · time and chips. One button per row opens the detail. */
const props = defineProps<{ events: readonly AdminEvent[]; selectedId?: string; checked: readonly string[]; busy: boolean }>()
const emit = defineEmits<{ open: [id: string]; toggle: [id: string, value: boolean]; toggleAll: [value: boolean]; approve: [event: AdminEvent]; edit: [event: AdminEvent]; reject: [event: AdminEvent, reason: string | null] }>()
const allChecked = computed<boolean | 'indeterminate'>(() => (props.checked.length === 0 ? false : props.checked.length === props.events.length ? true : 'indeterminate'))
</script>

<template>
  <div>
    <p class="flex items-center gap-3 border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta">
      <AdminCheckbox :model-value="allChecked" label="Seleccionar todos los de la vista" @update:model-value="(v) => emit('toggleAll', v === true)" />
      Por fecha del evento · los que ya han pasado, al final
    </p>
    <ul class="divide-y divide-adm-line" aria-label="Eventos por aprobar">
      <li
        v-for="e in events"
        :key="e.id"
        :class="['relative', selectedId === e.id && 'bg-adm-acc-soft before:absolute before:inset-y-0 before:left-0 before:w-0.5 before:bg-adm-acc']"
      >
        <div class="flex gap-3 px-4 py-3">
          <AdminCheckbox class="mt-1" :model-value="checked.includes(e.id)" :label="`Seleccionar «${e.titleEs}»`" @update:model-value="(v) => emit('toggle', e.id, v === true)" />
          <button
            type="button"
            :data-event="e.id"
            :aria-current="selectedId === e.id ? 'true' : undefined"
            :class="['flex min-w-0 flex-1 gap-3 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc', e.isPast && 'opacity-70']"
            @click="emit('open', e.id)"
          >
            <AdminEventsDateBlock :iso="e.startsAt" />
            <span class="min-w-0 flex-1">
              <span class="line-clamp-2 block text-sm leading-5 font-medium">{{ e.titleEs }}</span>
              <span class="mt-0.5 block truncate text-xs text-adm-meta">
                <span class="sr-only">{{ dayLabel(e.startsAt) }}. </span>{{ placeOf(e) || 'Sin lugar' }} · <span class="tabular-nums">{{ timeLabel(e) }}</span>
              </span>
              <span class="mt-1.5 flex flex-wrap items-center gap-1.5">
                <AdminEventsOrigin :source="e.source" short />
                <AdminEventsConfidence v-if="e.agent" :value="e.agent.confidence" />
                <AdminEventsFlags :event="e" />
                <AdminEventsLang :has="e.hasEn" />
              </span>
            </span>
          </button>
        </div>
        <p v-if="e.sourceUrl" class="-mt-1 flex flex-wrap items-center gap-x-3 pr-4 pb-2 pl-[100px]">
          <AdminEventsSource :url="e.sourceUrl" :title="e.titleEs" />
          <span v-if="collectedAt(e)" class="text-xs text-adm-meta">Recogida {{ runDay(collectedAt(e)!) }}</span>
        </p>
        <div class="flex gap-2 pr-4 pb-3 pl-[44px] lg:hidden">
          <AdminEventsRejectMenu v-if="e.isPast" :agent="e.source === 'agent'" @select="(reason) => emit('reject', e, reason)">
            <button type="button" :class="[admBtnGhost, 'flex-1']" :disabled="busy"><X aria-hidden="true" />Descartar</button>
          </AdminEventsRejectMenu>
          <template v-else>
            <button type="button" :class="[admBtnGhost, 'flex-1']" :disabled="busy" @click="emit('approve', e)"><Check aria-hidden="true" />Aprobar</button>
            <button type="button" :class="[admBtnGhost, 'flex-1']" @click="emit('edit', e)"><Pencil aria-hidden="true" />Editar</button>
            <AdminEventsRejectMenu :agent="e.source === 'agent'" align="end" @select="(reason) => emit('reject', e, reason)">
              <button type="button" :class="[admBtnGhost, 'max-md:w-11 md:size-8 md:px-0']" :disabled="busy" :aria-label="`Descartar «${e.titleEs}»`"><X aria-hidden="true" /></button>
            </AdminEventsRejectMenu>
          </template>
        </div>
      </li>
    </ul>
    <p class="flex gap-2 border-t border-adm-line px-4 py-3 text-xs text-adm-meta">
      Nada sale en el sitio sin tu aprobación. El agente recoge lunes y jueves. Lo que descartas no vuelve a proponerlo.
    </p>
  </div>
</template>
