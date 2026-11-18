<script setup lang="ts">
import { ArrowLeft } from 'lucide-vue-next'
import type { Article } from '~/types/domain'

/**
 * Article head (editorial v2, §13.5, D49): ink field continuing the site header, crumbs (mobile:
 * only the parent), H1 in Inter 500, excerpt, transparency badges and signature. The cover crosses
 * the seam between ink and paper (wide: page width; tall: split header, text 7 + photo 5).
 */
const props = defineProps<{ article: Article; guestVisit?: boolean; affiliate?: boolean }>()
const { t } = useI18n()
const { linkFor } = usePageLinks()

const parent = computed(() =>
  props.article.category
    ? { label: props.article.category.name, to: { name: 'blog-category-slug' as const, params: { slug: props.article.category.slug } } }
    : { label: t('nav.blog'), to: { name: 'blog' as const } },
)

const ratio = computed(() => {
  const { width, height } = props.article.cover ?? {}
  return width && height ? width / height : null
})
// No dimensions: treat as wide (the common case); tall covers split the header.
const split = computed(() => !!props.article.cover && ratio.value !== null && ratio.value < WIDE_COVER_RATIO)
const wide = computed(() => !!props.article.cover && !split.value)
const hasBadges = computed(() => props.guestVisit || props.affiliate)
</script>

<template>
  <div>
    <header class="chrome-dark" :class="wide ? 'pb-10 md:pb-14' : split ? 'pb-0' : 'pb-12 md:pb-16'">
      <div :class="articleShell" class="pt-6 md:pt-8">
        <!-- Crumbs: the title never goes in (it stays in the JSON-LD). Mobile: parent with an arrow. -->
        <nav :aria-label="t('nav.breadcrumbs')">
          <NuxtLinkLocale
            :to="parent.to"
            class="inline-flex min-h-11 items-center gap-2 font-mono text-micro tracking-[.06em] text-meta uppercase md:hidden"
          >
            <ArrowLeft :size="16" aria-hidden="true" />
            {{ parent.label }}
          </NuxtLinkLocale>
          <ol class="hidden flex-wrap items-center gap-x-2 font-mono text-micro tracking-[.06em] text-meta uppercase md:flex">
            <li class="flex items-center gap-2">
              <NuxtLinkLocale to="/" class="inline-flex min-h-11 items-center hover:text-foreground">{{ t('nav.home') }}</NuxtLinkLocale>
              <span class="text-hint" aria-hidden="true">/</span>
            </li>
            <li v-if="article.category" class="flex items-center gap-2">
              <NuxtLinkLocale :to="{ name: 'blog' }" class="inline-flex min-h-11 items-center hover:text-foreground">{{ t('nav.blog') }}</NuxtLinkLocale>
              <span class="text-hint" aria-hidden="true">/</span>
            </li>
            <li>
              <NuxtLinkLocale :to="parent.to" class="inline-flex min-h-11 items-center hover:text-foreground">{{ parent.label }}</NuxtLinkLocale>
            </li>
          </ol>
        </nav>
      </div>

      <div :class="split ? 'mx-auto w-full max-w-page px-4 md:px-6 lg:grid lg:grid-cols-12 lg:items-end lg:gap-x-12' : ''">
        <div :class="split ? 'pb-10 lg:col-span-7 lg:pb-14' : articleShell">
          <h1 id="article-title" class="mt-4 max-w-[20ch] text-balance text-article-title font-medium text-foreground">
            {{ article.title }}
          </h1>
          <div :class="split ? '' : [articleGrid, 'mt-8 gap-y-6']" class="mt-8">
            <div v-if="!split" class="max-[1099px]:order-last min-[1100px]:col-start-1 min-[1100px]:row-start-1">
              <AuthorSignature :author="article.author" :published-at="article.publishedAt" :minutes="article.readingMinutes" />
            </div>
            <div class="min-w-0 min-[1100px]:col-start-2">
              <p v-if="article.excerpt" class="text-[19px] leading-[1.5] text-prose md:text-[24px]">{{ article.excerpt }}</p>
              <div v-if="hasBadges" class="flex flex-wrap items-center gap-2" :class="article.excerpt ? 'mt-6' : ''">
                <UiBadge v-if="guestVisit" kind="guest-visit">{{ t('transparency.guestVisit') }}</UiBadge>
                <UiBadge v-if="affiliate" kind="affiliate">{{ t('transparency.affiliate') }}</UiBadge>
                <UiTextLink
                  :to="{ name: 'transparency' }"
                  v-bind="linkFor('transparency')"
                  variant="accent"
                  class="inline-flex min-h-11 items-center text-caption"
                >
                  {{ t('transparency.learnMore') }}
                </UiTextLink>
              </div>
              <div v-if="split" class="mt-6">
                <AuthorSignature :author="article.author" :published-at="article.publishedAt" :minutes="article.readingMinutes" />
              </div>
            </div>
          </div>
        </div>
        <figure v-if="split && article.cover" class="relative z-10 mt-10 lg:col-span-5 lg:mt-0 lg:translate-y-14">
          <UiPhoto
            :media="article.cover"
            sizes="xs:100vw sm:100vw md:640px"
            priority
            class="mx-auto w-full max-w-[640px] max-md:-mx-4 max-md:w-auto md:rounded-slab lg:max-h-[640px]"
            :style="{ aspectRatio: ratio ?? undefined }"
          />
        </figure>
      </div>
    </header>

    <!-- Tall cover crosses the seam by 56 px (translate): paper under it. -->
    <div v-if="split" class="hidden h-14 lg:block" aria-hidden="true" />

    <!-- Wide cover: crosses the seam; the ink covers the upper half behind it. -->
    <div v-if="wide && article.cover" class="relative">
      <div class="chrome-dark absolute inset-x-0 top-0 h-1/2" aria-hidden="true" />
      <figure class="relative mx-auto w-full max-w-page md:px-6">
        <UiPhoto
          :media="article.cover"
          sizes="xs:100vw sm:100vw md:100vw xl:1200px"
          priority
          class="w-full max-h-[72svh] md:max-h-[min(720px,82svh)] md:rounded-slab"
          :style="{ aspectRatio: ratio ?? '16 / 9' }"
        />
        <figcaption
          v-if="article.cover.credit"
          class="mx-auto mt-3 max-w-[calc(var(--container-prose)+2rem)] px-4 text-note text-meta min-[704px]:px-0 min-[1100px]:mx-0 min-[1100px]:ml-[288px]"
        >{{ article.cover.credit }}</figcaption>
      </figure>
    </div>
  </div>
</template>
