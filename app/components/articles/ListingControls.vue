<script setup lang="ts">
import { Search } from 'lucide-vue-next'
import type { CategoryNavItem } from '~/types/domain'

/**
 * Listing controls (§13.6): category chips and search in one row. From `lg` the chips sit on the
 * left and the field (4 columns, `/` shortcut) on the right. Below `lg` a 44 button comes first
 * and opens the field in place of the chips.
 */
const props = defineProps<{
  nav: { items: CategoryNavItem[]; total: number } | null | undefined
  tooShort: boolean
  current?: string | null
}>()
const query = defineModel<string>('query', { default: '' })
const { t } = useI18n()

const opened = ref(false)
const searchButton = ref<HTMLButtonElement | null>(null)
const fieldId = useId()
const field = ref<{ focus: () => void } | null>(null)
const showField = computed(() => opened.value || query.value.length > 0)

async function openField() {
  opened.value = true
  await nextTick()
  field.value?.focus()
}
async function onEscape() {
  if (query.value || !opened.value) return
  // Close first so the button renders, then move focus to it (otherwise it falls to <body>).
  opened.value = false
  await nextTick()
  searchButton.value?.focus()
}
function onFocusOut() {
  if (!query.value) opened.value = false
}
</script>

<template>
  <div class="mt-6">
    <div class="flex items-end gap-2 lg:justify-between lg:gap-8">
      <button
        v-if="!showField"
        ref="searchButton"
        type="button"
        :aria-expanded="showField"
        :aria-controls="fieldId"
        class="grid size-11 shrink-0 place-items-center rounded-sm border border-control text-foreground hover:border-meta hover:bg-elevated lg:hidden"
        :aria-label="t('common.search.label')"
        @click="openField"
      >
        <Search :size="18" aria-hidden="true" />
      </button>
      <div v-if="nav" class="min-w-0 flex-1" :class="showField ? 'hidden lg:block' : ''">
        <ArticlesCategoryNav :items="nav.items" :total="nav.total" :current="props.current" />
      </div>
      <UiSearchField
        :id="fieldId"
        ref="field"
        v-model="query"
        shortcut
        hide-label
        class="w-full lg:w-[360px] lg:shrink-0"
        :class="showField ? '' : 'hidden lg:block'"
        :label="t('common.search.label')"
        :clear-label="t('common.search.clear')"
        :placeholder="t('blog.search.placeholder')"
        @shortcut="opened = true"
        @keydown.esc.capture="onEscape"
        @focusout="onFocusOut"
      />
    </div>
    <p class="text-body-sm text-meta" :class="tooShort ? 'mt-2' : ''" role="status">
      {{ tooShort ? t('blog.search.tooShort') : '' }}
    </p>
  </div>
</template>
