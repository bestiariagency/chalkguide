<script setup lang="ts">
/**
 * Hand-drawn chalk stroke (decorative, aria-hidden), drawn once in 600 ms when it enters
 * the viewport. At most one per screen, never covering text.
 *  - underline / circle: wrap the highlighted words in the default slot.
 *  - arrow: standalone, usually next to a <UiHandNote>.
 */
const props = withDefaults(defineProps<{ variant?: 'underline' | 'circle' | 'arrow' }>(), {
  variant: 'underline',
})

const root = ref<HTMLElement | null>(null)
const inView = useInView(root)

const wrapper = computed(
  () =>
    ({
      underline: 'relative whitespace-nowrap',
      circle: 'relative inline-block',
      arrow: 'inline-block',
    })[props.variant],
)
</script>

<template>
  <span ref="root" :class="wrapper">
    <slot />
    <svg
      v-if="variant === 'underline'"
      viewBox="0 0 200 14"
      preserveAspectRatio="none"
      aria-hidden="true"
      data-draw
      :class="{ 'is-in': inView }"
      class="pointer-events-none absolute -bottom-[.18em] -left-[2%] h-[.38em] w-[104%] overflow-visible fill-none stroke-chalk [--len:220] [stroke-linecap:round] [stroke-linejoin:round]"
    >
      <path d="M3 9 C 40 4, 80 12, 120 7 S 180 5, 197 8" stroke-width="3.2" />
      <path d="M14 12 C 60 9, 120 13, 186 10" stroke-width="1.4" opacity=".55" />
    </svg>
    <svg
      v-else-if="variant === 'circle'"
      viewBox="0 0 220 60"
      preserveAspectRatio="none"
      aria-hidden="true"
      data-draw
      :class="{ 'is-in': inView }"
      class="pointer-events-none absolute -top-[24%] -left-[6%] h-[148%] w-[112%] overflow-visible fill-none stroke-chalk [--len:560] [stroke-linecap:round] [stroke-linejoin:round]"
    >
      <path
        d="M30 8 C 90 -2, 200 2, 214 26 C 224 50, 120 60, 50 54 C 6 50, 2 22, 40 10"
        stroke-width="2"
      />
    </svg>
    <svg
      v-else
      width="64"
      height="40"
      viewBox="0 0 64 40"
      aria-hidden="true"
      data-draw
      :class="{ 'is-in': inView }"
      class="overflow-visible fill-none stroke-chalk [--len:120] [stroke-linecap:round] [stroke-linejoin:round]"
    >
      <path d="M4 6 C 20 30, 40 34, 58 30" stroke-width="2" />
      <path d="M50 24 L 59 30 L 50 36" stroke-width="2" />
    </svg>
  </span>
</template>
