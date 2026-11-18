<script setup lang="ts">
/**
 * Sobre mí (editorial v2, §13.8, D51): ink head with the author's sentence as H1 and the 4:5 photo,
 * "En números", the page body (guide.pages `about`), "Lo último que he comprobado" and "Escríbeme".
 * Every block without data is left out; nothing is filled in.
 */
const { t } = useI18n()
const { linkFor } = usePageLinks()
const { page, error, refresh } = await useEditorialPage('about')
const { data: settings } = await useSiteSettings()
const { data: numbers } = await useAboutNumbers()
const author = computed(() => settings.value?.author ?? null)
const { name } = useAuthor()
const email = computed(() => settings.value?.contactEmail?.trim() || null)
const title = computed(() => page.value?.title ?? t('nav.about'))

// Same SEO rules as the other editorial pages: unpublished or `noindex` stays out of the index.
const seoText = useSeoText()
const mediaUrl = useMediaUrl()
usePageSeo(() => ({
  title: page.value?.seoTitle ?? title.value,
  description: page.value?.seoDescription ?? seoText('aboutDescription'),
  robots: !page.value || page.value.noindex ? ROBOTS_NOINDEX_FOLLOW : undefined,
  image: page.value?.ogImage ? mediaUrl(page.value.ogImage.path) : null,
  imageAlt: page.value?.ogImage?.alt,
  imageWidth: page.value?.ogImage?.width,
  imageHeight: page.value?.ogImage?.height,
}))

// The page is about its author: ProfilePage → Person (README §6, "señal de autoría").
const absolute = useAbsoluteUrl()
const route = useRoute()
useJsonLd('about', () =>
  page.value
    ? {
        '@context': 'https://schema.org',
        '@type': 'ProfilePage',
        mainEntity: { ...personLd(absolute(route.path)), name: name.value },
      }
    : null,
)
</script>

<template>
  <div>
    <AboutHero :author="author" :title="title" />
    <AboutNumbers
      :written="author?.stats ?? []"
      :gyms="numbers?.gyms ?? 0"
      :shoes="numbers?.shoes ?? 0"
      :has-photo="!!author?.photo"
    />

    <section class="mx-auto max-w-page px-4 pt-16 md:px-6 md:pt-24">
      <HomeSectionError v-if="error" :on-retry="refresh" />
      <div v-else-if="page" class="lg:grid lg:grid-cols-12 lg:gap-x-6">
        <div class="about-body lg:col-span-7 lg:col-start-4">
          <UiProse :html="page.bodyHtml" />
          <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')" class="mt-6 inline-flex min-h-11 items-center">
            {{ t('transparency.learnMore') }}
          </UiTextLink>
        </div>
      </div>
      <UiEmptyState v-else :title="t('pages.preparingTitle')" :body="t('pages.preparingBody')" class="max-w-read">
        <template #action>
          <UiButton :to="'/'" variant="ghost">{{ t('states.notFoundHome') }}</UiButton>
        </template>
      </UiEmptyState>
    </section>

    <AboutLatest :items="numbers?.latest ?? []" />
    <AboutContact v-if="email" :email="email" />
    <div v-else class="pb-16 md:pb-24" />
  </div>
</template>

<style scoped>
/* CSS fallback: "Cómo trabajo" (h2 + ol del editor) como filas numeradas con contador CSS; Tailwind no genera ::before con counter() sobre HTML del editor. */
.about-body :deep(h2 + ol) {
  counter-reset: how;
  margin-top: 1.25rem;
  padding: 0;
  list-style: none;
  border-top: 1px solid var(--color-foreground);
}
.about-body :deep(h2 + ol > li) {
  counter-increment: how;
  display: grid;
  grid-template-columns: 40px minmax(0, 1fr);
  gap: 12px;
  margin: 0;
  padding: 20px 0;
  border-bottom: 1px solid var(--color-line-strong);
  color: var(--color-foreground);
}
.about-body :deep(h2 + ol > li)::before {
  content: counter(how, decimal-leading-zero);
  font-family: var(--font-mono);
  font-size: 14px;
  line-height: 1.9;
  color: var(--color-accent);
}
@media (min-width: 768px) {
  .about-body :deep(h2 + ol > li) {
    grid-template-columns: 64px minmax(0, 1fr);
    padding: 24px 0;
  }
}
</style>
