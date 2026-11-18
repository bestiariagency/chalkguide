<script setup lang="ts">
import type { NewsSearchStatus } from '~/composables/useNewsSearch'
import type { NewsSearchHit, NewsSummary } from '~/types/news'

/**
 * Body of the index and of the categories: search results, or featured + weeks + pager, with the
 * error and empty states. `emptyKind` picks the copy of the empty state (nothing yet, category, scope).
 */
defineProps<{
  searchActive: boolean
  term: string
  status: NewsSearchStatus
  hits: NewsSearchHit[]
  total: number
  loadingMore: boolean
  hasMore: boolean
  featured: NewsSummary | null
  items: NewsSummary[]
  page: number
  pages: number
  error: boolean
  scoped: boolean
  isCategory: boolean
}>()
defineEmits<{ retry: []; more: []; clear: []; refresh: []; 'clear-scope': [] }>()
const { t, locale } = useI18n()
</script>

<template>
  <div>
    <NewsSearchResults
      v-if="searchActive"
      :term="term"
      :status="status"
      :hits="hits"
      :total="total"
      :loading-more="loadingMore"
      :has-more="hasMore"
      @retry="$emit('retry')"
      @more="$emit('more')"
      @clear="$emit('clear')"
    />
    <div v-else-if="error" class="mx-auto max-w-page px-4 py-12 md:px-6">
      <HomeSectionError :on-retry="() => $emit('refresh')" />
    </div>
    <template v-else>
      <NewsFeatured v-if="featured" :news="featured" />
      <div v-if="items.length || featured" id="news-list" class="scroll-mt-4">
        <NewsWeekList v-if="items.length" :items="items" />
      </div>
      <div v-if="!items.length && !featured" id="news-list" class="mx-auto max-w-page px-4 pt-12 pb-16 md:px-6">
        <UiEmptyState
          :title="scoped ? t('news.emptyScopeTitle') : isCategory ? t('news.emptyCategoryTitle') : t('news.emptyTitle')"
          :body="scoped ? t('news.emptyScopeBody') : isCategory ? t('news.emptyCategoryBody') : t('news.emptyBody')"
        >
          <template #action>
            <UiButton v-if="scoped" variant="ghost" @click="$emit('clear-scope')">{{ t('common.clearFilters') }}</UiButton>
            <UiButton v-else-if="isCategory" variant="ghost" :to="{ name: 'news' }">{{ t('news.allNews') }}</UiButton>
          </template>
        </UiEmptyState>
      </div>
      <NewsPager :page="page" :pages="pages" />
      <p v-if="locale === 'en'" class="mx-auto max-w-page px-4 pb-10 text-caption text-meta md:px-6" :class="pages > 1 ? '' : 'pt-10'">
        {{ t('news.newsletterSpanish') }}
      </p>
    </template>
  </div>
</template>
