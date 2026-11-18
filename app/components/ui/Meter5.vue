<script setup lang="ts">
/**
 * 5-segment meter (more is more: family index, variety). Half segments for .5 values.
 * Decorative: the figure is always shown next to it, so it is hidden from assistive tech.
 */
const props = defineProps<{ value: number | null }>()
const segments = computed(() =>
  [1, 2, 3, 4, 5].map((i) => {
    const v = props.value ?? 0
    return v >= i - 0.25 ? 'full' : v >= i - 0.75 ? 'half' : 'off'
  }),
)
</script>

<template>
  <span class="inline-flex gap-[3px]" aria-hidden="true">
    <i
      v-for="(state, index) in segments"
      :key="index"
      class="h-1.5 w-3 rounded-xs"
      :class="state === 'full' ? 'bg-chalk' : 'bg-(--bar-track)'"
      :style="state === 'half' ? { background: 'linear-gradient(90deg, var(--color-chalk) 50%, var(--bar-track) 50%)' } : undefined"
    />
  </span>
</template>
