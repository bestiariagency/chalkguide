<script setup lang="ts">
import type { HeroCardData } from '~/types/ui'

/**
 * One slab of the hero carousel. Photos are plain (no text, no link); the rest are links.
 * The plies (thickness) only exist on the client: 18 per card would bloat the SSR HTML.
 */
const props = defineProps<{
  card: HeroCardData
  /** The first image is the page's LCP: eager and high priority; the others lazy. */
  eager?: boolean
  plies?: boolean
}>()

const { t } = useI18n()
const link = resolveComponent('NuxtLinkLocale')
const isPhoto = computed(() => props.card.kind === 'photo')
// News (D89): with a photo it is a gym/article-like card with the dominant colour in the foot; without, the category tile of /noticias.
const isNews = computed(() => props.card.kind === 'news')
const newsText = computed(() => isNews.value && !props.card.image)
const newsClass = computed(() => (isNews.value ? newsToneClass(props.card.news?.categorySlug) : ''))
const newsStyle = computed(() => (props.card.news?.dominant ? { '--dom': props.card.news.dominant } : undefined))

// Text colour per base: chalk on photos, ink on the orange shoe card and on the paper event.
const tone = computed(() => {
  if (props.card.kind === 'shoe') return { eyebrow: '!text-on-accent', note: 'text-on-accent' }
  if (props.card.kind === 'event') return { eyebrow: '!text-accent-ink', note: 'text-meta-ink' }
  return { eyebrow: '!text-accent', note: 'text-prose' }
})
// Caption base: soft fade on photos, near-black for gyms/articles, none on the flat shoe/event bases.
const capBase = computed(() => {
  const { kind, strong } = props.card
  if (kind === 'shoe' || kind === 'event') return 'pt-18 max-[599px]:pt-14'
  // CSS fallback is not needed: the foot mixes the photo's dominant colour with black (D22), always dark enough for the chalk text.
  if (kind === 'news') return 'pt-26 bg-[linear-gradient(180deg,rgb(0_0_0/0),color-mix(in_oklab,var(--dom,#141414)_26%,#000)_50%,color-mix(in_oklab,var(--dom,#141414)_22%,#000)_100%)]'
  return strong
    ? 'pt-26 bg-[linear-gradient(180deg,rgb(0_0_0/0),rgb(0_0_0/.84)_46%,rgb(0_0_0/.97))]'
    : 'pt-18 max-[599px]:pt-14 bg-[linear-gradient(180deg,rgb(15_15_15/0),rgb(15_15_15/.88)_62%)]'
})

// The first card's image is the home LCP: preload it from the SSR head.
useImagePreload(() => ({
  src: props.eager ? props.card.image?.src : null,
  width: props.card.image?.width,
  height: props.card.image?.height,
  sizes: HERO_IMAGE_SIZES,
}))
</script>

<template>
  <component
    :is="card.to ? link : 'div'"
    :to="card.to ?? undefined"
    :draggable="false"
    class="hero-card"
    :class="[`hero-card--${card.kind}`, newsText ? 'hero-card--news-text' : '', newsClass]"
    :style="newsStyle"
    :data-label="card.label"
  >
    <div class="hero-slab">
      <template v-if="plies">
        <i v-for="n in HERO_PLIES" :key="n" class="hero-ply" :style="{ '--i': n }" />
      </template>
      <div class="hero-face">
        <p
          v-if="card.date"
          class="absolute top-3.5 left-4 font-display text-[31cqw]/[.92] font-bold font-stretch-expanded tracking-[-0.03em] uppercase"
        >
          <span class="block">{{ card.date.day }}</span>
          <span class="block">{{ card.date.month }}</span>
        </p>
        <NuxtImg
          v-if="card.image"
          :src="card.image.src"
          :alt="card.image.alt"
          :width="card.image.width"
          :height="card.image.height"
          :sizes="HERO_IMAGE_SIZES"
          :loading="eager ? 'eager' : 'lazy'"
          :fetchpriority="eager ? 'high' : undefined"
          :draggable="false"
          class="hero-img"
        />
        <i v-if="isPhoto" class="hero-grade" />
        <span
          v-if="isNews"
          class="absolute top-3.5 left-3.5 z-10 inline-flex items-center gap-1.5 rounded-sm bg-accent-fill px-[9px] pt-1.5 pb-[5px] font-mono text-micro leading-none tracking-[.14em] text-on-accent uppercase shadow-[0_1px_0_rgb(0_0_0/.25)]"
        >
          <i class="size-1.5 rounded-full bg-current" aria-hidden="true" />{{ t('home.hero.kind.news') }}
        </span>
        <NewsCategoryIcon
          v-if="newsText"
          :slug="card.news?.categorySlug"
          :size="24"
          :stroke-width="1"
          class="pointer-events-none absolute -right-[14%] -bottom-[10%] aspect-square h-auto w-[72%] stroke-1 text-(--tink) opacity-[.14]"
        />
        <div
          v-if="newsText"
          class="absolute inset-0 flex flex-col px-4 pt-[58px] pb-3.5 text-ink"
        >
          <span class="label-mini flex items-center gap-1.5 !text-(--tink)">
            <NewsCategoryIcon :slug="card.news?.categorySlug" :size="14" />{{ card.eyebrow }}
          </span>
          <strong class="mt-2.5 block text-[clamp(21px,9.6cqw,28px)]/[1.16] font-medium tracking-[-0.02em] text-balance">{{ card.title }}</strong>
          <small class="relative mt-auto text-[14px]/[1.35] text-meta-ink">{{ card.note }} <b class="font-medium text-ink">{{ card.source }}</b></small>
        </div>
        <div
          v-else-if="card.eyebrow"
          class="absolute inset-x-0 bottom-0 px-4 pb-3.5 [opacity:var(--cap,1)] max-[599px]:px-3.5 max-[599px]:pb-3"
          :class="capBase"
        >
          <span class="label-mini block" :class="[tone.eyebrow, isNews ? 'flex items-center gap-1.5' : '']">
            <NewsCategoryIcon v-if="isNews" :slug="card.news?.categorySlug" :size="14" />{{ card.eyebrow }}
          </span>
          <strong
            class="mt-2 block text-[19px]/[1.3] font-medium tracking-[-0.01em] text-balance"
          >
            {{ card.title }}
          </strong>
          <small v-if="card.note" class="mt-[5px] block text-caption/[1.35]" :class="tone.note">
            {{ card.note }}<template v-if="card.source"> <b class="font-medium text-foreground">{{ card.source }}</b></template>
          </small>
        </div>
        <i class="hero-sheen" />
      </div>
    </div>
  </component>
</template>
