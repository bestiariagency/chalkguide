<script setup lang="ts">
import { DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuItem, DropdownMenuItemIndicator, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { Bot, Check, ChevronDown, Inbox, Link as LinkIcon, Search, Settings2, Tag, X } from 'lucide-vue-next'
import { ADMIN_NEWS_SCOPES, NEWS_VIEWS, scopeLabel, type NewsCategory, type NewsFilters, type NewsView } from '~/utils/admin-news'

type FilterKey = 'categoria' | 'alcance' | 'fuente' | 'recogida'

/** Tabs with counts, search, filters (Categoría, Alcance, Fuente, Recogida) with removable chips. All of it lives in the URL. */
const props = defineProps<{
  counts?: Record<NewsView, number>
  categories: readonly NewsCategory[]
  categoryCounts: ReadonlyMap<string, number>
  sources: readonly { id: string; name: string; count: number }[]
  runs: readonly { id: string; label: string }[]
  filters: NewsFilters
}>()
const view = defineModel<NewsView>('view', { required: true })
const search = defineModel<string>('search', { required: true })
const emit = defineEmits<{ filter: [patch: Partial<Record<FilterKey, string | undefined>>] }>()

const ALL = 'all'
const scopeOptions = [{ value: ALL, label: 'Todo' }, ...ADMIN_NEWS_SCOPES]
const scope = computed({ get: () => props.filters.scope || ALL, set: (v: string) => emit('filter', { alcance: v === ALL ? undefined : v }) })
const csv = (list: string[]) => list.join(',') || undefined
const toggle = (list: string[], value: string, on: boolean) => (on ? [...list, value] : list.filter((v) => v !== value))
const catLabel = (key: string) => props.categories.find((c) => c.key === key)?.labelEs ?? key
const srcLabel = (id: string) => props.sources.find((s) => s.id === id)?.name ?? 'Una fuente'
const runLabelOf = (id: string) => props.runs.find((r) => r.id === id)?.label ?? 'Una recogida'
const active = computed(() => props.filters.categories.length > 0 || !!props.filters.scope || props.filters.sources.length > 0 || !!props.filters.run)

function move(event: KeyboardEvent, index: number) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
  if (!step) return
  event.preventDefault()
  const next = NEWS_VIEWS[(index + step + NEWS_VIEWS.length) % NEWS_VIEWS.length]
  if (!next) return
  view.value = next.value
  void nextTick(() => document.getElementById(`news-tab-${next.value}`)?.focus())
}
const chipBtn = 'inline-flex h-6 items-center gap-1 rounded-full border border-adm-line-strong bg-adm-elev pr-1 pl-2.5 text-xs hover:border-adm-control max-md:h-8'
const searchInput = ref<HTMLInputElement>()
onMounted(() => {
  const onKey = (e: KeyboardEvent) => {
    if (e.key !== '/' || isShortcutBlocked(e)) return
    e.preventDefault()
    searchInput.value?.focus()
  }
  window.addEventListener('keydown', onKey)
  onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
})
</script>

