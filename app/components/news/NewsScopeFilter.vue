<script setup lang="ts">
import type { NewsScope } from '~/types/news'

/**
 * Scope filter (§15.2): text buttons with `aria-pressed` and a 2 px chalk underline on the active
 * one, 44 px high. Category is a route; scope is a state of the UI (`?alcance=`, canonical without query).
 */
defineProps<{ modelValue: NewsScope | null }>()
defineEmits<{ 'update:modelValue': [value: NewsScope | null] }>()
const { t } = useI18n()
const options: (NewsScope | null)[] = [null, ...NEWS_SCOPES]
</script>

<template>
  <div class="-mx-4 flex items-center gap-1 overflow-x-auto px-4 md:mx-0 md:px-0" role="group" :aria-label="t('news.scopeLabel')">
    <span class="mr-2 text-caption whitespace-nowrap text-meta">{{ t('news.scopeLabel') }}</span>
    <button
      v-for="option in options"
      :key="option ?? 'all'"
      type="button"
      :aria-pressed="modelValue === option"
      class="inline-flex min-h-11 items-center gap-1.5 rounded-md px-3 text-body-sm whitespace-nowrap text-meta transition-colors duration-150 hover:bg-elevated hover:text-foreground aria-pressed:rounded-b-none aria-pressed:font-medium aria-pressed:text-foreground aria-pressed:shadow-[inset_0_-2px_0_var(--color-chalk)]"
      @click="$emit('update:modelValue', option)"
    >
      {{ t(`news.scope.${option ?? 'all'}`) }}
    </button>
  </div>
</template>
