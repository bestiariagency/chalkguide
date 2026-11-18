<script setup lang="ts">
/**
 * Scroll bar (56 px): out of the way while scrolling down, back when scrolling up, never at the
 * top of the page. Left column stays empty: the scroll dock sits there. `visible` and the
 * spy come from `useScrollChrome`/`useSectionSpy` in the layout; the bar is inert while hidden.
 */
const props = defineProps<{ visible: boolean; spy?: string | null }>()
const { t } = useI18n()
const menu = useMobileMenu()
const el = ref<HTMLElement | null>(null)
defineExpose({ el })
</script>

<template>
  <div
    ref="el"
    class="chrome-dark fixed inset-x-0 top-0 z-40 h-14 bg-background text-foreground"
    :class="
      props.visible
        ? 'visible translate-y-0 [transition:translate_420ms_var(--ease-out),visibility_0s] motion-reduce:[transition:visibility_0s]'
        : 'invisible -translate-y-[104%] [transition:translate_320ms_cubic-bezier(.5,0,.9,.4),visibility_0s_linear_320ms] motion-reduce:[transition:visibility_0s]'
    "
    :aria-hidden="!props.visible"
    :inert="!props.visible || undefined"
  >
    <div
      class="mx-auto grid h-full max-w-page grid-cols-[1fr_auto] items-center gap-6 px-4 md:px-6 lg:grid-cols-[1fr_auto_1fr]"
    >
      <span aria-hidden="true" />
      <nav :aria-label="t('nav.mainCompact')" class="hidden lg:block">
        <LayoutMainNav compact :spy="props.visible ? props.spy : null" />
      </nav>
      <div class="flex items-center justify-self-end lg:gap-2">
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
</template>
