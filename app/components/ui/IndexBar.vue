<script setup lang="ts">
/**
 * Index bar (design system): elevated track + accent fill that grows once on entering the
 * viewport. Decorative: the figure is always shown next to it (color never alone), unless
 * `label` is given, in which case the bar itself is announced (role="img").
 */
const props = withDefaults(defineProps<{ value: number | null; max?: number; label?: string }>(), {
  max: 5,
  label: undefined,
})
const root = ref<HTMLElement | null>(null)
const inView = useInView(root)
const width = computed(() =>
  props.value === null ? '0%' : `${Math.max(0, Math.min(1, props.value / props.max)) * 100}%`,
)
</script>

<template>
  <span
    ref="root"
    class="block h-1 overflow-hidden rounded-full bg-(--bar-track)"
    :role="label ? 'img' : undefined"
    :aria-label="label"
    :aria-hidden="label ? undefined : 'true'"
  >
    <span
      class="block h-full origin-left rounded-full bg-chalk motion-safe:transition-transform motion-safe:delay-100 motion-safe:duration-[600ms] motion-safe:ease-out"
      :class="inView ? 'scale-x-100' : 'motion-safe:[.js_&]:scale-x-0'"
      :style="{ width }"
    />
  </span>
</template>
