<script setup lang="ts">
import { ArrowLeft } from 'lucide-vue-next'

/**
 * News page as a preview that leads to the source (F8, §18.9, D91): paper family, 640 px column. Order: headline, date and
 * «Fuente: X ↗» · photo · summary · «Por qué importa» (the insight) · videos · «En ChalkGuide» · ink plaque with «Leer en X ↗».
 * Indexable only with an insight of >= 80 words (D92); without it `noindex, follow`. 404 if missing or, under /en, without an
 * English version (D3). All text is plain and interpolated (F8.1 F1).
 */
const { t, locale } = useI18n()
const route = useRoute()
const slug = computed(() => String(route.params.slug))

const { data: news } = await useNewsItem(slug)
useDetailLocales(news.value, 'news')
const current = computed(() => news.value!)
const related = await useNewsRelated(() => current.value.id)

const category = computed(() =>
  current.value.categoryKey && current.value.categoryName
    ? { slug: current.value.categoryKey, name: current.value.categoryName }
    : null,
)
const parent = computed(() =>
  category.value
    ? { label: category.value.name, to: { name: 'news-category-slug' as const, params: { slug: category.value.slug } } }
    : { label: t('nav.news'), to: { name: 'news' as const } },
)
const crumbs = computed(() => [
  { label: t('nav.home'), to: '/' as const },
  { label: t('nav.news'), to: { name: 'news' as const } },
  ...(category.value ? [{ label: category.value.name, to: parent.value.to }] : []),
  { label: current.value.title },
])
const summary = computed(() => newsParagraphs(current.value.summary))
const sourceHref = computed(() => (isHttpsUrl(current.value.sourceUrl) ? current.value.sourceUrl : null))
const sourceRel = computed(() => newsSourceRel(current.value.sourceTrusted))
const scopeLabel = computed(() => (current.value.scope ? t(`news.scope.${current.value.scope}`) : null))

const mediaUrl = useMediaUrl()
const absolute = useAbsoluteUrl()
const siteUrl = useSiteUrl()
const localePath = useLocalePath()
const { aboutUrl } = useAuthorUrl()
const indexable = computed(() => isNewsIndexable({ insight: current.value.insight }))
const description = computed(() => newsSeoDescription(current.value))
usePageSeo(() => ({
  title: current.value.title,
  description: description.value,
  image: current.value.image ? mediaUrl(current.value.image.path) : null,
  imageAlt: current.value.image?.alt,
  imageWidth: current.value.image?.width,
  imageHeight: current.value.image?.height,
  type: 'article',
  publishedTime: current.value.publishedAt,
  modifiedTime: current.value.updatedAt,
  robots: indexable.value ? undefined : ROBOTS_NOINDEX_FOLLOW,
}))
// `Article` only on indexable pages (spec §19.5): Organization author, Xavi editor, the source as `isBasedOn`.
useJsonLd('article', () =>
  indexable.value
    ? newsArticleLd({
        url: absolute(route.path),
        siteUrl,
        headline: current.value.title,
        description: description.value,
        image: current.value.image ? mediaUrl(current.value.image.path) : undefined,
        publishedAt: current.value.publishedAt,
        modifiedAt: current.value.updatedAt,
        section: current.value.categoryName ?? undefined,
        language: locale.value === 'en' ? 'en' : 'es',
        aboutUrl,
        source: {
          url: current.value.sourceUrl,
          name: current.value.sourceName,
          title: current.value.sourceTitle,
          publishedOn: current.value.sourcePublishedOn,
        },
        related: (related.data.value ?? []).map((item) => ({
          name: item.label,
          url: item.kind === 'event' ? undefined : absolute(localePath(newsRelatedTo(item.kind, item.slug) as never)),
        })),
      })
    : null,
)
useBreadcrumbJsonLd(crumbs)
</script>

<template>
  <div v-if="news">
    <article aria-labelledby="news-title">
      <header class="mx-auto max-w-page px-4 pt-6 md:px-6 md:pt-10">
        <div class="mx-auto max-w-prose">
          <UiBreadcrumbs :items="crumbs.slice(0, -1)" class="max-md:hidden" />
          <NuxtLinkLocale
            :to="parent.to"
            class="inline-flex min-h-11 items-center gap-2 font-mono text-micro tracking-[.06em] text-meta uppercase md:hidden"
          >
            <ArrowLeft :size="16" aria-hidden="true" />
            {{ parent.label }}
          </NuxtLinkLocale>
          <p class="mt-5 flex flex-wrap items-center gap-x-1.5 text-body-sm font-medium text-meta md:mt-6">
            <NuxtLinkLocale :to="parent.to" class="inline-flex min-h-6 items-center gap-1.5 hover:text-foreground">
              <NewsCategoryIcon :slug="news.categoryKey" />{{ parent.label }}
            </NuxtLinkLocale>
            <template v-if="scopeLabel"><span aria-hidden="true">·</span>{{ scopeLabel }}</template>
            <span aria-hidden="true">·</span>
            <time :datetime="news.publishedAt">{{ formatDate(news.publishedAt, locale) }}</time>
          </p>
          <h1
            id="news-title"
            class="mt-2 text-[clamp(1.875rem,1.45rem+1.9vw,3rem)] leading-[1.08] font-medium tracking-[-.028em] text-balance"
          >
            {{ news.title }}
          </h1>
          <p class="mt-5 flex flex-wrap items-center gap-x-2.5 gap-y-1.5 text-body-sm text-meta">
            <UiBadge>{{ t('news.markSummary') }}</UiBadge>
            <span>
              {{ t('news.markSource') }}
              <a v-if="sourceHref" :href="sourceHref" target="_blank" :rel="sourceRel" class="font-medium text-foreground underline underline-offset-2">
                {{ news.sourceName }}<span aria-hidden="true"> ↗</span><span class="sr-only"> {{ t('news.detail.external') }}</span>
              </a>
              <b v-else class="font-medium text-foreground">{{ news.sourceName }}</b>
            </span>
          </p>
        </div>
      </header>

      <figure v-if="news.image" class="mx-auto mt-8 max-w-page px-0 md:mt-10 md:px-6">
        <div class="mx-auto max-w-prose">
          <UiPhoto :media="news.image" eager sizes="100vw md:640px" class="aspect-[3/2] w-full overflow-hidden md:rounded-slab" />
          <figcaption class="mt-3 px-4 text-caption text-meta md:px-0">
            <small class="text-note">
              {{ t('news.detail.photoBy', { credit: news.imageCredit ?? '' }) }}<template v-if="news.imageLicense"> · {{ t('news.detail.photoLicense', { license: news.imageLicense }) }}</template>
            </small>
          </figcaption>
        </div>
      </figure>

      <div class="mx-auto max-w-page px-4 pt-8 pb-20 md:px-6 md:pt-10 md:pb-28">
        <div class="mx-auto max-w-prose">
          <div class="space-y-5 text-read text-prose">
            <p v-for="(paragraph, i) in summary" :key="i">{{ paragraph }}</p>
          </div>
          <NewsInsight v-if="news.insight" :text="news.insight" class="mt-10 block" />
          <NewsVideos v-if="news.videos.length" :videos="news.videos" class="mt-10 block" />
          <NewsRelatedLinks :items="related.data.value ?? []" class="mt-12 block" />
          <NewsSourceCard :news="news" class="mt-12" />
        </div>
      </div>
    </article>
  </div>
</template>
