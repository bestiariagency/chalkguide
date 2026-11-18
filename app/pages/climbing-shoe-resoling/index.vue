<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Resoler listing (F3.6). One `useResolers('all')` query; sort and filter are client-side
 * state mirrored in the query string, the canonical is the route without query.
 */
const { t } = useI18n()
const { linkFor } = usePageLinks()
const { data, error, refresh } = await useResolers('all')

const all = computed(() => data.value ?? [])
const listing = useResolerListing(all)
const best = computed(() => sortResolers(all.value, 'score')[0]?.id ?? null)

const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.resoling') },
])

const listingRobots = await useListingSeo('resoler', () => all.value.length)
const robots = useListingRobots(listingRobots)
usePageSeo(() => ({
  title: t('resolers.list.seoTitle'),
  description: t('resolers.list.seoDescription'),
  robots: robots.value,
}))
useBreadcrumbJsonLd(crumbs)
useItemListJsonLd(all, 'climbing-shoe-resoling-slug')
</script>

<template>
  <div>
    <section class="border-b-[0.5px] border-line board-tex">
      <div class="mx-auto max-w-page px-4 pt-8 pb-12 md:px-6 md:pt-10 md:pb-16">
        <UiBreadcrumbs :items="crumbs" />
        <h1 class="mt-5 title-section">{{ t('resolers.list.title') }}</h1>
        <p class="mt-4 max-w-read text-body-lg text-meta">{{ t('resolers.list.intro') }}</p>
      </div>
    </section>

    <section class="mx-auto max-w-page px-4 py-10 md:px-6 md:py-14" aria-labelledby="resolers-list">
      <h2 id="resolers-list" class="sr-only">{{ t('resolers.list.heading') }}</h2>

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
        <ResolersFilters
          v-model:query="listing.query.value"
          :active="listing.active.value"
          :sort-key="listing.sortKey.value"
          :count="listing.sorted.value.length"
          :total="listing.total.value"
          @toggle="listing.toggle"
          @sort="listing.setSort"
          @clear="listing.clear"
        />

        <ResolersRows
          v-if="listing.sorted.value.length"
          :resolers="listing.sorted.value"
          :best-id="best"
          :tokens="listing.tokens.value"
          :caption="t('resolers.list.caption')"
        />
        <ItemsNoResults
          v-else
          :query="listing.query.value.trim()"
          :active-filters="listing.active.value.length"
          :noun="t('resolers.search.nounOne')"
          @clear-filters="listing.clear()"
          @clear-query="listing.clearQuery()"
        />

        <p class="mt-10 max-w-read text-caption text-meta">
          <span class="text-foreground">{{ t('resolers.list.randTerm') }}</span>
          {{ t('resolers.list.randNote') }}
          <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')">{{ t('transparency.learnMore') }}</UiTextLink>
        </p>
      </template>
    </section>
  </div>
</template>
