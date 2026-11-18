<script setup lang="ts">
import { PopoverContent, PopoverPortal, PopoverRoot, PopoverTrigger } from 'reka-ui'
import { CalendarRange, Check, ChevronDown, Download, Search } from 'lucide-vue-next'
import { ACTIVITY_PERIODS, ACTIVITY_TABS, periodLabel, SEARCH_MAX, SEARCH_MIN, tabSlug, type ActivityFilters, type ActivityTab } from '~/utils/admin-activity'

/**
 * Tabs (← → move between them; Exportaciones carries its count), search by title, file or subscriber email (`/`) and
 * the period. All of it lives in the URL: the `filter` event carries a URL patch.
 */
const props = defineProps<{ filters: ActivityFilters; counts?: Record<ActivityTab, number> }>()
const search = defineModel<string>('search', { required: true })
const emit = defineEmits<{ filter: [patch: Record<string, string | undefined>] }>()

const searchInput = ref<HTMLInputElement>()
const tooShort = computed(() => search.value.trim().length > 0 && search.value.trim().length < SEARCH_MIN)
const today = todayMadrid()

function pick(tab: ActivityTab) {
  emit('filter', { vista: tab === 'all' ? undefined : tabSlug(tab) })
}
function move(event: KeyboardEvent, index: number) {
  const last = ACTIVITY_TABS.length - 1
  const target = event.key === 'Home' ? 0 : event.key === 'End' ? last : event.key === 'ArrowRight' ? (index + 1) % ACTIVITY_TABS.length : event.key === 'ArrowLeft' ? (index + last) % ACTIVITY_TABS.length : -1
  if (target < 0) return
  event.preventDefault()
  const next = ACTIVITY_TABS[target]
  if (!next) return
  pick(next.value)
  void nextTick(() => document.getElementById(`act-tab-${next.value}`)?.focus())
}
/** Keeps the active tab in view (the tab strip scrolls at 390 px). */
function centerActive() {
  void nextTick(() => document.getElementById(`act-tab-${props.filters.tab}`)?.scrollIntoView({ inline: 'center', block: 'nearest' }))
}
watch(() => props.filters.tab, centerActive)
onMounted(centerActive)

const periodOpen = ref(false)
const periodTrigger = ref<{ $el: HTMLElement }>()
function pickPeriod(slug: string | undefined) {
  emit('filter', { periodo: slug, desde: undefined, hasta: undefined })
  periodOpen.value = false
  void nextTick(() => periodTrigger.value?.$el.focus())
}
function onPeriodKey(event: KeyboardEvent) {
  const keys: Record<string, number> = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }
  const step = keys[event.key]
  if (!step) return
  const radios = [...(event.currentTarget as HTMLElement).querySelectorAll<HTMLElement>('[role=radio]')]
  const at = radios.indexOf(document.activeElement as HTMLElement)
  if (at < 0) return
  event.preventDefault()
  radios[(at + step + radios.length) % radios.length]!.focus()
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

const range = (key: 'desde' | 'hasta', event: Event) => emit('filter', { periodo: undefined, [key]: (event.target as HTMLInputElement).value || undefined })
</script>

<template>
  <div class="flex-none">
    <div class="overflow-x-auto border-b border-adm-line px-4 md:px-6">
      <div role="tablist" aria-label="Tipos de actividad" class="flex min-w-max gap-5">
        <button
          v-for="(tab, index) in ACTIVITY_TABS"
          :id="`act-tab-${tab.value}`"
          :key="tab.value"
          type="button"
          role="tab"
          aria-controls="act-panel"
          :aria-selected="filters.tab === tab.value"
          :tabindex="filters.tab === tab.value ? 0 : -1"
          :class="[
            'relative inline-flex h-10 items-center gap-1.5 rounded text-[13px] max-md:h-11',
            filters.tab === tab.value ? 'font-medium text-adm-fg after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-adm-acc' : 'text-adm-meta hover:text-adm-fg',
          ]"
          @click="pick(tab.value)"
          @keydown="move($event, index)"
        >
          <Download v-if="tab.value === 'exp'" class="size-3.5" aria-hidden="true" />{{ tab.label }}
          <span v-if="tab.value === 'exp' && counts" class="text-adm-muted tabular-nums">{{ fmtInt(counts.exp) }}</span>
          <span v-if="tab.value === 'exp' && counts" class="sr-only">{{ counts.exp === 1 ? 'entrada' : 'entradas' }}</span>
        </button>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2.5 md:px-6">
      <div class="relative w-full sm:w-72">
        <label for="act-q" class="sr-only">Buscar en la actividad</label>
        <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
        <input
          id="act-q"
          ref="searchInput"
          v-model="search"
          type="search"
          :maxlength="SEARCH_MAX"
          :class="[admInput, 'pr-8 pl-8 [&::-webkit-search-cancel-button]:hidden']"
          placeholder="Buscar por título, archivo o email"
          autocomplete="off"
          spellcheck="false"
          aria-keyshortcuts="/"
          :aria-describedby="tooShort ? 'act-q-help' : undefined"
        />
        <span :class="[admKbd, 'pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 max-sm:hidden']" aria-hidden="true">/</span>
      </div>
      <p v-if="tooShort" id="act-q-help" class="text-xs text-adm-meta" role="status">Escribe al menos {{ SEARCH_MIN }} caracteres.</p>

      <PopoverRoot v-model:open="periodOpen">
        <PopoverTrigger ref="periodTrigger" :class="admBtnGhost"><CalendarRange aria-hidden="true" />{{ periodLabel(filters) }}<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /></PopoverTrigger>
        <PopoverPortal>
          <PopoverContent align="start" :side-offset="4" :class="[admPopover, 'admin w-72 space-y-3 p-3 font-sans']">
            <ul class="space-y-0.5" role="radiogroup" aria-label="Periodo" @keydown="onPeriodKey">
              <li v-for="p in ACTIVITY_PERIODS" :key="p.value" role="presentation">
                <button type="button" :class="[admMenuItem, 'justify-between hover:bg-adm-subtle focus-visible:bg-adm-subtle']" role="radio" :aria-checked="filters.period === p.value" :tabindex="filters.period === p.value || (!ACTIVITY_PERIODS.some((q) => q.value === filters.period) && p === ACTIVITY_PERIODS[0]) ? 0 : -1" @click="pickPeriod(p.slug)">
                  {{ p.label }}<Check v-if="filters.period === p.value" class="size-4 text-adm-acc" aria-hidden="true" />
                </button>
              </li>
            </ul>
            <fieldset class="space-y-2 border-t border-adm-line pt-3">
              <legend class="sr-only">Rango personalizado</legend>
              <div><label for="act-from" :class="admLabel">Desde</label><input id="act-from" type="date" :class="admInput" :value="filters.from" :max="filters.to || today" @change="range('desde', $event)" /></div>
              <div><label for="act-to" :class="admLabel">Hasta</label><input id="act-to" type="date" :class="admInput" :value="filters.to" :min="filters.from || undefined" :max="today" @change="range('hasta', $event)" /></div>
              <p class="text-xs text-adm-meta">Hora de Barcelona. El día de «Hasta» se incluye entero.</p>
            </fieldset>
          </PopoverContent>
        </PopoverPortal>
      </PopoverRoot>
    </div>
  </div>
</template>
