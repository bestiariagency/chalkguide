<script setup lang="ts">
/**
 * 1–5 score (the global one, required, or one criterion, optional and clearable). Native radios (arrow keys, Tab and screen readers for free)
 * inside a fieldset; the numbers are the visible control (44px targets).
 */
defineProps<{
  name: string
  label: string
  invalid?: boolean
  /** Optional scores can be cleared with a "remove" button; required ones cannot. */
  clearable?: boolean
  /** Visual weight: the global score is bigger and its legend stronger. */
  prominent?: boolean
  /** Help text under the legend (D29); empty = nothing is rendered. */
  help?: string | null
}>()
const model = defineModel<number | null>({ default: null })
const { t } = useI18n()
const helpId = useId()

const group = ref<HTMLElement | null>(null)
/** Clears the score and returns focus to the first option (the button disappears). */
async function clear() {
  model.value = null
  await nextTick()
  group.value?.querySelector<HTMLInputElement>('input')?.focus()
}
</script>

<template>
  <fieldset>
    <legend class="mb-2 flex items-center gap-2" :class="prominent ? 'text-body font-medium' : 'text-body-sm'">
      {{ label }}
      <span v-if="invalid" class="text-note text-danger-text">{{ t('reviews.missing') }}</span>
    </legend>
    <p v-if="help" :id="helpId" class="-mt-1 mb-2 max-w-prose text-caption text-meta">{{ help }}</p>
    <div class="flex flex-wrap items-center gap-x-1.5">
    <div ref="group" class="flex gap-1.5" role="radiogroup" :aria-label="t('reviews.ratingGroup', { label })" :aria-describedby="help ? helpId : undefined">
      <label v-for="n in 5" :key="n" class="group/score relative">
        <input
          v-model="model"
          type="radio"
          :name="name"
          :value="n"
          :aria-label="t('reviews.scoreOption', { n, max: 5 })"
          :aria-invalid="invalid || undefined"
          class="peer absolute inset-0 m-0 size-full cursor-pointer opacity-0"
        />
        <span
          class="grid size-11 place-items-center rounded-md border border-control font-mono text-body-sm text-meta transition-[background-color,border-color,color,transform] duration-200 ease-standard peer-checked:border-accent-fill peer-checked:bg-accent-fill peer-checked:text-on-accent peer-focus-visible:shadow-[var(--ring)] peer-active:scale-[.96] motion-reduce:transition-none [@media(hover:hover)]:group-hover/score:border-meta [@media(hover:hover)]:group-hover/score:text-foreground peer-checked:[@media(hover:hover)]:group-hover/score:border-accent peer-checked:[@media(hover:hover)]:group-hover/score:text-on-accent"
          :class="invalid && 'border-danger-text'"
          aria-hidden="true"
        >
          {{ n }}
        </span>
      </label>
    </div>
      <button
        v-if="clearable && model !== null"
        type="button"
        class="ml-1 inline-flex min-h-11 items-center rounded-md px-2 text-caption text-meta underline underline-offset-4 hover:text-foreground focus-visible:shadow-[var(--ring)]"
        :aria-label="t('reviews.clearScore', { label })"
        @click="clear"
      >
        {{ t('reviews.clear') }}
      </button>
    </div>
  </fieldset>
</template>
