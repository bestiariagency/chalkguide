<script setup lang="ts">
import { Check } from 'lucide-vue-next'

/** Filter chip: toggle button with aria-pressed. Group chips in role="group" with a label. */
defineProps<{ disabled?: boolean; compact?: boolean }>()
const pressed = defineModel<boolean>('pressed', { default: false })
</script>

<template>
  <button
    type="button"
    :aria-pressed="pressed"
    :disabled="disabled"
    :class="compact ? 'min-h-11 px-2.5 text-caption [@media(hover:hover)_and_(pointer:fine)]:min-h-9' : 'min-h-11 px-[.85rem]'"
    class="inline-flex items-center gap-1.5 rounded-sm border border-control text-body-sm font-medium text-foreground transition-[background-color,border-color,color,transform] duration-200 ease-standard not-disabled:active:scale-[.97] disabled:cursor-not-allowed disabled:opacity-50 aria-pressed:border-accent aria-pressed:bg-accent-muted aria-pressed:text-accent [&:not([aria-pressed=true]):not(:disabled)]:hover:border-meta [&:not([aria-pressed=true]):not(:disabled)]:hover:bg-elevated"
    @click="pressed = !pressed"
  >
    <span
      class="inline-flex overflow-hidden transition-[width,opacity] duration-200 ease-out"
      :class="pressed ? 'w-3.5 opacity-100' : 'w-0 opacity-0'"
      aria-hidden="true"
    >
      <Check :size="14" />
    </span>
    <slot />
  </button>
</template>
