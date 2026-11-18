<script setup lang="ts">
/**
 * Section reveal: fade + 8 px, 300 ms, staggered 60 ms per `index`. Hidden state exists only
 * under `.reveal-ready` + prefers-reduced-motion: no-preference, and only once `reveal-ready` is on <html> (client plugin).
 */
const props = withDefaults(defineProps<{ index?: number }>(), { index: 0 })
const root = ref<HTMLElement | null>(null)
const inView = useInView(root)
</script>

<template>
  <div
    ref="root"
    data-reveal
    :class="{ 'is-in': inView }"
    :style="{ '--reveal-delay': `${props.index * 60}ms` }"
  >
    <slot />
  </div>
</template>
