<script setup lang="ts">
/**
 * Home (D44, D77): hero carousel · por dónde empiezas · rocódromos · Chalk app · pies de gato · blog · noticias.
 * The orange newsletter block comes from the layout.
 * One query per domain, fetched in parallel; in English only content with an English version.
 */
import archivoLatin from '@fontsource-variable/archivo/files/archivo-latin-wdth-normal.woff2?url'

const { t } = useI18n()

// Archivo draws the hero H1 (the text LCP): preload it so the title does not swap fonts late.
useHead({ link: [{ rel: 'preload', as: 'font', type: 'font/woff2', href: archivoLatin, crossorigin: 'anonymous' }] })

const [articles, gyms, shoes, events, settings, news] = await Promise.all([
  useArticles('home', { limit: 5 }),
  useGyms('all'),
  useShoes('home-latest'),
  useNextEvents(),
  useSiteSettings(),
  useHomeNews(),
])

const articleSplit = computed(() => splitHomeArticles(articles.data.value ?? []))
const blog = computed(() => articleSplit.value.blog)
// D77 B: the news block needs at least 2 items, never a list of one.
const homeNews = computed(() => (news.data.value?.length ?? 0) >= 2 ? (news.data.value ?? []) : [])
const homeGyms = computed(() => pickHomeGyms(gyms.data.value ?? []))
const homeShoes = computed(() => pickLatestShoes(shoes.data.value ?? []))
const heroCards = useHeroCards(() => ({
  photos: settings.data.value?.heroPhotos ?? [],
  shoes: pickHeroShoes(shoes.data.value ?? []),
  event: pickHeroEvent(events.data.value ?? []),
  gyms: pickHeroGyms(gyms.data.value ?? [], articleSplit.value.latest?.cover?.path),
  article: articleSplit.value.latest,
}))

usePageSeo(() => ({ title: t('seo.homeTitle'), description: t('seo.homeDescription') }))
</script>

<template>
  <div>
    <HomeHeroCarousel :cards="heroCards" />

    <UiReveal><HomeProfilePaths /></UiReveal>

    <UiReveal v-if="homeGyms.length">
      <GymsHomeTable :gyms="homeGyms" :total="gyms.data.value?.length ?? 0" />
    </UiReveal>
    <div v-else-if="gyms.error.value" class="mx-auto max-w-page px-4 py-16 md:px-6">
      <HomeSectionError :on-retry="() => gyms.refresh()" />
    </div>

    <UiReveal><HomePartnerTeaser /></UiReveal>

    <UiReveal v-if="homeShoes.length"><ShoesGlance :shoes="homeShoes" /></UiReveal>
    <div v-else-if="shoes.error.value" class="mx-auto max-w-page px-4 py-16 md:px-6">
      <HomeSectionError :on-retry="() => shoes.refresh()" />
    </div>

    <UiReveal v-if="blog.length"><HomeBlogSection :articles="blog" /></UiReveal>

    <UiReveal v-if="homeNews.length"><HomeNews :news="homeNews" /></UiReveal>
  </div>
</template>
