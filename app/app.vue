<script setup lang="ts">
const { t } = useI18n()

// lang/dir on <html>, hreflang alternates, canonical and og:locale from @nuxtjs/i18n.
const i18nHead = useLocaleHead()

useHead(() => ({
  htmlAttrs: {
    lang: i18nHead.value.htmlAttrs.lang,
    dir: i18nHead.value.htmlAttrs.dir,
  },
  link: [...(i18nHead.value.link ?? [])],
  meta: [...(i18nHead.value.meta ?? [])],
}))

// Site-wide SEO defaults. Pages override title/description with their own useSeoMeta.
useSeoMeta({
  title: () => t('seo.defaultTitle'),
  description: () => t('seo.defaultDescription'),
  ogType: 'website',
  ogSiteName: 'ChalkGuide',
  ogTitle: () => t('seo.defaultTitle'),
  ogDescription: () => t('seo.defaultDescription'),
  // TODO: add ogImage / twitterImage once a default share image exists.
  twitterCard: 'summary_large_image',
  twitterTitle: () => t('seo.defaultTitle'),
  twitterDescription: () => t('seo.defaultDescription'),
})
</script>

<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
