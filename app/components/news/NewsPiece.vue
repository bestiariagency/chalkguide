<script setup lang="ts">
import type { NewsSummary } from '~/types/news'
import type { NewsPos } from '~/utils/news'

/**
 * One piece of the /noticias front page (README §18.1): the same markup draws the grid (photo or category tile with the title
 * inside) and, under `html[data-news-view=list]`, the row of §15.2 (`news-list:` variant, §18.6). The size comes from the
 * position, never from the content. One link, the title, with an `::after` over the whole piece: a single tab stop.
 * The photo is decorative (the title is on top of it). Everything is plain text, interpolated (F8.1 F1).
 *
 * `view` is only set on the two copies of an opener that is not the first by date (focus order, WCAG 2.4.3): the `grid` copy
 * sits first in the DOM and is hidden in the list; the `list` copy sits at its date and is hidden in the grid.
 */
const props = defineProps<{ news: NewsSummary; pos: NewsPos; age: number; view?: 'grid' | 'list' }>()
const { t, locale } = useI18n()
const day = computed(() => formatNewsDay(props.news.publishedAt, locale.value))
const image = computed(() => (props.news.image ? { ...props.news.image, alt: '' } : null))
const dek = computed(() => newsDek(props.news))
const to = computed(() => ({ name: 'news-slug' as const, params: { slug: props.news.slug } }))
const lead = computed(() => props.pos === 'lead')
const visibility = computed(() =>
  props.view === 'list' ? 'hidden news-list:block' : props.view === 'grid' ? 'flex news-list:hidden' : 'flex news-list:block',
)

const sizes = computed(() => (lead.value ? 'xs:100vw md:100vw lg:776px' : 'xs:100vw md:50vw lg:368px'))
const scrim = computed(() =>
  lead.value
    ? 'bg-[linear-gradient(180deg,rgb(12_11_10/0)_0,rgb(12_11_10/.74)_64px,rgb(12_11_10/.88)_100%)] md:bg-[linear-gradient(180deg,rgb(12_11_10/0)_0,rgb(12_11_10/.74)_96px,rgb(12_11_10/.88)_100%)]'
    : 'bg-[linear-gradient(180deg,rgb(12_11_10/0)_0,rgb(12_11_10/.74)_64px,rgb(12_11_10/.88)_100%)]',
)
const pad = computed(() =>
  lead.value
    ? 'px-5 pt-[88px] pb-[18px] md:px-7 md:pt-[120px] md:pb-6'
    : props.pos === 'side'
      ? 'px-[18px] pt-[76px] pb-4'
      : 'px-4 pt-[72px] pb-3.5 md:px-[18px] md:pt-[76px] md:pb-4',
)
const figShape = computed(() =>
  lead.value
    ? 'aspect-[4/3] md:aspect-video lg:aspect-auto lg:min-h-[380px] lg:flex-1'
    : 'aspect-video md:aspect-[3/2]',
)
const titleSize = computed(() =>
  lead.value
    ? 'mt-2.5 line-clamp-3 max-w-[24ch] text-[28px] leading-[1.1] tracking-[-.022em] md:text-[36px] lg:text-[40px] xl:text-[44px]'
    : props.pos === 'side'
      ? 'mt-1.5 line-clamp-4 text-[21px] leading-[1.2] tracking-[-.015em]'
      : 'mt-1.5 line-clamp-4 text-[19px] leading-[1.24] tracking-[-.012em]',
)
// The glyph of the tile peeks out at the top right, away from the text (§18.14).
const glyphPlace = computed(() => (lead.value ? 'right-[4%] -top-[6%] w-[34%]' : '-right-[6%] -top-[14%] w-[46%]'))
const text = {
  kicker:
    'font-mono text-micro leading-[1.3] tracking-[.1em] uppercase ' +
    'news-list:col-start-1 news-list:row-start-1 md:news-list:col-start-2 news-list:font-sans news-list:text-[14px] ' +
    'news-list:font-medium news-list:tracking-normal news-list:text-meta news-list:normal-case news-list:[text-shadow:none]',
  title:
    'font-medium text-balance ' +
    'news-list:col-start-1 news-list:row-start-2 md:news-list:col-start-2 news-list:mt-1 news-list:line-clamp-none news-list:max-w-none ' +
    'news-list:text-[19px] news-list:leading-[1.3] news-list:tracking-[-.012em] md:news-list:text-[23px] ' +
    'news-list:text-foreground news-list:[text-shadow:none]',
}
</script>

