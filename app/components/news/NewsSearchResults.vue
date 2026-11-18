<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import type { NewsSearchStatus } from '~/composables/useNewsSearch'
import type { NewsSearchHit } from '~/types/news'

/**
 * Search results (FTS, §15.2): replace the featured and the weeks with "N resultados para «x»" and
 * the same row. Loading skeleton, empty and error states, "load more" past the first page. Titles
 * and summaries are interpolated; the match marks are drawn by <UiHighlight> over plain text.
 */
const props = defineProps<{
  term: string
  status: NewsSearchStatus
  hits: NewsSearchHit[]
  total: number
  loadingMore: boolean
  hasMore: boolean
}>()
defineEmits<{ retry: []; more: []; clear: [] }>()
const { t } = useI18n()
const tokens = computed(() => searchTokens(props.term))
const heading = computed(() => {
  if (props.status === 'loading') return t('news.search.searching', { term: props.term })
  if (props.status === 'error') return `«${props.term}»`
  return props.total
    ? t('news.search.results', { count: props.total, term: props.term })
    : t('news.search.emptyTitle', { term: props.term })
})
</script>

<template>
  <section aria-labelledby="news-search-title" class="mx-auto max-w-page px-4 py-10 md:px-6 md:py-12">
    <h2 id="news-search-title" tabindex="-1" class="text-[22px] font-medium tracking-[-.015em] md:text-[26px]">{{ heading }}</h2>
    <p class="sr-only" role="status" aria-atomic="true">{{ status === 'ready' ? heading : '' }}</p>

    <ul v-if="status === 'loading'" class="mt-4 border-t border-foreground" aria-busy="true" :aria-label="t('common.loading')">
      <li v-for="n in 3" :key="n" class="grid gap-x-8 gap-y-3 border-b border-line-strong py-6 md:grid-cols-[132px_minmax(0,1fr)]">
        <UiSkeleton class="h-3 w-20" />
        <div class="space-y-3">
          <UiSkeleton class="h-5 w-3/4" />
          <UiSkeleton class="h-3 w-full" />
        </div>
      </li>
    </ul>

    <div v-else-if="status === 'error'" role="alert" class="mt-4 flex items-start gap-3 rounded-lg border-[0.5px] border-line-strong bg-board p-6 md:p-8">
      <TriangleAlert :size="20" class="mt-0.5 text-danger-text" aria-hidden="true" />
      <div>
        <p class="font-medium">{{ t('news.search.errorTitle') }}</p>
        <p class="mt-1 text-body-sm text-meta">{{ t('news.search.errorBody') }}</p>
        <UiButton variant="ghost" class="mt-4" @click="$emit('retry')">{{ t('common.retry') }}</UiButton>
      </div>
    </div>

    <div v-else-if="!hits.length" class="mt-6 max-w-[760px] rounded-slab bg-board p-6">
      <p class="text-body-sm text-meta">{{ t('news.search.emptyBody') }}</p>
      <div class="mt-5 flex flex-wrap gap-3">
        <UiButton variant="ghost" @click="$emit('clear')">{{ t('common.clearFilters') }}</UiButton>
        <UiButton variant="ghost" :to="{ name: 'blog' }">{{ t('news.goBlog') }}</UiButton>
      </div>
    </div>

    <template v-else>
      <ul class="mt-4 border-t border-foreground">
        <li v-for="hit in hits" :key="hit.id" class="border-b border-line-strong">
          <NewsRow :news="hit" :tokens="tokens" />
        </li>
      </ul>
      <div v-if="hasMore" class="mt-6 flex flex-wrap items-center gap-4">
        <UiButton variant="ghost" :loading="loadingMore" @click="$emit('more')">{{ t('news.search.loadMore') }}</UiButton>
        <span class="font-mono text-note text-meta">{{ t('news.search.showing', { shown: hits.length, total }) }}</span>
      </div>
    </template>
  </section>
</template>
