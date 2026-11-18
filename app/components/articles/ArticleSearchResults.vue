<script setup lang="ts">
import { SearchX, TriangleAlert } from 'lucide-vue-next'
import type { ArticleSearchStatus } from '~/composables/useArticleSearch'
import type { ArticleSearchHit } from '~/services/article-search'

/**
 * Blog search results (mockup buscador-blog): loading skeleton, results with the snippet,
 * empty and error states, and "load more" past the first page. Titles and excerpts are always
 * interpolated; only the snippet carries marks, through <ArticlesArticleSearchHeadline>.
 */
const props = defineProps<{
  term: string
  status: ArticleSearchStatus
  hits: ArticleSearchHit[]
  total: number
  loadingMore: boolean
  hasMore: boolean
  /** Name of the category the search is limited to (category page, narrow scope). */
  scopeName?: string
  /** Category of the page (category page only), even when the scope is the whole blog. */
  categoryName?: string
}>()
defineEmits<{ retry: []; more: []; widen: []; narrow: []; clear: [] }>()

const { t, locale } = useI18n()
const { data: settings } = useSiteSettings()
const email = computed(() => settings.value?.contactEmail)
const tokens = computed(() => searchTokens(props.term))
const heading = computed(() => {
  if (props.status === 'loading') return t('blog.search.searching', { term: props.term })
  if (props.status === 'error') return `«${props.term}»`
  return props.total
    ? t('blog.search.results', { count: props.total, term: props.term })
    : t('blog.search.noResults', { term: props.term })
})
</script>

<template>
  <section aria-labelledby="blog-search-title" class="mx-auto max-w-page px-4 py-10 md:px-6 md:py-12">
    <h2 id="blog-search-title" tabindex="-1" class="text-title-3 font-medium">
      {{ heading }}
    </h2>
    <p
      v-if="categoryName && hits.length && status === 'ready'"
      class="mt-2 text-body-sm text-meta"
    >
      <template v-if="scopeName">
        {{ t('blog.search.scopeCategory', { name: categoryName }) }} ·
        <button
          type="button"
          class="link-underline relative after:absolute after:inset-x-0 after:-inset-y-3.5"
          @click="$emit('widen')"
        >
          {{ t('blog.search.searchAll') }}
        </button>
      </template>
      <template v-else>
        {{ t('blog.search.scopeAll') }} ·
        <button
          type="button"
          class="link-underline relative after:absolute after:inset-x-0 after:-inset-y-3.5"
          @click="$emit('narrow')"
        >
          {{ t('blog.search.narrow', { name: categoryName }) }}
        </button>
      </template>
    </p>
    <p class="sr-only" role="status" aria-atomic="true">
      {{ status === 'ready' ? heading : '' }}
    </p>

    <ul
      v-if="status === 'loading'"
      class="mt-4 border-t-[0.5px] border-line"
      aria-busy="true"
      :aria-label="t('common.loading')"
    >
      <li
        v-for="n in 3"
        :key="n"
        class="grid gap-x-6 gap-y-3 border-b-[0.5px] border-line py-6 md:grid-cols-[140px_minmax(0,1fr)_120px]"
      >
        <UiSkeleton class="h-3 w-24" />
        <div class="space-y-3">
          <UiSkeleton class="h-5 w-3/4" />
          <UiSkeleton class="h-3 w-full" />
          <UiSkeleton class="h-3 w-2/3" />
        </div>
        <UiSkeleton class="h-3 w-12 md:ml-auto" />
      </li>
    </ul>

    <div
      v-else-if="status === 'error'"
      role="alert"
      class="mt-4 flex items-start gap-3 rounded-lg border-[0.5px] border-line-strong bg-board p-6 md:p-8"
    >
      <TriangleAlert :size="20" class="mt-0.5 text-danger-text" aria-hidden="true" />
      <div>
        <p class="font-medium">{{ t('blog.search.errorTitle') }}</p>
        <p class="mt-1 text-body-sm text-meta">{{ t('blog.search.errorBody') }}</p>
        <UiButton variant="ghost" class="mt-4" @click="$emit('retry')">
          {{ t('common.retry') }}
        </UiButton>
      </div>
    </div>

    <UiEmptyState
      v-else-if="!hits.length"
      class="mt-4"
      variant="board"
      :hand-title="scopeName ? undefined : t('blog.search.emptyHand')"
      :icon="scopeName ? SearchX : undefined"
      :title="
        scopeName
          ? t('blog.search.emptyInScope', { name: scopeName, term })
          : t('blog.search.emptyTitle', { term })
      "
      :body="t('blog.search.emptyBody')"
    >
      <template #action>
        <UiButton v-if="scopeName" variant="ghost" @click="$emit('widen')">
          {{ t('blog.search.searchAll') }}
        </UiButton>
        <UiButton v-else variant="ghost" @click="$emit('clear')">
          {{ t('blog.allArticles') }}
        </UiButton>
        <p v-if="!scopeName && email" class="mt-3 text-caption text-meta">
          {{ t('blog.search.wantTopic') }}
          <UiTextLink :href="`mailto:${email}`">{{ t('blog.search.tellMeTopic') }}</UiTextLink>
        </p>
      </template>
    </UiEmptyState>

    <template v-else>
      <ul class="mt-4 border-t-[0.5px] border-line">
        <li v-for="hit in hits" :key="hit.id" class="border-b-[0.5px] border-line">
          <article
            class="group/card relative grid gap-x-6 gap-y-1 py-6 has-[a:focus-visible]:ring-focus md:grid-cols-[140px_minmax(0,1fr)_120px]"
          >
            <p class="label-mini md:pt-1.5">
              {{ hit.category?.name }}
              <span v-if="hit.publishedAt" class="font-mono tracking-normal normal-case md:hidden">
                · {{ formatShortDate(hit.publishedAt, locale) }}
              </span>
            </p>
            <div>
              <h3 class="text-lg leading-snug font-medium md:text-xl">
                <NuxtLinkLocale
                  :to="{ name: 'blog-slug', params: { slug: hit.slug } }"
                  class="after:absolute after:inset-0 focus-visible:shadow-none"
                >
                  <span :class="cardTitleUnderline"><UiHighlight :text="hit.title" :tokens="tokens" /></span>
                </NuxtLinkLocale>
              </h3>
              <p v-if="hit.headline" class="mt-1 text-body-sm text-meta">
                <ArticlesArticleSearchHeadline :headline="hit.headline" />
              </p>
              <p v-else-if="hit.excerpt" class="mt-1 text-body-sm text-meta">{{ hit.excerpt }}</p>
            </div>
            <p
              v-if="hit.publishedAt"
              class="hidden font-mono text-note text-meta md:block md:pt-1.5 md:text-right"
            >
              <time :datetime="hit.publishedAt">{{ formatShortDate(hit.publishedAt, locale) }}</time>
            </p>
          </article>
        </li>
      </ul>
      <div v-if="hasMore" class="mt-6 flex flex-wrap items-center gap-4">
        <UiButton variant="ghost" :loading="loadingMore" @click="$emit('more')">
          {{ t('blog.search.loadMore') }}
        </UiButton>
        <span class="font-mono text-note text-meta">
          {{ t('blog.search.showing', { shown: hits.length, total }) }}
        </span>
      </div>
    </template>
  </section>
</template>