<template>
  <li
    :data-pos="pos"
    :data-photo="image ? '' : undefined"
    class="min-w-0 news-list:border-b news-list:border-line-strong"
    :class="[
      visibility,
      newsToneClass(news.categoryKey),
      lead ? 'md:col-span-full lg:col-span-2 lg:row-span-2' : '',
      pos === 'grid'
        ? 'md:max-lg:[&:last-child:nth-child(odd_of_[data-pos=grid])]:col-span-2'
        : '',
    ]"
  >
    <article
      class="group/card relative flex w-full flex-col news-list:grid news-list:grid-cols-[minmax(0,1fr)_auto] news-list:gap-x-4 news-list:py-5 md:news-list:grid-cols-[132px_minmax(0,1fr)_auto] md:news-list:gap-x-8 md:news-list:py-6 news-list:has-[a:focus-visible]:ring-focus"
    >
      <time
        :datetime="news.publishedAt"
        class="hidden font-mono text-data leading-[1.6] text-meta md:news-list:col-start-1 md:news-list:row-span-4 md:news-list:row-start-1 md:news-list:block md:news-list:pt-0.5"
      >{{ day }}</time>

      <div
        class="relative isolate overflow-hidden rounded-slab news-list:contents group-has-[a:focus-visible]/card:ring-focus"
        :class="[figShape, image ? 'bg-news-photo-bg' : 'bg-(--tone) before:absolute before:inset-x-0 before:top-0 before:z-10 before:h-[3px] before:bg-(--tink) news-list:before:hidden']"
      >
        <div
          v-if="image"
          class="absolute inset-0 -z-10 transition-transform duration-200 ease-out motion-safe:group-hover/card:scale-[1.03] news-list:hidden"
        >
          <UiPhoto :media="image" :sizes="sizes" :priority="lead && view !== 'list'" class="size-full" />
        </div>
        <NewsCategoryIcon
          v-else
          :slug="news.categoryKey"
          :size="24"
          :stroke-width="1"
          class="pointer-events-none absolute -z-10 aspect-square h-auto stroke-1 text-(--tink) opacity-[.13] news-list:hidden"
          :class="glyphPlace"
        />
        <div
          class="absolute inset-x-0 bottom-0 news-list:contents"
          :class="[pad, image ? ['text-news-on-photo', scrim] : 'text-foreground']"
        >
          <p
            :class="[text.kicker, image ? 'text-news-on-photo-meta [text-shadow:0_1px_2px_rgb(0_0_0/.35)]' : 'text-(--tink)']"
          >
            <time :datetime="news.publishedAt" class="md:news-list:hidden">{{ day }}</time>
            <span aria-hidden="true" class="mx-[.35em] md:news-list:hidden">·</span>
            <span class="inline-flex items-center gap-1.5 align-bottom">
              <NewsCategoryIcon :slug="news.categoryKey" :size="14" class="news-list:size-4" />{{ news.categoryName }}
            </span>
          </p>
          <h3
            :class="[text.title, titleSize, image ? '[text-shadow:0_1px_2px_rgb(0_0_0/.35)]' : '']"
          >
            <NuxtLinkLocale :to="to" class="after:absolute after:inset-0 after:z-[3] focus-visible:shadow-none">
              <span :class="[cardTitleUnderline, 'group-has-[a:focus-visible]/card:bg-size-[100%_1.5px] pb-px']">{{ news.title }}</span>
            </NuxtLinkLocale>
          </h3>
        </div>
      </div>

      <div class="pt-3 news-list:contents">
        <p
          class="line-clamp-2 text-[16px] leading-[1.45] text-prose [text-wrap:pretty] news-list:col-start-1 news-list:row-start-3 md:news-list:col-start-2 news-list:mt-2 news-list:max-w-[62ch] news-list:text-[16px] news-list:text-meta max-md:news-list:hidden"
          :class="lead ? 'max-w-[64ch] text-[18px]' : ''"
        >{{ dek }}</p>
        <p class="mt-1.5 text-note text-meta news-list:col-start-1 news-list:row-start-4 md:news-list:col-start-2 news-list:mt-2.5 news-list:text-[14px]">
          {{ t('news.markSource') }} <b class="font-medium text-foreground">{{ news.sourceName }}</b>
        </p>
      </div>

      <UiPhoto
        v-if="image && age === 0"
        :media="image"
        sizes="xs:96px md:144px"
        class="hidden aspect-[3/2] w-24 rounded-slab news-list:col-start-2 news-list:row-span-4 news-list:row-start-1 news-list:block md:news-list:col-start-3 md:news-list:w-36"
        aria-hidden="true"
      />
    </article>
  </li>
</template>
