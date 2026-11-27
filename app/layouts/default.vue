<script setup lang="ts">
/**
 * Public layout: skip link, header (+ scroll bar and dock), mobile menu,
 * newsletter block, footer and the toast region.
 * A page can hide the newsletter block with definePageMeta({ newsletterBlock: false }).
 */
import type { NewsletterSource } from '~/services/newsletter'

const { t } = useI18n()
const route = useRoute()

const header = ref<{ masthead: HTMLElement | null } | null>(null)
const masthead = computed(() => header.value?.masthead ?? null)
const mastheadVisible = useIntersecting(masthead)

const bar = ref<{ el: HTMLElement | null } | null>(null)
const pastMasthead = computed(() => !mastheadVisible.value)
const { barVisible } = useScrollChrome(
  pastMasthead,
  computed(() => bar.value?.el ?? null),
)
// Section tracking in the bar: only the home has sections with a nav link.
const getRouteBaseName = useRouteBaseName()
const onHome = computed(() => getRouteBaseName(route) === 'index')
const spy = useSectionSpy(onHome)

const { isOpen: menuOpen } = useMobileMenu()
// F8: the /noticias section (list, category, detail) tags its sign-ups with the `noticias` origin.
const newsletterSource = computed<NewsletterSource>(() => (String(getRouteBaseName(route) ?? '').startsWith('news') ? 'noticias' : 'footer'))
const showNewsletter = computed(() => route.meta.newsletterBlock !== false)
</script>

<template>
  <div>
    <!-- Everything but the mobile menu and the toasts goes inert while the menu is open. -->
    <div class="flex min-h-dvh flex-col" :inert="menuOpen || undefined">
      <a
        href="#main"
        class="sr-only rounded-md bg-accent-fill px-3 py-2 text-on-accent focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[80]"
      >
        {{ t('nav.skipToContent') }}
      </a>
      <LayoutStickyBar ref="bar" :visible="barVisible" :spy="spy" />
      <LayoutScrollDock :visible="pastMasthead" :bar-visible="barVisible" />
      <LayoutSiteHeader ref="header" />
      <NewsletterNotice />
      <main id="main" tabindex="-1" class="flex-1 overflow-x-clip focus-visible:shadow-none">
        <slot />
      </main>
      <NewsletterField v-if="showNewsletter" :source="newsletterSource" anchor />
      <LayoutSiteFooter />
    </div>
    <LayoutMobileMenu />
    <UiToastRegion />
  </div>
</template>
