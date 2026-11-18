<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Gym listing (F3.5). SEO: canonical without query, hreflang only with >= 5 English gyms (§6). Data: one `useGyms('all')` (shared with the home payload). Cards (README §9.9.2), default order by day price. Sort and
 * filters are client-side state mirrored in the query string; the canonical (from
 * @nuxtjs/i18n) is the route without query, and the SSR HTML is the unfiltered list.
 */
const { t } = useI18n()
const { data: gyms, error, refresh } = await useGyms('all')

const { data: varietyData } = await useGymVarietyActive()
// Until known (or on error) keep the column: it only disappears when the criterion is confirmed off.
const showVariety = computed(() => varietyData.value !== false)

const all = computed(() => gyms.value ?? [])
const listing = useGymListing(all, showVariety)

const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.gyms') },
])

const listingRobots = await useListingSeo('gym', () => all.value.length)
const robots = useListingRobots(listingRobots)
usePageSeo(() => ({
  title: t('gyms.list.seoTitle'),
  description: t('gyms.list.seoDescription'),
  robots: robots.value,
}))
useBreadcrumbJsonLd(crumbs)
useItemListJsonLd(all, 'climbing-gyms-slug')
</script>

<template>
  <div>
    <section class="border-b-[0.5px] border-line board-tex">
      <div class="mx-auto max-w-page px-4 pt-8 pb-12 md:px-6 md:pt-10 md:pb-16">
        <UiBreadcrumbs :items="crumbs" />
        <h1 class="mt-5 title-section">{{ t('gyms.list.title') }}</h1>
        <p class="mt-4 max-w-read text-body-lg text-meta">{{ t('gyms.list.intro') }}</p>
      </div>
    </section>

    <section class="mx-auto max-w-page px-4 py-10 md:px-6 md:py-14" aria-labelledby="gyms-list">
      <h2 id="gyms-list" class="sr-only">{{ t('gyms.list.heading') }}</h2>

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

      <template v-else>
        <GymsFilters
          v-model:query="listing.query.value"
          :active="listing.active.value"
          :sort-key="listing.sortKey.value"
          :count="listing.sorted.value.length"
          :total="listing.total.value"
          :show-variety="showVariety"
          @toggle="listing.toggle"
          @sort="listing.setSort"
          @clear="listing.clear"
        />

        <template v-if="listing.sorted.value.length">
          <GymsLegend :show-variety="showVariety" />
          <ul class="mt-2 grid gap-4 sm:grid-cols-2 md:gap-5 lg:grid-cols-3">
            <li v-for="gym in listing.sorted.value" :key="gym.id">
              <GymsCard :gym="gym" :tokens="listing.tokens.value" :show-variety="showVariety" />
            </li>
          </ul>
        </template>
        <ItemsNoResults
          v-else
          :query="listing.query.value.trim()"
          :active-filters="listing.active.value.length"
          :noun="t('gyms.search.nounOne')"
          @clear-filters="listing.clear()"
          @clear-query="listing.clearQuery()"
        />

      </template>
    </section>
  </div>
</template>
