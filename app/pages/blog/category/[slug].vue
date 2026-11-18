<script setup lang="ts">
import { isEnglishCategoryIndexable } from '~/services/seo'
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Blog category (F3.8): header + description + articles in editorial order (sort_order).
 * 404 if the category does not exist in this locale (D3); in English also 404 when it has
 * no English articles, and the language switcher learns which versions exist.
 */
const { t } = useI18n()
const route = useRoute()
const locale = useGuideLocale()
const slug = computed(() => String(route.params.slug))

const { data: category } = await useArticleCategory(slug)
await useSlugRedirect(category.value, 'article_category', 'blog-category-slug')
useDetailLocales(category.value, 'blog')

const list = await useArticles(
  `category:${category.value?.id}`,
  { categoryId: category.value?.id, bySortOrder: true, limit: 60 },
)
const { data: articles, error, refresh } = list
if (locale.value === 'en' && !error.value && !articles.value?.length) {
  throw createError({ statusCode: 404, statusMessage: 'Not Found', fatal: true })
}
const { data: nav } = await useCategoryNav()

const title = computed(() => category.value?.name ?? slug.value)
const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.blog'), to: { name: 'blog' } },
  { label: title.value },
])

// Indexable only with >= 3 articles and its own text, otherwise `noindex, follow` (§6.x). The
// Spanish page emits the English hreflang only if the English category is indexable too.
const seoText = useSeoText()
const hreflang = useState<{ path: string; locales: ('es' | 'en')[] } | null>('seo-hreflang', () => null)
const indexable = computed(() =>
  isCategoryIndexable(articles.value?.length ?? 0, category.value?.description),
)
let englishReady = false
if (locale.value === 'es' && category.value?.hasEn) {
  const { data: ready } = await useGuideData(`en-category:${category.value.id}`, (db) =>
    isEnglishCategoryIndexable(db, category.value!.id),
  )
  englishReady = ready.value === true
}
hreflang.value = { path: route.path, locales: (locale.value === 'en' ? indexable.value : englishReady) ? ['es', 'en'] : ['es'] }
const robots = useListingRobots(indexable.value ? undefined : ROBOTS_NOINDEX_FOLLOW)
usePageSeo(() => ({
  title: seoText('categoryTitle', { name: title.value }),
  description: category.value?.description || seoText('categoryDescription', { name: title.value }),
  robots: robots.value,
}))
useBreadcrumbJsonLd(crumbs)

const search = useArticleSearch(() => category.value?.id)
</script>

<template>
  <div>
    <section>
      <div class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10">
        <UiBreadcrumbs :items="crumbs" />
        <p class="label-mini mt-6 !text-accent">{{ t('blog.category') }}</p>
        <h1 class="mt-3 title-section">{{ title }}</h1>
        <p v-if="category?.description" class="mt-4 max-w-read text-body-lg text-meta">
          {{ category.description }}
        </p>
        <ArticlesListingControls
          v-model:query="search.query.value"
          :nav="nav"
          :too-short="search.tooShort.value"
          :current="category?.slug"
        />
      </div>
    </section>

    <ArticlesArticleSearchResults
      v-if="search.active.value"
      :term="search.term.value"
      :status="search.status.value"
      :hits="search.hits.value"
      :total="search.total.value"
      :loading-more="search.loadingMore.value"
      :has-more="search.hasMore.value"
      :scope-name="search.scope.value === 'category' ? title : undefined"
      :category-name="title"
      @retry="search.retry()"
      @more="search.loadMore()"
      @widen="search.scope.value = 'all'"
      @narrow="search.scope.value = 'category'"
      @clear="search.clearQuery()"
    />
    <section
      v-else
      class="mx-auto max-w-page px-4 pt-6 pb-12 md:px-6 md:pt-8 md:pb-16"
      aria-labelledby="category-list"
    >
      <h2 id="category-list" class="sr-only">{{ t('blog.categoryList', { name: title }) }}</h2>
      <HomeSectionError v-if="error" :on-retry="() => refresh()" />
      <UiEmptyState
        v-else-if="!articles?.length"
        :title="t('blog.categoryEmptyTitle')"
        :body="t('blog.categoryEmptyBody')"
      >
        <template #action>
          <UiButton :to="{ name: 'blog' }" variant="ghost">{{ t('blog.allArticles') }}</UiButton>
        </template>
      </UiEmptyState>
      <div v-else class="grid gap-3 md:grid-cols-2">
        <UiReveal v-for="(article, i) in articles" :key="article.id" :index="i" class="flex">
          <ArticlesArticleCard :article="article" variant="grid" :priority="i === 0" class="w-full" />
        </UiReveal>
      </div>
    </section>
  </div>
</template>
