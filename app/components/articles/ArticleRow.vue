<script setup lang="ts">
import type { ArticleSummary } from '~/types/domain'

/**
 * Row of the "Últimos" list (editorial v2, §13.6): thumbnail (104 px, 200 × 134 from md; empty alt,
 * the link already has the title), category, title, excerpt from md, date and minutes in mono.
 */
const props = defineProps<{ article: ArticleSummary }>()
const { t, locale } = useI18n()
const to = computed(() => ({ name: 'blog-slug' as const, params: { slug: props.article.slug } }))
</script>

<template>
  <article
    class="group/card relative grid grid-cols-[104px_minmax(0,1fr)] gap-x-4 gap-y-2 py-5 has-[a:focus-visible]:ring-focus md:grid-cols-[200px_minmax(0,1fr)_140px] md:gap-x-6 md:py-6"
  >
    <div class="relative row-span-2 md:row-span-1">
      <UiPhoto
        :media="article.cover ? { ...article.cover, alt: '' } : null"
        sizes="xs:104px md:200px"
        class="aspect-[3/2] w-full overflow-hidden rounded-slab"
      />
      <p v-if="!article.cover" class="chrome-dark absolute inset-0 grid place-items-center bg-transparent text-center font-mono text-micro">
        {{ t('blog.noCover') }}
      </p>
    </div>
    <div class="min-w-0">
      <p v-if="article.category" class="label-mini">{{ article.category.name }}</p>
      <h3 class="mt-1.5 text-[19px] leading-snug font-medium md:text-2xl">
        <NuxtLinkLocale :to="to" class="after:absolute after:inset-0 focus-visible:shadow-none">
          <span :class="cardTitleUnderline">{{ article.title }}</span>
        </NuxtLinkLocale>
      </h3>
      <p v-if="article.excerpt" class="mt-1.5 line-clamp-2 text-body-sm text-meta max-md:hidden">{{ article.excerpt }}</p>
    </div>
    <p class="col-start-2 flex flex-wrap items-baseline gap-x-3 font-mono text-note text-meta md:col-start-3 md:row-start-1 md:flex-col md:gap-x-0 md:gap-y-1 md:text-right">
      <time v-if="article.publishedAt" :datetime="article.publishedAt">{{ formatShortDate(article.publishedAt, locale) }}</time>
      <span v-if="article.readingMinutes">{{ t('blog.readingTime', { count: article.readingMinutes }) }}</span>
    </p>
  </article>
</template>
