<script setup lang="ts">
import { ArrowUpRight } from 'lucide-vue-next'
import type { NewsDetail } from '~/types/news'

/**
 * Last piece of the page (README §18.9.7): ink plaque with the outlet, the original headline (with its `lang`), the date and
 * language, the 56 px orange button «Leer en X ↗» and the transparency line. D79: opens outside (`noopener`) and carries
 * `nofollow` unless the source is trusted. Only `https:` URLs become links (F8.1). No UTM: the URL goes out as it came.
 */
const props = defineProps<{ news: NewsDetail }>()
const { t, locale } = useI18n()

const safeUrl = computed(() => (isHttpsUrl(props.news.sourceUrl) ? props.news.sourceUrl : null))
const rel = computed(() => newsSourceRel(props.news.sourceTrusted))
const language = computed(() => languageName(props.news.sourceLang, locale.value))
const published = computed(() =>
  props.news.sourcePublishedOn
    ? formatDate(`${props.news.sourcePublishedOn}T12:00:00Z`, locale.value, { day: 'numeric', month: 'short', year: 'numeric' })
    : null,
)
const meta = computed(() =>
  [
    published.value ? t('news.detail.publishedOn', { date: published.value }) : null,
    language.value ? t('news.detail.inLanguage', { language: language.value }) : null,
  ]
    .filter((part): part is string => !!part)
    .join(' · '),
)
</script>

<template>
  <section
    id="source"
    class="scroll-mt-24 rounded-lg bg-news-source px-5 py-6 text-news-source-text md:px-10 md:py-9"
    aria-labelledby="news-source-title"
  >
    <h2 id="news-source-title" class="font-mono text-micro tracking-[.14em] text-news-source-meta uppercase">{{ t('news.source.kicker') }}</h2>
    <p class="mt-2 text-[26px] leading-[1.15] font-medium tracking-[-.02em]">{{ news.sourceName }}</p>
    <p v-if="news.sourceTitle" class="mt-2.5 text-[17px] leading-[1.45] text-news-source-soft [text-wrap:pretty]" :lang="news.sourceLang || undefined">
      «{{ news.sourceTitle }}»
    </p>
    <p v-if="meta" class="mt-1.5 text-caption text-news-source-meta">{{ meta }}</p>
    <a
      v-if="safeUrl"
      :href="safeUrl"
      target="_blank"
      :rel="rel"
      class="mt-6 flex min-h-14 w-full items-center justify-center gap-2.5 rounded-md bg-accent-fill px-6 text-[17px] font-medium text-on-accent transition-[background-color,transform] duration-150 hover:bg-news-source-btn-hover active:scale-[.99] focus-visible:shadow-[0_0_0_2px_var(--color-news-source),0_0_0_4px_var(--color-accent-fill)] md:inline-flex md:w-auto motion-reduce:transition-none"
    >
      {{ t('news.source.cta', { source: news.sourceName }) }}
      <ArrowUpRight :size="18" aria-hidden="true" class="shrink-0" />
      <span class="sr-only">{{ t('news.detail.external') }}</span>
    </a>
    <p class="mt-5 border-t border-news-source-line pt-4 text-caption leading-[1.5] text-news-source-meta">
      {{ t('news.source.transparency') }}
      <NuxtLinkLocale :to="{ name: 'transparency' }" class="text-news-source-text underline underline-offset-[3px]">{{ t('news.detail.howWeDoIt') }}</NuxtLinkLocale>
    </p>
  </section>
</template>
