<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * News category (F8): same header and list as the index, filtered by the category route (a route,
 * not a filter, §15.2). 404 if it does not exist or, under /en, has no English news (D3). Indexable
 * with >= 3 items and its own text, otherwise `noindex, follow` (like the blog categories).
 */
const { t, locale } = useI18n()
const route = useRoute()
const slug = computed(() => String(route.params.slug))

const { data: category } = await useNewsCategory(slug)
if (!category.value) throw createError({ statusCode: 404, statusMessage: 'Not Found', fatal: true })
const listing = await useNewsListing(() => category.value)
const { search, nav } = listing
const count = computed(() => nav.data.value?.items.find((item) => item.slug === slug.value)?.count ?? 0)
if (locale.value === 'en' && !nav.error.value && !count.value) {
  throw createError({ statusCode: 404, statusMessage: 'Not Found', fatal: true })
}

const title = computed(() => category.value?.name ?? slug.value)
const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.news'), to: { name: 'news' } },
  { label: title.value },
])

// hreflang between category pages is left to the SEO pass (8.11): no alternates for now.
const hreflang = useState<{ path: string; locales: ('es' | 'en')[] } | null>('seo-hreflang', () => null)
hreflang.value = { path: route.path, locales: ['es'] }
const indexable = computed(() => isNewsCategoryIndexable(count.value, category.value?.description))
const robots = useListingRobots(indexable.value ? undefined : ROBOTS_NOINDEX_FOLLOW)
const seoText = useSeoText()
usePageSeo(() => ({
  title: seoText('newsCategoryTitle', { name: title.value }),
  description: category.value?.description || seoText('newsCategoryDescription', { name: title.value }),
  robots: robots.value,
}))
useBreadcrumbJsonLd(crumbs)
</script>

<template>
  <div>
    <NewsHeader
      v-model:query="search.query.value"
      :scope="listing.scope.value"
      :crumbs="crumbs"
      :eyebrow="t('news.category')"
      :title="title"
      :lede="category?.description || t('news.categoryLede', { name: title })"
      :nav="nav.data.value"
      :current="slug"
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
      is-category
      @retry="search.retry()"
      @more="search.loadMore()"
      @clear="search.clearQuery()"
      @refresh="listing.list.refresh()"
      @clear-scope="listing.setScope(null)"
    />
  </div>
</template>
