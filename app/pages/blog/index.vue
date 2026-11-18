<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Blog index (F3.8): featured articles + "Últimos" + category chips with counts.
 * In English only articles/categories with an English version are listed (D3).
 */
const { t } = useI18n()
const [list, navData] = await Promise.all([
  useArticles('index', { limit: 60 }),
  useCategoryNav(),
])
const { data: articles, error, refresh } = list
const nav = navData.data

const split = computed(() => splitBlogIndex(articles.value ?? []))
const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.blog') },
])

// The English blog is indexable (and gets hreflang) with >= 3 English articles (§6).
const listingRobots = await useListingSeo('article', () => articles.value?.length ?? 0)
const robots = useListingRobots(listingRobots)
usePageSeo(() => ({ title: t('blog.seoTitle'), description: t('blog.seoDescription'), robots: robots.value }))
useBreadcrumbJsonLd(crumbs)

const search = useArticleSearch()
</script>

<template>
  <div>
    <section class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10">
      <UiBreadcrumbs :items="crumbs" />
      <h1 class="mt-5 title-section">{{ t('nav.blog') }}</h1>
      <ArticlesListingControls v-model:query="search.query.value" :nav="nav" :too-short="search.tooShort.value" />
    </section>

    <ArticlesArticleSearchResults
      v-if="search.active.value"
      :term="search.term.value"
      :status="search.status.value"
      :hits="search.hits.value"
      :total="search.total.value"
      :loading-more="search.loadingMore.value"
      :has-more="search.hasMore.value"
      @retry="search.retry()"
      @more="search.loadMore()"
      @clear="search.clearQuery()"
    />

    <div v-if="search.active.value" />
    <div v-else-if="error" class="mx-auto max-w-page px-4 py-12 md:px-6">
      <HomeSectionError :on-retry="() => refresh()" />
    </div>
    <div v-else-if="!split.featured.length" class="mx-auto max-w-page px-4 py-12 md:px-6">
      <UiEmptyState :title="t('blog.emptyTitle')" :body="t('blog.emptyBody')" />
    </div>
    <template v-else>
      <section class="mx-auto max-w-page px-4 pt-6 pb-10 md:px-6 md:pt-8 md:pb-12" aria-labelledby="blog-featured">
        <h2 id="blog-featured" class="sr-only">{{ t('blog.featured') }}</h2>
        <!-- md+: 12 x 6 mosaic with fixed rows; mobile: first card on photo (4:5), the rest as rows. -->
        <div class="grid gap-3 md:grid-cols-12 md:grid-rows-[repeat(6,5.5rem)]">
          <UiReveal
            v-for="(article, i) in split.featured"
            :key="article.id"
            :index="i"
            class="flex"
            :class="[featuredSlot(split.featured.length, i).classes, i > 0 ? 'max-md:border-b-[0.5px] max-md:border-line' : '']"
          >
            <ArticlesOverlayCard
              :article="article"
              flat
              :priority="i === 0"
              :size="featuredSlot(split.featured.length, i).narrow ? 'sm' : 'md'"
              :sizes="featuredSlot(split.featured.length, i).narrow ? '100vw md:33vw' : '100vw md:66vw'"
              class="aspect-[4/5] w-full md:aspect-auto"
              :class="i > 0 ? 'max-md:hidden' : ''"
            />
            <ArticlesArticleRow v-if="i > 0" :article="article" class="w-full md:hidden" />
          </UiReveal>
        </div>
      </section>

      <section
        v-if="split.latest.length"
        class="mx-auto max-w-page px-4 pb-16 md:px-6 md:pb-24"
        aria-labelledby="blog-latest"
      >
        <h2 id="blog-latest" class="label-mini">{{ t('blog.latest') }}</h2>
        <ul class="mt-4 border-t-[0.5px] border-line">
          <li v-for="article in split.latest" :key="article.id" class="border-b-[0.5px] border-line">
            <ArticlesArticleRow :article="article" />
          </li>
        </ul>
      </section>
    </template>
  </div>
</template>
