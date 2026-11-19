<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * News index (F8, §15.2, §18): header with category chips, scope and the grid/list switch, the newspaper front page
 * (opener + 2 + grid, or the list by week), FTS search and `?pagina=` paging.
 * Indexable from 6 published items (D79); `?pagina`, `?alcance` and `?q` are `noindex, follow` with
 * the clean canonical. In English only items with an English version are listed (D3).
 */
const { t, locale } = useI18n()
const listing = await useNewsListing()
const { search, nav } = listing

const crumbs = computed<BreadcrumbItem[]>(() => [{ label: t('nav.home'), to: '/' }, { label: t('nav.news') }])

const navTotal = computed(() => nav.data.value?.total ?? 0)
const listingRobots = await useListingSeo('news', navTotal)
const base = computed(() =>
  locale.value === 'es' && !isNewsIndexIndexable(navTotal.value) ? ROBOTS_NOINDEX_FOLLOW : listingRobots,
)
const robots = useListingRobots(base.value)
usePageSeo(() => ({ title: t('seo.newsTitle'), description: t('seo.newsDescription'), robots: robots.value }))
useBreadcrumbJsonLd(crumbs)
</script>

<template>
  <div>
    <NewsHeader
      v-model:query="search.query.value"
      :scope="listing.scope.value"
      :crumbs="crumbs"
      :title="t('nav.news')"
      :lede="t('news.lede')"
      :nav="nav.data.value"
      :too-short="search.tooShort.value"
      @update:scope="listing.setScope"
    />
    <NewsListing
      :search-active="search.active.value"
      :term="search.term.value"
      :status="search.status.value"
      :hits="search.hits.value"
      :total="search.total.value"
      :loading-more="search.loadingMore.value"
      :has-more="search.hasMore.value"
      :items="listing.items.value"
      :page="listing.page.value"
      :pages="listing.pages.value"
      :error="!!listing.list.error.value"
      :scoped="!!listing.scope.value"
      :is-category="false"
      @retry="search.retry()"
      @more="search.loadMore()"
      @clear="search.clearQuery()"
      @refresh="listing.list.refresh()"
      @clear-scope="listing.setScope(null)"
    />
  </div>
</template>
