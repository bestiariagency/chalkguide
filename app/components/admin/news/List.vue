<script setup lang="ts">
import { Check, Pencil, X } from 'lucide-vue-next'
import { scopeLabel, type AdminNews } from '~/utils/admin-news'

/**
 * Rows of the Por revisar inbox: checkbox, title (2 lines), «Fuente: X · fecha · categoría» and chips. One button per row opens
 * the detail. Under 1024 each row also carries Aprobar, Editar and Rechazar (44 px). Everything the agent wrote is interpolated.
 */
const props = defineProps<{ rows: readonly AdminNews[]; selectedId?: string; checked: readonly string[]; busy: boolean; labels: Record<string, string> }>()
const emit = defineEmits<{ open: [id: string]; toggle: [id: string, value: boolean]; toggleAll: [value: boolean]; approve: [news: AdminNews]; edit: [news: AdminNews]; reject: [news: AdminNews, reason: string | null] }>()
const allChecked = computed<boolean | 'indeterminate'>(() => (props.checked.length === 0 ? false : props.checked.length === props.rows.length ? true : 'indeterminate'))
const dateOf = (n: AdminNews) => (n.sourcePublishedOn ? adminDate(n.sourcePublishedOn) : 'sin fecha')
</script>

<template>
  <div>
    <p class="flex items-center gap-3 border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta">
      <AdminCheckbox :model-value="allChecked" label="Seleccionar todas las de la vista" @update:model-value="(v) => emit('toggleAll', v === true)" />
      Más recientes arriba · la fecha es la de la fuente
    </p>
    <ul class="divide-y divide-adm-line" aria-label="Noticias por revisar">
      <li v-for="n in rows" :key="n.id" :class="['relative', selectedId === n.id && 'bg-adm-acc-soft before:absolute before:inset-y-0 before:left-0 before:w-0.5 before:bg-adm-acc']">
        <div class="flex gap-3 px-4 py-3">
          <AdminCheckbox class="mt-1" :model-value="checked.includes(n.id)" :label="`Seleccionar «${n.titleEs}»`" @update:model-value="(v) => emit('toggle', n.id, v === true)" />
          <button
            type="button"
            :data-news="n.id"
            :aria-current="selectedId === n.id ? 'true' : undefined"
            class="min-w-0 flex-1 text-left focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc"
            @click="emit('open', n.id)"
          >
            <span class="line-clamp-2 block text-sm leading-5 font-medium">{{ n.titleEs }}</span>
            <span class="mt-0.5 block truncate text-xs text-adm-meta">Fuente: <span class="text-adm-fg">{{ n.sourceName }}</span> · {{ dateOf(n) }} · {{ labels[n.categoryKey] ?? n.categoryKey }}</span>
            <span class="mt-1.5 flex flex-wrap items-center gap-1.5">
              <AdminNewsOrigin :source="n.source" short />
              <span :class="[admChip, 'bg-adm-subtle text-adm-meta']">{{ scopeLabel(n.scope) }}</span>
              <AdminEventsConfidence v-if="n.agent" :value="n.agent.confidence" />
              <AdminNewsFlags :news="n" />
              <AdminNewsLang :has="n.hasEn" />
            </span>
          </button>
        </div>
        <div class="flex gap-2 pr-4 pb-3 pl-[44px] lg:hidden">
          <button type="button" :class="[admBtnGhost, 'flex-1']" :disabled="busy" @click="emit('approve', n)"><Check aria-hidden="true" />Aprobar</button>
          <button type="button" :class="[admBtnGhost, 'flex-1']" @click="emit('edit', n)"><Pencil aria-hidden="true" />Editar</button>
          <AdminNewsRejectMenu :agent="n.source === 'agent'" align="end" @select="(reason) => emit('reject', n, reason)">
            <button type="button" :class="[admBtnGhost, 'max-md:w-11 md:size-8 md:px-0']" :disabled="busy" :aria-label="`Rechazar «${n.titleEs}»`"><X aria-hidden="true" /></button>
          </AdminNewsRejectMenu>
        </div>
      </li>
    </ul>
    <p class="flex gap-2 border-t border-adm-line px-4 py-3 text-xs text-adm-meta">
      Nada sale en el sitio sin tu aprobación. El agente recoge lunes y jueves; lo que rechazas no vuelve a proponerlo.
    </p>
  </div>
</template>