<template>
  <div class="flex-none">
    <div class="overflow-x-auto border-b border-adm-line px-4 md:px-6">
      <div role="tablist" aria-label="Vistas de noticias" class="flex min-w-max gap-5">
        <button
          v-for="(tab, index) in NEWS_VIEWS"
          :id="`news-tab-${tab.value}`"
          :key="tab.value"
          type="button"
          role="tab"
          :aria-selected="view === tab.value"
          aria-controls="news-panel"
          :tabindex="view === tab.value ? 0 : -1"
          :class="[
            'relative inline-flex h-10 items-center gap-1.5 rounded text-[13px] max-md:h-11',
            view === tab.value ? 'font-medium text-adm-fg after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-adm-acc' : 'text-adm-meta hover:text-adm-fg',
          ]"
          @click="view = tab.value"
          @keydown="move($event, index)"
        >
          <Inbox v-if="tab.value === 'revisar'" class="size-4" aria-hidden="true" />{{ tab.label }}
          <span v-if="counts" :class="tab.value === 'revisar' && counts.revisar ? 'rounded-full bg-adm-warn-soft px-1.5 text-adm-warn tabular-nums' : 'text-adm-muted tabular-nums'">{{ counts[tab.value] }}</span>
        </button>
      </div>
    </div>

    <div class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2.5 md:px-6">
      <div class="relative w-full sm:w-64">
        <label for="news-q" class="sr-only">Buscar noticias</label>
        <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
        <input id="news-q" ref="searchInput" v-model="search" type="search" :class="[admInput, 'pr-7 pl-8 [&::-webkit-search-cancel-button]:hidden']" placeholder="Buscar noticias" autocomplete="off" />
        <span :class="[admKbd, 'pointer-events-none absolute top-1/2 right-2 -translate-y-1/2 max-md:hidden']" aria-hidden="true">/</span>
      </div>

      <div class="flex max-w-full items-center gap-2 overflow-x-auto pb-0.5">
        <DropdownMenuRoot>
          <DropdownMenuTrigger :class="admBtnGhost" :aria-label="filters.categories.length ? `Categoría, ${filters.categories.length} seleccionadas` : 'Categoría'">
            <Tag aria-hidden="true" />Categoría<span v-if="filters.categories.length" class="rounded-full bg-adm-acc-soft px-1.5 text-adm-acc tabular-nums">{{ filters.categories.length }}</span><ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" />
          </DropdownMenuTrigger>
          <DropdownMenuPortal>
            <DropdownMenuContent align="start" :side-offset="4" :class="[admPopover, 'admin font-sans']">
              <DropdownMenuCheckboxItem
                v-for="c in categories"
                :key="c.id"
                :model-value="filters.categories.includes(c.key)"
                :class="[admMenuItem, 'cursor-pointer']"
                @select.prevent
                @update:model-value="(on: boolean) => emit('filter', { categoria: csv(toggle(filters.categories, c.key, on)) })"
              >
                <span class="grid size-4 place-items-center rounded border border-adm-control"><DropdownMenuItemIndicator><Check class="size-3! text-adm-acc!" aria-hidden="true" /></DropdownMenuItemIndicator></span>
                <span class="flex-1">{{ c.labelEs }}</span><span class="text-adm-muted tabular-nums">{{ categoryCounts.get(c.key) ?? 0 }}</span>
              </DropdownMenuCheckboxItem>
            </DropdownMenuContent>
          </DropdownMenuPortal>
        </DropdownMenuRoot>

        <AdminSegmented v-model="scope" label="Alcance" :options="scopeOptions" />

        <DropdownMenuRoot>
          <DropdownMenuTrigger :class="admBtnGhost" :aria-label="filters.sources.length ? `Fuente, ${filters.sources.length} seleccionadas` : 'Fuente'">
            <LinkIcon aria-hidden="true" />Fuente<span v-if="filters.sources.length" class="rounded-full bg-adm-acc-soft px-1.5 text-adm-acc tabular-nums">{{ filters.sources.length }}</span><ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" />
          </DropdownMenuTrigger>
          <DropdownMenuPortal>
            <DropdownMenuContent align="start" :side-offset="4" :class="[admPopover, 'admin max-h-80 overflow-y-auto font-sans']">
              <DropdownMenuCheckboxItem
                v-for="s in sources"
                :key="s.id"
                :model-value="filters.sources.includes(s.id)"
                :class="[admMenuItem, 'cursor-pointer']"
                @select.prevent
                @update:model-value="(on: boolean) => emit('filter', { fuente: csv(toggle(filters.sources, s.id, on)) })"
              >
                <span class="grid size-4 place-items-center rounded border border-adm-control"><DropdownMenuItemIndicator><Check class="size-3! text-adm-acc!" aria-hidden="true" /></DropdownMenuItemIndicator></span>
                <span class="flex-1 truncate">{{ s.name }}</span><span class="text-adm-muted tabular-nums">{{ s.count }}</span>
              </DropdownMenuCheckboxItem>
              <p v-if="!sources.length" class="px-2 py-1.5 text-xs text-adm-meta">Ninguna fuente en esta vista.</p>
              <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
              <DropdownMenuItem as-child :class="[admMenuItem, 'cursor-pointer']"><NuxtLink :to="`${adminPath('ingesta')}#fuentes`"><Settings2 aria-hidden="true" />Gestionar fuentes</NuxtLink></DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenuPortal>
        </DropdownMenuRoot>

        <DropdownMenuRoot>
          <DropdownMenuTrigger :class="[admBtnGhost, 'whitespace-nowrap']"><Bot aria-hidden="true" />{{ filters.run ? `Recogida: ${runLabelOf(filters.run)}` : 'Recogida' }}<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /></DropdownMenuTrigger>
          <DropdownMenuPortal>
            <DropdownMenuContent align="start" :side-offset="4" :class="[admPopover, 'admin max-h-80 overflow-y-auto font-sans']">
              <p class="px-2 pt-1.5 pb-1 text-xs text-adm-meta">Últimos 30 días</p>
              <DropdownMenuItem v-for="r in runs" :key="r.id" :class="[admMenuItem, 'cursor-pointer']" @select="emit('filter', { recogida: r.id })">
                <Check v-if="filters.run === r.id" class="text-adm-acc!" aria-hidden="true" /><span v-else class="size-4" aria-hidden="true" />{{ r.label }}
              </DropdownMenuItem>
              <p v-if="!runs.length" class="px-2 py-1.5 text-xs text-adm-meta">Todavía no hay recogidas.</p>
            </DropdownMenuContent>
          </DropdownMenuPortal>
        </DropdownMenuRoot>
      </div>

      <p v-if="view === 'revisar'" class="ml-auto hidden items-center gap-2 text-xs text-adm-meta xl:flex">
        <span :class="admKbd">J</span><span :class="admKbd">K</span> moverse · <span :class="admKbd">A</span> aprobar · <span :class="admKbd">E</span> editar · <span :class="admKbd">D</span> rechazar
      </p>
    </div>

    <div v-if="active" class="flex flex-wrap items-center gap-2 border-b border-adm-line px-4 py-2 text-xs md:px-6" aria-label="Filtros activos" role="group">
      <span class="text-adm-meta">Filtros:</span>
      <button v-for="key in filters.categories" :key="key" type="button" :class="chipBtn" @click="emit('filter', { categoria: csv(toggle(filters.categories, key, false)) })">Categoría: {{ catLabel(key) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button v-if="filters.scope" type="button" :class="chipBtn" @click="emit('filter', { alcance: undefined })">Alcance: {{ scopeLabel(filters.scope) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button v-for="id in filters.sources" :key="id" type="button" :class="chipBtn" @click="emit('filter', { fuente: csv(toggle(filters.sources, id, false)) })">Fuente: {{ srcLabel(id) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button v-if="filters.run" type="button" :class="chipBtn" @click="emit('filter', { recogida: undefined })">Recogida: {{ runLabelOf(filters.run) }}<X class="size-3.5" aria-hidden="true" /><span class="sr-only"> quitar filtro</span></button>
      <button type="button" class="ml-1 rounded px-1 text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11" @click="emit('filter', { categoria: undefined, alcance: undefined, fuente: undefined, recogida: undefined })">Quitar filtros</button>
    </div>
  </div>
</template>
