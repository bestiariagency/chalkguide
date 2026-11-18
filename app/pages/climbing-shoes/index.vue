<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Climbing shoe comparator (F3.7, 3.17-3.19). One `useShoes('all')` query (no N+1: author
 * scores come batched). Search, filters, price range and the chosen models (up to 3) live in
 * the query string; the canonical is the route without query and any of them makes the page
 * `noindex, follow`. Adding a 4th model asks which one to replace.
 */
const { t, locale } = useI18n()
const { data, error, refresh } = await useShoes('all')

const all = computed(() => data.value ?? [])
const cmp = useShoeComparator(all)
// The tray steps aside only once the comparison fills a good part of the screen.
const comparatorWrap = ref<HTMLElement | null>(null)
const comparatorInView = useIntersecting(comparatorWrap, { rootMargin: '0px 0px -40% 0px' })
const actions = useCompareActions(cmp, { trayShown: computed(() => !comparatorInView.value) })
const range = computed({ get: () => cmp.range.value, set: (value) => cmp.setRange(value) })
const sortOptions = computed(() =>
  SHOE_SORTS.map((value) => ({ value, label: t(`shoes.list.sort.${value}`) })),
)
const sortId = useId()
const onSort = (event: Event) => cmp.setSort(parseSort((event.target as HTMLSelectElement).value))

// Detail drawer: the clicked card's model (not in the URL; the card link is the shareable one).
const detailSlug = ref<string | null>(null)
const detailShoe = computed(() => all.value.find((s) => s.slug === detailSlug.value) ?? null)
const drawerOpen = computed({
  get: () => !!detailShoe.value,
  set: (open) => {
    if (!open) detailSlug.value = null
  },
})
// The replace dialog must not stack under/over the drawer.
watch(
  () => actions.dialogOpen.value,
  (open) => open && (detailSlug.value = null),
)
const checkedAt = computed(() => latestPriceCheck(all.value))
const checkedText = computed(() =>
  checkedAt.value ? formatDate(checkedAt.value, locale.value, SHORT_MONTH_DATE) : null,
)


const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.shoes') },
])

const listingRobots = await useListingSeo('shoe', () => all.value.length)
const robots = useListingRobots(listingRobots)
usePageSeo(() => ({
  title: t('shoes.list.seoTitle'),
  description: t('shoes.list.seoDescription'),
  robots: robots.value,
}))
useBreadcrumbJsonLd(crumbs)
useItemListJsonLd(all, 'climbing-shoes-slug')
const resultsLabel = computed(() =>
  cmp.hasQuery.value
    ? t('common.search.countQuery', {
        count: cmp.results.value.length,
        total: all.value.length,
        noun: t('shoes.search.nounMany'),
        query: cmp.query.value.trim(),
      })
    : t('shoes.list.models', cmp.results.value.length),
)
const announce = useDebouncedValue(resultsLabel, 400)
</script>

<template>
  <div>
    <section class="border-b-[0.5px] border-line board-tex">
      <div class="mx-auto max-w-page px-4 pt-8 pb-10 md:px-6 md:pt-10 md:pb-14">
        <UiBreadcrumbs :items="crumbs" />
        <h1 class="mt-5 title-section">{{ t('shoes.list.title') }}</h1>
        <p v-if="all.length" class="mt-4 max-w-read text-body-lg text-meta">
          {{ t('shoes.list.intro', { date: checkedText ?? t('common.noData') }, all.length) }}
        </p>
      </div>
    </section>

    <div class="mx-auto max-w-page px-4 py-10 md:px-6 md:py-14">
      <UiEmptyState
        v-if="error && !all.length"
        :title="t('states.errorTitle')"
        :body="t('states.errorBody')"
      >
        <template #action>
          <UiButton variant="ghost" @click="refresh()">{{ t('common.retry') }}</UiButton>
        </template>
      </UiEmptyState>
      <UiEmptyState
        v-else-if="!all.length"
        :title="t('states.emptyTitle')"
        :body="t('states.emptyBody')"
      />

      <div v-else class="grid gap-10 lg:grid-cols-[260px_minmax(0,1fr)]">
        <ShoesFilters
          v-model:range="range"
          v-model:query="cmp.query.value"
          :filters="cmp.filters.value"
          :options="cmp.options.value"
          :counts="cmp.counts.value"
          :bounds="cmp.bounds.value"
          :active-count="cmp.activeCount.value"
          @list="cmp.setList"
          @owned="cmp.setOwned"
          @clear="cmp.clearFilters"
        />

        <section aria-labelledby="shoes-results" class="min-w-0">
          <div class="flex flex-wrap items-baseline justify-between gap-3">
            <h2 id="shoes-results" class="text-xl font-medium">
              <span aria-hidden="true">{{ resultsLabel }}</span>
              <span class="sr-only" aria-live="polite" aria-atomic="true">{{ announce }}</span>
            </h2>
            <div class="flex items-center gap-3">
              <label :for="sortId" class="text-caption text-meta">{{ t('shoes.list.sortLabel') }}</label>
              <select
                :id="sortId"
                :value="cmp.sort.value"
                class="min-h-11 rounded-md border border-control bg-board px-3 text-body-sm text-foreground focus:border-accent"
                @change="onSort"
              >
                <option v-for="option in sortOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </div>
          </div>
          <ul v-if="cmp.results.value.length" class="mt-5 grid gap-5 tabular-nums sm:grid-cols-2 xl:grid-cols-3">
            <li v-for="shoe in cmp.results.value" :key="shoe.id">
              <ShoesCard
                :shoe="shoe"
                :selected="cmp.isSelected(shoe.slug)"
                :tokens="cmp.tokens.value"
                @toggle="actions.request(shoe)"
                @open="detailSlug = shoe.slug"
              />
            </li>
          </ul>
          <ItemsNoResults
            v-else
            :query="cmp.query.value.trim()"
            :active-filters="cmp.activeCount.value"
            :noun="t('shoes.search.nounOne')"
            @clear-filters="cmp.clearFilters()"
            @clear-query="cmp.clearQuery()"
          />
        </section>
      </div>
    </div>

    <div v-if="all.length" ref="comparatorWrap">
      <ShoesComparator
        v-model:dialog-open="actions.dialogOpen.value"
        :shoes="all"
        :selected="cmp.selected.value"
        :pending="actions.pending.value"
        :flash-slug="actions.flashSlug.value"
        :checked-text="checkedText"
        @pick="actions.request"
        @remove="actions.remove"
        @replace="actions.confirmReplace"
      />
    </div>

    <ShoesCompareTray
      :shoes="cmp.selected.value"
      :hidden="comparatorInView"
      @remove="actions.remove"
    />
    <ShoesDetailDrawer
      v-model:open="drawerOpen"
      :shoe="detailShoe"
      :selected="detailShoe ? cmp.isSelected(detailShoe.slug) : false"
      @toggle="actions.request($event, { silent: true })"
    />
  </div>
</template>
