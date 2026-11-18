<script setup lang="ts">
import type { ArticleSummary } from '~/types/domain'

/**
 * Article card. `feature`: cover + large title; `compact`: category + title (home, related);
 * `grid`: cover + date + title + excerpt (category page). `excerpt` adds the summary to `feature`.
 */
const props = withDefaults(
  defineProps<{
    article: ArticleSummary
    variant?: 'feature' | 'compact' | 'grid'
    excerpt?: boolean
    /** Secondary featured card: smaller title (20 px). */
    secondary?: boolean
    /** First image of the page (LCP): no lazy loading, high fetch priority. */
    priority?: boolean
  }>(),
  { variant: 'compact', excerpt: false, secondary: false, priority: false },
)
const { t, locale } = useI18n()
const to = computed(() => ({ name: 'blog-slug' as const, params: { slug: props.article.slug } }))
const hasCover = computed(() => props.variant !== 'compact')
</script>

<template>
  <article class="group/card flex flex-col overflow-hidden" :class="cardSurface">
    <div v-if="hasCover" class="aspect-video overflow-hidden">
      <UiPhoto
        :media="article.cover"
        :priority="priority"
        :sizes="variant === 'grid' ? '100vw md:50vw' : '100vw md:66vw'"
        class="size-full transition-transform duration-[600ms] ease-out group-hover/card:scale-[1.03]"
      />
    </div>
    <div class="p-6">
      <p v-if="variant === 'grid' && article.publishedAt" class="font-mono text-note text-meta">
        <time :datetime="article.publishedAt">
          {{ formatShortDate(article.publishedAt, locale) }}
        </time>
        <template v-if="article.readingMinutes">
          {{ ' · ' }}{{ t('blog.readingTime', { count: article.readingMinutes }) }}
        </template>
      </p>
      <p v-else-if="article.category" class="label-mini">{{ article.category.name }}</p>
      <h3
        class="font-medium"
        :class="[
          variant === 'feature' && !secondary ? 'text-title-3' : 'text-title-4 leading-snug',
          variant === 'grid' ? 'mt-2' : 'mt-3',
        ]"
      >
        <!-- Stretched link: the whole card is clickable, focus ring on the card. -->
        <NuxtLinkLocale
          :to="to"
          class="after:absolute after:inset-0 after:z-[1] focus-visible:shadow-none"
        >
          <span :class="cardTitleUnderline">{{ article.title }}</span>
        </NuxtLinkLocale>
      </h3>
      <p
        v-if="article.excerpt && (excerpt || variant === 'grid')"
        class="mt-2 text-body-sm text-meta"
      >
        {{ article.excerpt }}
      </p>
    </div>
  </article>
</template>
