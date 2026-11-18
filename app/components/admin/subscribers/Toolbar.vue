<script setup lang="ts">
import { PopoverContent, PopoverPortal, PopoverRoot, PopoverTrigger } from 'reka-ui'
import { CalendarRange, ChevronDown, FileCheck, MapPin, Megaphone, Search, ShieldCheck } from 'lucide-vue-next'
import { DATE_FIELDS, dateFieldSlug, hasFilterChips, SOURCE_OPTIONS, STATUS_FILTERS, sourceLabel, SUBSCRIBER_VIEWS, type SubscriberFilters, type SubscriberList, type SubscriberView } from '~/utils/admin-subscribers'
import { RELATED_FILTERS, relatedSlug } from '~/utils/admin-subscribers-related'

/**
 * Tabs with counts (← → move between them), search by email (`/`), filters (Origen, Idioma, Fechas, Texto aceptado, Afines (D66) and,
 * in Todos, Estado) and their removable chips. All of it lives in the URL. The `filter` event carries a URL patch.
 */
const props = defineProps<{ result?: SubscriberList; filters: SubscriberFilters }>()
const view = defineModel<SubscriberView>('view', { required: true })
const search = defineModel<string>('search', { required: true })
const emit = defineEmits<{ filter: [patch: Record<string, string | undefined>]; clear: [] }>()

const ALL = 'all'
const searchInput = ref<HTMLInputElement>()
const localeOptions = [{ value: ALL, label: 'Cualquier idioma' }, { value: 'es', label: 'Español' }, { value: 'en', label: 'Inglés' }]
const sourceOptions = computed(() => {
  const known = SOURCE_OPTIONS.map((o) => o.value)
  const extra = Object.keys(props.result?.sourceCounts ?? {}).filter((s) => !known.includes(s)).map((s) => ({ value: s, label: sourceLabel(s) }))
  return [...SOURCE_OPTIONS, ...extra].map((o) => ({ ...o, count: props.result?.sourceCounts[o.value] ?? 0 }))
})
const versionOptions = computed(() =>
  Object.entries(props.result?.versionCounts ?? {})
    .map(([v, count]) => ({ value: v, label: `Versión ${v}`, count }))
    .sort((a, b) => Number(b.value) - Number(a.value)),
)
const relatedOptions = computed(() => RELATED_FILTERS.map((o) => ({ value: o.slug, label: o.label, count: props.result?.relatedCounts[o.value] ?? 0 })))
const dateOptions = DATE_FIELDS.map((d) => ({ value: d.value, label: d.label }))
const chips = computed(() => hasFilterChips(props.filters))

/** Toggles one value of a comma list in the URL. */
function toggle(key: 'origen' | 'version' | 'estado' | 'afines', current: readonly (string | number)[], value: string, on: boolean) {
  const next = on ? [...current.map(String), value] : current.map(String).filter((c) => c !== value)
  emit('filter', { [key]: next.join(',') || undefined })
}

function move(event: KeyboardEvent, index: number) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
  if (!step) return
  event.preventDefault()
  const next = SUBSCRIBER_VIEWS[(index + step + SUBSCRIBER_VIEWS.length) % SUBSCRIBER_VIEWS.length]
  if (!next) return
  view.value = next.value
  void nextTick(() => document.getElementById(`sub-tab-${next.value}`)?.focus())
}
function onSlash(event: KeyboardEvent) {
  const target = event.target as HTMLElement | null
  if (event.key !== '/' || event.ctrlKey || event.metaKey || event.altKey) return
  if (target?.closest('input,textarea,select,[contenteditable],[role=dialog],[role=alertdialog]')) return
  event.preventDefault()
  searchInput.value?.focus()
}
onMounted(() => window.addEventListener('keydown', onSlash))
onBeforeUnmount(() => window.removeEventListener('keydown', onSlash))
</script>

