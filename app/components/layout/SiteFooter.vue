<script setup lang="ts">
import type { NavItem } from '~/composables/useSiteNav'

const { t } = useI18n()
const { guides } = useSiteNav()
const { options: languages } = useLanguageSwitch()
const otherLanguage = computed(() => languages.value.find((option) => !option.isCurrent))
const { linkFor, isAvailable } = usePageLinks()
const year = new Date().getFullYear()

// Under /en, pages without an English version are hidden (never a 404, never a Spanish detour).
const media = computed<NavItem[]>(() =>
  ([
    { name: 'blog', label: t('nav.blog') },
    { name: 'news', label: t('nav.news') },
    { name: 'events', label: t('nav.events') },
    { name: 'newsletter', label: t('nav.newsletter') },
    { name: 'about', label: t('nav.about') },
  ] as NavItem[]).filter((item) => isAvailable(item.name)),
)
const accounts = computed<NavItem[]>(() =>
  ([
  { name: 'transparency', label: t('footer.transparency') },
  { name: 'privacy', label: t('footer.privacy') },
  { name: 'cookies', label: t('footer.cookies') },
  { name: 'legal-notice', label: t('footer.legalNotice') },
  ] as NavItem[]).filter((item) => isAvailable(item.name)),
)
</script>

<template>
  <footer id="site-footer" class="chrome-dark">
    <div class="mx-auto max-w-page px-4 pt-16 pb-8 md:px-6 md:pt-20">
      <div class="grid gap-x-6 gap-y-12 lg:grid-cols-12">
        <div class="lg:col-span-5">
          <p><LayoutLogoLockup size="footer" :alt="t('brand.name')" /></p>
          <p class="mt-8 max-w-[20ch] text-[24px] leading-[1.2] font-medium tracking-[-0.015em] md:text-[28px]">
            {{ t('footer.promise') }}
          </p>
        </div>
        <div class="grid grid-cols-2 gap-x-6 gap-y-10 text-body-sm sm:grid-cols-3 lg:col-span-7">
          <nav :aria-label="t('footer.guides')">
            <p class="text-note font-medium text-meta">{{ t('footer.guides') }}</p>
            <ul class="mt-2">
              <li v-for="guide in guides" :key="guide.name">
                <LayoutNavLink :to="{ name: guide.name }">{{ guide.label }}</LayoutNavLink>
              </li>
            </ul>
          </nav>
          <nav :aria-label="t('footer.media')">
            <p class="text-note font-medium text-meta">{{ t('footer.media') }}</p>
            <ul class="mt-2">
              <li v-for="item in media" :key="item.name">
                <LayoutNavLink :to="{ name: item.name }" v-bind="linkFor(item.name)">{{
                  item.label
                }}</LayoutNavLink>
              </li>
              <li>
                <a
                  :href="CHALK_APP_URL"
                  class="inline-flex min-h-11 items-center text-meta transition-colors duration-150 ease-standard hover:text-foreground"
                >
                  {{ t('footer.chalkApp') }}
                </a>
              </li>
            </ul>
          </nav>
          <nav v-if="accounts.length" :aria-label="t('footer.clearAccounts')">
            <p class="text-note font-medium text-meta">{{ t('footer.clearAccounts') }}</p>
            <ul class="mt-2">
              <li v-for="item in accounts" :key="item.name">
                <LayoutNavLink :to="{ name: item.name }" v-bind="linkFor(item.name)">{{
                  item.label
                }}</LayoutNavLink>
              </li>
            </ul>
          </nav>
        </div>
      </div>
      <div
        class="mt-12 flex flex-wrap items-center justify-between gap-x-6 gap-y-1 border-t border-line-strong pt-5 text-note text-meta"
      >
        <p>{{ t('footer.copyright', { year }) }}</p>
        <NuxtLink
          v-if="otherLanguage?.to"
          :to="otherLanguage.to"
          :lang="otherLanguage.code"
          :hreflang="otherLanguage.code"
          class="inline-flex min-h-11 items-center transition-colors duration-150 hover:text-foreground"
        >
          {{ t(otherLanguage.code === 'en' ? 'nav.languageEn' : 'nav.languageEs') }}
        </NuxtLink>
      </div>
    </div>
  </footer>
</template>
