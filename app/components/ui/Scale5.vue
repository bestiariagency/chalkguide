<script setup lang="ts">
/**
 * Neutral 1-5 ruler (grading, style): five marks and one ink dot, no number and no accent,
 * because it describes, it does not rate (README §9.9.2). Decorative: the parent writes the
 * word and the screen-reader text (`gyms.scale.srValue`).
 */
const props = withDefaults(
  defineProps<{
    value: number | null
    /** `sm` for cards (64 px), `lg` for the detail page (full width). */
    size?: 'sm' | 'lg'
    /** Colour of the surface behind it (the dot's ring). */
    surface?: 'background' | 'board'
  }>(),
  { size: 'sm', surface: 'background' },
)
const left = computed(() =>
  props.value === null ? null : `${(Math.min(5, Math.max(1, props.value)) - 1) * 25}%`,
)
</script>

<template>
  <span
    class="relative block shrink-0"
    :class="size === 'sm' ? 'h-2.5 w-16' : 'h-3.5 w-full'"
    aria-hidden="true"
  >
    <span
      class="absolute inset-x-0 flex justify-between bg-line-strong"
      :class="size === 'sm' ? 'top-1 h-0.5' : 'top-[6px] h-0.5'"
    >
      <i
        v-for="mark in 5"
        :key="mark"
        class="w-0.5 rounded-[1px] bg-control"
        :class="size === 'sm' ? '-mt-[3px] h-2' : '-mt-1 h-2.5'"
      />
    </span>
    <span
      v-if="left !== null"
      class="absolute top-0 rounded-full bg-foreground"
      :class="[
        size === 'sm' ? 'size-2.5 -ml-[5px] ring-2' : 'size-3.5 -ml-[7px] ring-[3px]',
        surface === 'board' ? 'ring-board' : 'ring-background',
      ]"
      :style="{ left }"
    />
  </span>
</template>
