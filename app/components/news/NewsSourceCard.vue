<script setup lang="ts">
import { ArrowUpRight } from 'lucide-vue-next'
import type { NewsDetail } from '~/types/news'

/**
 * Original source (§15.3), always present: `board` + `slab` plaque with the outlet, the original
 * headline (with its `lang`), the date and language, and the ink button to the source. D79: the
 * link opens outside (`noopener`) and carries `nofollow` unless the source is trusted. Only `https:`
 * URLs become links (F8.1). No UTM: the URL goes out as it came.
 */
const props = defineProps<{ news: NewsDetail }>()
const { t, locale } = useI18n()

const safeUrl = computed(() => (isHttpsUrl(props.news.sourceUrl) ? props.news.sourceUrl : null))
const rel = computed(() => newsSourceRel(props.news.sourceTrusted))
const language = computed(() => {
  const code = props.news.sourceLang
  if (!code) return null
  try {
    return new Intl.DisplayNames([locale.value], { type: 'language' }).of(code) ?? null
  } catch {
    return null
  }
})
const published = computed(() =>
  props.news.sourcePublishedOn
    ? formatDate(`${props.news.sourcePublishedOn}T12:00:00Z`, locale.value, { day: 'numeric', month: 'short', year: 'numeric' })
    : null,
)
const showMeta = computed(() => published.value || language.value)
</script>

<template>
  <section
    id="source"
    class="scroll-mt-24 slab bg-board p-5 md:grid md:grid-cols-[minmax(0,1fr)_auto] md:items-end md:gap-6 md:px-7 md:py-6"
    aria-labelledby="news-source-title"
  >
    <div class="min-w-0">
      <h2 id="news-source-title" class="text-caption font-medium text-meta">{{ t('news.detail.sourceTitle') }}</h2>
      <p class="mt-2 text-[20px] leading-[1.25] font-medium tracking-[-.012em] md:text-[22px]">{{ news.sourceName }}</p>
      <p v-if="news.sourceTitle" class="mt-2 text-[16px] leading-[1.45] text-prose" :lang="news.sourceLang || undefined">
        «{{ news.sourceTitle }}»
      </p>
      <p v-if="showMeta" class="mt-2 text-caption text-meta">
        <template v-if="published">
          {{ t('news.detail.publishedOn', { date: published }) }}
        </template>
        <template v-if="published && language"> · </template>
        <template v-if="language">{{ t('news.detail.inLanguage', { language }) }}</template>
      </p>
    </div>
    <UiButton
      v-if="safeUrl"
      variant="ink"
      :href="safeUrl"
      target="_blank"
      :rel="rel"
      class="mt-5 w-full md:mt-0 md:w-auto"
    >
      <span class="inline-flex items-center gap-2">
        {{ t('news.detail.readAt', { source: news.sourceName }) }}
        <ArrowUpRight :size="16" aria-hidden="true" class="shrink-0" />
      </span>
      <span class="sr-only">{{ t('news.detail.external') }}</span>
    </UiButton>
  </section>
</template>
