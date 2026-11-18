<script setup lang="ts">
import type { NewsSummary } from '~/types/news'

/**
 * Text row of a news item (§15.2 and §15.4, no thumbnails). One link per row: the title carries an
 * `::after` overlay, so there is a single tab stop (the link to the source lives on the page).
 * `list` = index and search; `compact` = "Más noticias" on the page; `home` = block of the home.
 * Everything is plain text and interpolated (F8.1 F1): never v-html, markdown or linkify.
 */
type Row = Pick<NewsSummary, 'slug' | 'title' | 'sourceName' | 'publishedAt'> &
  Partial<Pick<NewsSummary, 'summary' | 'note' | 'categoryName' | 'scope'>> & { hasNote?: boolean }

const props = withDefaults(
  defineProps<{ news: Row; variant?: 'list' | 'compact' | 'home'; tokens?: string[] }>(),
  { variant: 'list', tokens: () => [] },
)
const { t, locale } = useI18n()
const day = computed(() => formatNewsDay(props.news.publishedAt, locale.value))
const meta = computed(() =>
  [props.news.categoryName, props.news.scope ? t(`news.scope.${props.news.scope}`) : null]
    .filter(Boolean)
    .join(' · '),
)
const withNote = computed(() => !!props.news.note || props.news.hasNote === true)
const home = computed(() => props.variant === 'home')
const to = computed(() => ({ name: 'news-slug' as const, params: { slug: props.news.slug } }))
</script>

<template>
  <article
    class="group/card relative grid gap-1.5 has-[a:focus-visible]:ring-focus"
    :class="
      home
        ? 'py-[18px] md:grid-cols-[88px_minmax(0,1fr)] md:gap-6 md:py-5'
        : 'py-5 md:grid-cols-[132px_minmax(0,1fr)] md:gap-8 md:py-6'
    "
  >
    <time
      :datetime="news.publishedAt"
      class="hidden font-mono text-data tabular-nums text-meta md:block"
      :class="home ? 'md:pt-0.5' : 'md:pt-1'"
    >{{ day }}</time>
    <div class="min-w-0">
      <p v-if="!home" class="text-caption font-medium text-meta">
        <time :datetime="news.publishedAt" class="font-mono tabular-nums md:hidden">{{ day }} · </time>{{ meta }}
      </p>
      <h3
        class="font-medium text-balance"
        :class="[
          home ? 'text-[19px] leading-[1.3] tracking-[-.01em] md:text-[21px]' : 'mt-1 text-[19px] leading-[1.3] tracking-[-.012em] md:text-[23px]',
          variant === 'compact' ? 'md:text-[22px]' : '',
        ]"
      >
        <NuxtLinkLocale :to="to" class="after:absolute after:inset-0 focus-visible:shadow-none">
          <span :class="cardTitleUnderline"><UiHighlight v-if="tokens.length" :text="news.title" :tokens="tokens" /><template v-else>{{ news.title }}</template></span>
        </NuxtLinkLocale>
      </h3>
      <p v-if="variant === 'list' && news.summary" class="mt-2 line-clamp-2 max-w-[62ch] text-body text-meta max-md:hidden">
        {{ news.summary }}
      </p>
      <p v-if="home" class="mt-1.5 text-caption text-meta">
        <time :datetime="news.publishedAt" class="font-mono tabular-nums md:hidden">{{ day }} · </time>{{ t('news.markSource') }}
        <b class="font-medium text-foreground">{{ news.sourceName }}</b>
        <template v-if="withNote"> · <span class="font-medium text-accent">{{ t('news.withNote') }}</span></template>
      </p>
      <p v-else class="mt-2.5 flex flex-wrap items-center gap-x-3 gap-y-1.5 text-caption text-meta">
        <span>
          <template v-if="variant === 'list'">{{ t('news.markSummary') }} · </template>{{ t('news.markSource') }}
          <b class="font-medium text-foreground">{{ news.sourceName }}</b>
        </span>
        <UiBadge v-if="withNote" kind="author">{{ t('news.withNote') }}</UiBadge>
      </p>
    </div>
  </article>
</template>
