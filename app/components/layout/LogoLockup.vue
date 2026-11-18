<script setup lang="ts">
/**
 * logo-white.svg + "BCN" (label-mini), per the logo rules: the tag is not part of the
 * logo, sits ≥ 2x to the right, and its baseline aligns with the wordmark's (19.2 % of the
 * logo height from the bottom). Header: 22 → 28 px; footer: 24 px.
 */
const props = withDefaults(defineProps<{ size?: 'header' | 'footer'; alt?: string }>(), {
  size: 'header',
  alt: '',
})
const { t } = useI18n()
const sizing = computed(() =>
  props.size === 'header'
    ? 'gap-3 [--logo-h:22px] md:gap-4 md:[--logo-h:28px]'
    : 'gap-3 [--logo-h:24px]',
)
</script>

<template>
  <span class="flex items-end" :class="sizing">
    <img
      src="/brand/logo-white.svg"
      :alt="alt"
      width="2073"
      height="384"
      class="block h-(--logo-h) w-auto"
    />
    <span class="pb-[calc(var(--logo-h)*0.192-2px)] label-mini" aria-hidden="true">
      {{ t('brand.city') }}
    </span>
  </span>
</template>