<template>
  <div class="flex-none">
    <div class="overflow-x-auto border-b border-adm-line px-4 md:px-6">
      <div role="tablist" aria-label="Vistas de suscriptores" class="flex min-w-max gap-5">
        <button
          v-for="(tab, index) in SUBSCRIBER_VIEWS"
          :id="`sub-tab-${tab.value}`"
          :key="tab.value"
          type="button"
          role="tab"
          :aria-selected="view === tab.value"
          :tabindex="view === tab.value ? 0 : -1"
          :class="[
            'relative inline-flex h-10 items-center gap-1.5 rounded text-[13px] max-md:h-11',
            view === tab.value ? 'font-medium text-adm-fg after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-adm-acc' : 'text-adm-meta hover:text-adm-fg',
          ]"
          @click="view = tab.value"
          @keydown="move($event, index)"
        >
          {{ tab.label }}
          <span v-if="result && tab.value !== 'all'" class="text-adm-muted tabular-nums">{{ new Intl.NumberFormat('es-ES').format(result.tabCounts[tab.value]) }}</span>
        </button>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2.5 md:px-6">
      <div class="relative w-full sm:w-72">
        <label for="sub-q" class="sr-only">Buscar por email</label>
        <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
        <input id="sub-q" ref="searchInput" v-model="search" type="search" :class="[admInput, 'pr-8 pl-8 [&::-webkit-search-cancel-button]:hidden']" placeholder="Buscar por email" autocomplete="off" spellcheck="false" aria-keyshortcuts="/" />
        <span :class="[admKbd, 'pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 max-sm:hidden']" aria-hidden="true">/</span>
      </div>

      <AdminSubscribersFilterMenu label="Origen" :icon="MapPin" :options="sourceOptions" :selected="filters.sources" @toggle="(v, on) => toggle('origen', filters.sources, v, on)" />

      <div class="min-w-0 max-sm:flex-1 sm:w-44"><AdminSelect :model-value="filters.locale || ALL" label="Idioma" :options="localeOptions" hide-label @update:model-value="(v) => emit('filter', { idioma: v === ALL ? undefined : v })" /></div>

      <PopoverRoot>
        <PopoverTrigger :class="admBtnGhost"><CalendarRange aria-hidden="true" />Fechas<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /></PopoverTrigger>
        <PopoverPortal>
          <PopoverContent align="start" :side-offset="4" :class="[admPopover, 'admin w-72 space-y-3 p-3 font-sans']">
            <div>
              <p :id="'sub-datefield'" :class="admLabel">Fecha de</p>
              <AdminSegmented
                :model-value="filters.dateField"
                labelledby="sub-datefield"
                :options="dateOptions"
                @update:model-value="(v) => emit('filter', { fecha: v === 'consent' ? undefined : dateFieldSlug(v) })"
              />
            </div>
            <div><label for="sub-from" :class="admLabel">Desde</label><input id="sub-from" type="date" :class="admInput" :value="filters.from" @change="emit('filter', { desde: ($event.target as HTMLInputElement).value || undefined })" /></div>
            <div><label for="sub-to" :class="admLabel">Hasta</label><input id="sub-to" type="date" :class="admInput" :value="filters.to" @change="emit('filter', { hasta: ($event.target as HTMLInputElement).value || undefined })" /></div>
            <p class="text-xs text-adm-meta">Hora de Barcelona. El último día cuenta entero.</p>
          </PopoverContent>
        </PopoverPortal>
      </PopoverRoot>

      <AdminSubscribersFilterMenu class="max-sm:hidden" label="Texto aceptado" :icon="FileCheck" :options="versionOptions" :selected="filters.versions.map(String)" @toggle="(v, on) => toggle('version', filters.versions, v, on)" />
      <AdminSubscribersFilterMenu label="Afines" :icon="Megaphone" :options="relatedOptions" :selected="filters.related.map(relatedSlug)" @toggle="(v, on) => toggle('afines', filters.related.map(relatedSlug), v, on)" />
      <AdminSubscribersFilterMenu v-if="view === 'all'" label="Estado" :icon="ShieldCheck" :options="STATUS_FILTERS" :selected="filters.statuses" @toggle="(v, on) => toggle('estado', filters.statuses, v, on)" />
    </div>

    <AdminSubscribersChips v-if="chips" :filters="filters" :show-statuses="view === 'all'" @filter="emit('filter', $event)" @remove="(key, value) => toggle(key, key === 'origen' ? filters.sources : key === 'version' ? filters.versions : key === 'afines' ? filters.related.map(relatedSlug) : filters.statuses, value, false)" @clear="emit('clear')" />
  </div>
</template>
