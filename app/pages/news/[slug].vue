<script setup lang="ts">
import { ArrowLeft } from 'lucide-vue-next'

/**
 * News page (F8, §15.3): paper family, 640 px column. Header with the "Resumen de ChalkGuide ·
 * Fuente" mark, optional image (licensed), the summary, the "Nota de Xavi" if it exists, the original
 * source (always) and related links. Indexable only with a note of >= ~60 words (D73, D79); without
 * it `noindex, follow`. 404 if missing or, under /en, without an English version (D3). All text is
 * plain and interpolated (F8.1 F1).
 */
const { t, locale } = useI18n()
const route = useRoute()
const slug = computed(() => String(route.params.slug))
const { linkFor } = usePageLinks()

const { data: news } = await useNewsItem(slug)
useDetailLocales(news.value, 'news')
const current = computed(() => news.value!)
const [related, more] = await Promise.all([
  useNewsRelated(() => current.value.id),
  useMoreNews(() => current.value.id),
])

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
const scopeLabel = computed(() => (current.value.scope ? t(`news.scope.${current.value.scope}`) : null))

const mediaUrl = useMediaUrl()
usePageSeo(() => ({
  title: current.value.title,
  description: newsSeoDescription(current.value),
  image: current.value.image ? mediaUrl(current.value.image.path) : null,
  imageAlt: current.value.image?.alt,
  imageWidth: current.value.image?.width,
  imageHeight: current.value.image?.height,
  type: 'article',
  publishedTime: current.value.publishedAt,
  modifiedTime: current.value.updatedAt,
  robots: isNewsIndexable({ note: current.value.note }) ? undefined : ROBOTS_NOINDEX_FOLLOW,
}))
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
          <p class="mt-5 text-body-sm font-medium text-meta md:mt-6">
            <template v-if="scopeLabel">{{ scopeLabel }} · </template>
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
            <span>{{ t('news.markSource') }} <UiTextLink href="#source" class="font-medium">{{ news.sourceName }}</UiTextLink></span>
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

      <div class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10">
        <div class="mx-auto max-w-prose">
          <div class="space-y-5 text-read text-prose">
            <p v-for="(paragraph, i) in summary" :key="i">{{ paragraph }}</p>
          </div>
          <NewsNote v-if="news.note" :note="news.note" signed large :date="news.publishedAt" class="mt-10" />
          <NewsSourceCard :news="news" class="mt-10" />
          <p class="mt-4 text-caption text-meta">
            {{ t('news.detail.transparency') }}
            <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')" class="text-foreground">{{ t('news.detail.howWeDoIt') }}</UiTextLink>
          </p>
          <NewsRelatedLinks :items="related.data.value ?? []" class="mt-10 block" />
        </div>
      </div>
    </article>

    <section v-if="more.data.value?.length" class="mx-auto max-w-page px-4 pt-16 pb-20 md:px-6 md:pt-24 md:pb-28" aria-labelledby="news-more-title">
      <div class="flex items-end justify-between gap-4">
        <h2 id="news-more-title" class="text-[22px] font-medium tracking-[-.015em] md:text-[26px]">{{ t('news.detail.more') }}</h2>
        <NuxtLinkLocale :to="{ name: 'news' }" class="link-underline hidden min-h-11 items-center text-body-sm font-medium sm:inline-flex">
          {{ t('news.allNews') }}
        </NuxtLinkLocale>
      </div>
      <ul class="mt-4 border-t border-foreground">
        <li v-for="item in more.data.value" :key="item.id" class="border-b border-line-strong">
          <NewsRow :news="item" variant="compact" />
        </li>
      </ul>
      <UiButton :to="{ name: 'news' }" variant="ghost" class="mt-6 w-full sm:hidden">{{ t('news.allNews') }}</UiButton>
    </section>
  </div>
</template>
