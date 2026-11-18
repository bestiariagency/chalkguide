<script setup lang="ts">
import type { NewsSummary } from '~/types/news'

/**
 * Featured (§15.2): the latest item with a note from the last 7 days. `board` + `slab` plaque: meta,
 * title, summary and source mark on the left (7 columns), the note on the right (5; below on mobile).
 * The only place of the index where the author's voice leads.
 */
const props = defineProps<{ news: NewsSummary }>()
const { t, locale } = useI18n()
const meta = computed(() =>
  [props.news.categoryName, props.news.scope ? t(`news.scope.${props.news.scope}`) : null].filter(Boolean).join(' · '),
)
</script>

<template>
  <section class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10" aria-labelledby="news-featured">
    <h2 id="news-featured" class="sr-only">{{ t('news.featured') }}</h2>
    <article class="group/card relative grid gap-x-8 gap-y-6 slab bg-board p-5 has-[a:focus-visible]:ring-focus md:p-8 lg:grid-cols-12 lg:p-10">
      <div class="lg:col-span-7">
        <p class="text-caption font-medium text-meta">
          {{ meta }}<template v-if="meta"> · </template><time class="font-mono tabular-nums" :datetime="news.publishedAt">{{ formatDate(news.publishedAt, locale, { day: 'numeric', month: 'short', year: 'numeric' }) }}</time>
        </p>
        <h3 class="mt-2 max-w-[22ch] text-[26px] leading-[1.12] font-medium tracking-[-.025em] text-balance md:text-[36px]">
          <NuxtLinkLocale :to="{ name: 'news-slug', params: { slug: news.slug } }" class="after:absolute after:inset-0 focus-visible:shadow-none">
            <span :class="cardTitleUnderline">{{ news.title }}</span>
          </NuxtLinkLocale>
        </h3>
        <p class="mt-4 max-w-[56ch] text-[17px] leading-[1.55] text-meta">{{ news.summary }}</p>
        <p class="mt-4 text-caption text-meta">
          {{ t('news.markSummary') }} · {{ t('news.markSource') }}
          <b class="font-medium text-foreground">{{ news.sourceName }}</b>
        </p>
      </div>
      <NewsNote v-if="news.note" :note="news.note" class="self-start lg:col-span-5" />
    </article>
  </section>
</template>
