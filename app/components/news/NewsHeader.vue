<script setup lang="ts">
import { Search } from 'lucide-vue-next'
import type { BreadcrumbItem } from '~/types/ui'
import type { NewsCategoryNavItem, NewsScope } from '~/types/news'

/**
 * Header of the index and of the categories (ListingHeader pattern of /blog, §15.2): breadcrumbs,
 * H1, lede and search (`/` from `lg`); below, category chips (routes) and the scope filter (state).
 * Under `lg` a 44 px button opens the search field in place of the chips.
 */
const props = defineProps<{
  crumbs: BreadcrumbItem[]
  title: string
  lede: string
  eyebrow?: string
  nav: { items: NewsCategoryNavItem[]; total: number } | null | undefined
  current?: string | null
  tooShort: boolean
}>()
const query = defineModel<string>('query', { default: '' })
const scope = defineModel<NewsScope | null>('scope', { default: null })
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
  opened.value = false
  await nextTick()
  searchButton.value?.focus()
}
function onFocusOut() {
  if (!query.value) opened.value = false
}
</script>

<template>
  <section class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10">
    <UiBreadcrumbs :items="crumbs" />
    <div class="mt-5 grid items-end gap-x-6 gap-y-4 lg:grid-cols-12">
      <div class="lg:col-span-8">
        <p v-if="eyebrow" class="label-mini mb-3 !text-accent">{{ eyebrow }}</p>
        <h1 class="title-section">{{ title }}</h1>
        <p class="mt-3 max-w-[56ch] text-[17px] leading-[1.6] text-meta md:mt-4 md:text-[18px]">{{ lede }}</p>
      </div>
      <UiSearchField
        :id="fieldId"
        ref="field"
        v-model="query"
        shortcut
        hide-label
        class="max-lg:order-last lg:col-span-4"
        :class="showField ? '' : 'max-lg:hidden'"
        :label="t('common.search.label')"
        :clear-label="t('common.search.clear')"
        :placeholder="t('news.searchPlaceholder')"
        @shortcut="opened = true"
        @keydown.esc.capture="onEscape"
        @focusout="onFocusOut"
      />
    </div>
    <p class="text-body-sm text-meta" :class="tooShort ? 'mt-2' : ''" role="status">
      {{ tooShort ? t('news.search.tooShort') : '' }}
    </p>
    <div class="mt-4 flex items-center gap-2 md:mt-6">
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
      <div v-if="nav" class="min-w-0 flex-1" :class="showField ? 'max-lg:hidden' : ''">
        <NewsCategoryNav :items="nav.items" :total="nav.total" :current="props.current" />
      </div>
    </div>
    <NewsScopeFilter v-model="scope" class="mt-3" />
  </section>
</template>
