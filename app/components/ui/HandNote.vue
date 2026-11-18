<script setup lang="ts">
/**
 * Caveat 500 for short phrases only (≤ 2 lines, ≥ 22 px): author quote, "Lo que aprendí",
 * chalkboard heading. Never paragraphs, buttons, labels or data (prices, times).
 *  - quote: handwritten text in the default slot; optional #caption (Inter, meta).
 *  - learned: `title` in handwriting (accent) + body in Inter 17/1.7 in the default slot.
 *  - heading: large board heading ("Octubre"); optional #caption rendered as label-mini.
 */
withDefaults(
  defineProps<{
    variant?: 'quote' | 'learned' | 'heading'
    title?: string
    as?: string
  }>(),
  { variant: 'quote', title: undefined, as: 'p' },
)
</script>

<template>
  <div v-if="variant === 'learned'" class="border-l-2 border-accent pl-4">
    <p class="font-hand text-[26px] leading-tight text-accent">{{ title }}</p>
    <div class="mt-1 text-lead"><slot /></div>
  </div>
  <div v-else>
    <component
      :is="as"
      class="-rotate-1 font-hand"
      :class="variant === 'heading' ? 'text-hand-lg' : 'text-[28px] leading-[1.15]'"
    >
      <slot />
    </component>
    <p
      v-if="$slots.caption"
      :class="variant === 'heading' ? 'mt-3 label-mini' : 'mt-3 text-caption text-meta'"
    >
      <slot name="caption" />
    </p>
  </div>
</template>
