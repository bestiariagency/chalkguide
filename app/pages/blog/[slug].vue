<script setup lang="ts">
/**
 * Article (editorial v2, D51): ink head, 640 px reading column, body from body_html (editorial
 * HTML, sanitized by /api/content) through <UiProse>. Index only with >= 800 words and >= 3 H2 (rail
 * from 1100 px, <details> below, 2 px progress bar). 404 if missing or without an English version
 * under /en (D3); the language switcher learns the translated slug. Email (D48): only the layout's
 * orange block and the index line; no cards inside the article.
 */
const { t, locale } = useI18n()
const route = useRoute()
const slug = computed(() => String(route.params.slug))

const { data: article } = await useArticle(slug)
await useSlugRedirect(article.value, 'article', 'blog-slug')
useDetailLocales(article.value, 'blog')
const current = computed(() => article.value!)

// Already sanitized by the server: the index, the heading ids (UiProse) and the reading spy all read the same SafeHtml.
const bodyHtml = computed(() => current.value.bodyHtml)
const toc = computed(() => articleToc(bodyHtml.value))
const allHeadings = computed(() => extractHeadings(bodyHtml.value))
const bodyEl = ref<HTMLElement | null>(null)
const { progress, activeId } = useArticleReading({
  body: bodyEl,
  headings: allHeadings,
})
useDockReadingHide(bodyEl)

const { items, related } = await useArticleRelations(current)

const guestVisit = computed(() => items.data.value?.some((item) => item.visitType === 'invited'))
const affiliate = computed(() => items.data.value?.some((item) => item.isAffiliate))

// SEO: article metadata (og:type article, cover as share image), `Article` with author Person
// and BreadcrumbList. `noindex` articles stay out of the index (and the sitemap).
const absolute = useAbsoluteUrl()
const siteUrl = useSiteUrl()
const mediaUrl = useMediaUrl()
const { aboutUrl } = useAuthorUrl()
const cover = computed(() => (current.value.cover ? mediaUrl(current.value.cover.path) : null))
usePageSeo(() => ({
  title: current.value.seoTitle ?? current.value.title,
  description: current.value.seoDescription ?? current.value.excerpt,
  image: cover.value,
  imageAlt: current.value.cover?.alt,
  imageWidth: current.value.cover?.width,
  imageHeight: current.value.cover?.height,
  type: 'article',
  publishedTime: current.value.publishedAt,
  modifiedTime: current.value.updatedAt,
  robots: current.value.noindex ? ROBOTS_NOINDEX_FOLLOW : undefined,
}))
useJsonLd('article', () =>
  articleLd({
    url: absolute(route.path),
    siteUrl,
    headline: current.value.title,
    description: current.value.seoDescription ?? current.value.excerpt ?? undefined,
    image: cover.value ?? undefined,
    publishedAt: current.value.publishedAt,
    modifiedAt: current.value.updatedAt,
    section: current.value.category?.name,
    language: locale.value === 'en' ? 'en' : 'es',
    aboutUrl,
    authorName: current.value.author?.name ?? undefined,
  }),
)
useBreadcrumbJsonLd(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.blog'), to: { name: 'blog' } },
  ...(current.value.category
    ? [
        {
          label: current.value.category.name,
          to: { name: 'blog-category-slug', params: { slug: current.value.category.slug } },
        },
      ]
    : []),
  { label: current.value.title },
])
</script>

<template>
  <div v-if="article">
    <ArticlesArticleProgress v-if="toc.length" :progress="progress" />
    <article aria-labelledby="article-title">
      <ArticlesArticleHeader :article="article" :guest-visit="guestVisit" :affiliate="affiliate" />
      <div :class="[articleShell, articleGrid]" class="pt-10 md:pt-14">
        <ArticlesArticleToc
          v-if="toc.length"
          variant="rail"
          :headings="toc"
          :active-id="activeId"
          :minutes="article.readingMinutes"
          :progress="progress"
        />
        <ArticlesArticleToc v-if="toc.length" variant="inline" :headings="toc" class="mb-8 min-[1100px]:col-start-2" />
        <div class="min-w-0 min-[1100px]:col-start-2">
          <div ref="bodyEl">
            <UiProse :html="bodyHtml" anchors />
          </div>
          <AuthorSignature variant="full" :author="article.author" />
          <ArticlesArticleItems :items="items.data.value ?? []" />
        </div>
      </div>
      <div class="pb-12 md:pb-16" />
    </article>
    <ArticlesArticleRelated :articles="related.data.value ?? []" />
  </div>
</template>
