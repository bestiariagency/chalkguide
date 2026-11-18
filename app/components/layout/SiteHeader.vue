<script setup lang="ts">
const { t } = useI18n()
const menu = useMobileMenu()
const masthead = ref<HTMLElement | null>(null)
defineExpose({ masthead })
</script>

<template>
  <header ref="masthead" class="chrome-dark">
    <div class="mx-auto max-w-page px-4 md:px-6">
      <div class="flex h-16 items-center justify-between gap-4 md:h-20">
        <NuxtLinkLocale
          to="/"
          :aria-label="t('brand.homeLabel')"
          class="flex min-h-11 items-center"
        >
          <LayoutLogoLockup size="header" />
        </NuxtLinkLocale>
        <nav :aria-label="t('nav.main')" class="hidden lg:block">
          <LayoutMainNav />
        </nav>
        <div class="flex items-center gap-2">
          <LayoutSignOutButton icon-only class="max-lg:hidden" />
          <LayoutLanguageSwitcher class="hidden lg:flex" />
          <LayoutBurger
            class="lg:hidden [html:not(.js)_&]:hidden"
            aria-controls="mobile-menu"
            :open="menu.isOpen.value"
            :label="menu.isOpen.value ? t('nav.menu.close') : t('nav.menu.open')"
            @click="menu.open"
          />
        </div>
      </div>
    </div>
  </header>
</template>
