<script setup lang="ts">
import type { PageContent } from '~/types/domain'

/**
 * Shell for editorial pages (Sobre mí, transparency, legal): board header + <UiProse> body
 * from guide.pages. Without a published page it shows an "en preparación" notice (no content).
 */
const props = defineProps<{
  page?: PageContent | null
  /** i18n title used while the page is not published and as the crumb. */
  title: string
  error?: unknown
  onRetry?: () => void
  /** e.g. 'noindex, follow' for legal pages (§6). */
  robots?: string
}>()
const { t, locale } = useI18n()
const mediaUrl = useMediaUrl()
const heading = computed(() => props.page?.title ?? props.title)

// Unpublished ("en preparación") and `noindex` pages stay out of the index; the legal pages pass
// `robots`. The description falls back to a per-page seo.* copy (never the site default).
const seoText = useSeoText()
const route = useRoute()
const getBaseName = useRouteBaseName()
const FALLBACK_DESCRIPTION: Record<string, string> = {
  about: 'aboutDescription',
  transparency: 'transparencyDescription',
  privacy: 'privacyDescription',
  cookies: 'cookiesDescription',
  'legal-notice': 'legalNoticeDescription',
}
usePageSeo(() => {
  const name = String(getBaseName(route) ?? '')
  return {
    title: props.page?.seoTitle ?? heading.value,
    description:
      props.page?.seoDescription ?? (FALLBACK_DESCRIPTION[name] ? seoText(FALLBACK_DESCRIPTION[name]) : undefined),
    robots: !props.page || props.page.noindex ? ROBOTS_NOINDEX_FOLLOW : props.robots,
    image: props.page?.ogImage ? mediaUrl(props.page.ogImage.path) : null,
    imageAlt: props.page?.ogImage?.alt,
    imageWidth: props.page?.ogImage?.width,
    imageHeight: props.page?.ogImage?.height,
  }
})
</script>

<template>
  <div>
    <section class="border-b-[0.5px] border-line board-tex">
      <div class="mx-auto max-w-page px-4 pt-8 pb-12 md:px-6 md:pt-10 md:pb-16">
        <UiBreadcrumbs :items="[{ label: t('nav.home'), to: '/' }, { label: heading }]" />
        <h1 class="mt-5 text-title-1 font-medium">{{ heading }}</h1>
        <p v-if="page?.revisedOn" class="mt-3 text-sm text-meta">
          {{ t('pages.lastUpdated', { date: formatDate(page.revisedOn, locale) }) }}
        </p>
      </div>
    </section>
    <section class="mx-auto max-w-page px-4 py-12 md:px-6 md:py-16">
      <slot name="before" />
      <HomeSectionError v-if="error" :on-retry="onRetry" />
      <template v-else-if="page">
        <UiProse :html="page.bodyHtml" />
        <slot name="after" />
      </template>
      <UiEmptyState
        v-else
        :title="t('pages.preparingTitle')"
        :body="t('pages.preparingBody')"
        class="max-w-read"
      >
        <template #action>
          <UiButton :to="'/'" variant="ghost">{{ t('states.notFoundHome') }}</UiButton>
        </template>
      </UiEmptyState>
    </section>
  </div>
</template>
