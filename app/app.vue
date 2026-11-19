<script setup lang="ts">
const { t, locale } = useI18n()
const site = useSiteConfig()
const siteUrl = useSiteUrl()
const route = useRoute()
const onAdmin = computed(() => isAdminPath(route.path))

// lang/dir, title template, canonical, hreflang (only versions that exist, D3), og:url/locale
// and the route-level robots rules (legal, utility, newsletter states).
useSiteSeo()

// Site-wide defaults. Pages override them with their own usePageSeo (title, description,
// og:*, twitter:*, image); the default share image is /og-default[-en].png.
usePageSeo(() => ({ title: t('seo.defaultTitle'), description: t('seo.defaultDescription') }))

// Organization + WebSite (JSON-LD) for every page.
const { data: settings } = await useSiteSettings()
useJsonLd('site', () =>
  siteGraphLd({
    siteUrl,
    name: String(site.name || 'ChalkGuide'),
    description: t('seo.defaultDescription'),
    logoUrl: `${siteUrl}/icon-512.png`,
    sameAs: Object.values(settings.value?.socialLinks ?? {}).filter((url) => /^https?:\/\//.test(url)),
    locale: locale.value === 'en' ? 'en' : 'es',
  }),
)
</script>

<template>
  <!-- Mount point of the cookie banner (D86): filled on the client only, hidden on the panel. -->
  <div id="cc-root" :hidden="onAdmin || undefined" />
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
</template>
