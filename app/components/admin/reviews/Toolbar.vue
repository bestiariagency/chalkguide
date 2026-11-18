<script setup lang="ts">
import { Image, Search } from 'lucide-vue-next'
import { ALL_OPTION, REVIEW_CATEGORIES, REVIEW_VIEWS, type ReviewItemOption, type ReviewView } from '~/utils/admin-reviews'

/** Views (tabs with counts), search, type and item filters of the inbox. Everything lives in the URL. */
const props = defineProps<{
  counts?: Record<ReviewView, number>
  items: readonly ReviewItemOption[]
  selectedCategory: string
}>()
const view = defineModel<ReviewView>('view', { required: true })
const search = defineModel<string>('search', { required: true })
const category = defineModel<string>('categoryFilter', { required: true })
const item = defineModel<string>('item', { required: true })

const categoryOptions = [{ value: ALL_OPTION, label: 'Todos los tipos' }, ...REVIEW_CATEGORIES.map((c) => ({ value: c.value, label: c.label }))]
const itemOptions = computed(() => [
  { value: ALL_OPTION, label: 'Todas las fichas' },
  ...props.items.filter((i) => props.selectedCategory === ALL_OPTION || i.category === props.selectedCategory).map((i) => ({ value: i.id, label: i.name })),
])

function move(event: KeyboardEvent, index: number) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
  if (!step) return
  event.preventDefault()
  const next = REVIEW_VIEWS[(index + step + REVIEW_VIEWS.length) % REVIEW_VIEWS.length]
  if (!next) return
  view.value = next.value
  void nextTick(() => document.getElementById(`rev-tab-${next.value}`)?.focus())
}
</script>

<template>
  <div class="flex-none">
    <div class="overflow-x-auto border-b border-adm-line px-4 md:px-6">
      <div role="tablist" aria-label="Vistas" class="flex min-w-max gap-5">
        <button
          v-for="(tab, index) in REVIEW_VIEWS"
          :id="`rev-tab-${tab.value}`"
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
          <Image v-if="tab.value === 'photos'" class="size-3.5" aria-hidden="true" />{{ tab.label }}
          <span v-if="tab.value === 'recent'" class="text-adm-muted">· 7 días</span>
          <span v-if="counts" :class="tab.value === 'photos' && counts.photos ? 'rounded-full bg-adm-warn-soft px-1.5 text-adm-warn tabular-nums' : 'text-adm-muted tabular-nums'">{{ counts[tab.value] }}</span>
        </button>
      </div>
    </div>
    <div class="grid grid-cols-2 items-center gap-2 border-b border-adm-line px-4 py-2.5 sm:flex sm:flex-wrap md:px-6">
      <div class="relative col-span-2 w-full sm:w-64">
        <label for="rev-q" class="sr-only">Buscar en opiniones</label>
        <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted" aria-hidden="true" />
        <input id="rev-q" v-model="search" type="search" :class="[admInput, 'pl-8']" placeholder="Buscar texto o autor" autocomplete="off" />
      </div>
      <div class="min-w-0 sm:w-44"><AdminSelect v-model="category" label="Tipo" :options="categoryOptions" hide-label /></div>
      <div class="min-w-0 sm:w-56"><AdminSelect v-model="item" label="Ficha" :options="itemOptions" hide-label /></div>
      <p class="col-span-2 ml-auto hidden items-center gap-2 text-xs text-adm-meta lg:flex">
        <span :class="admKbd">J</span><span :class="admKbd">K</span> moverse · <span :class="admKbd">V</span> está bien, siguiente · <span :class="admKbd">A</span> aprobar fotos · <span :class="admKbd">H</span> ocultar
      </p>
    </div>
  </div>
</template>
