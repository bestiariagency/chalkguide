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

const link = resolveComponent('NuxtLinkLocale')
const isPhoto = computed(() => props.card.kind === 'photo')

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
    :class="`hero-card--${card.kind}`"
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
        <div
          v-if="card.eyebrow"
          class="absolute inset-x-0 bottom-0 px-4 pb-3.5 [opacity:var(--cap,1)] max-[599px]:px-3.5 max-[599px]:pb-3"
          :class="capBase"
        >
          <span class="label-mini block" :class="tone.eyebrow">{{ card.eyebrow }}</span>
          <strong
            class="mt-2 block text-[19px]/[1.3] font-medium tracking-[-0.01em] text-balance"
          >
            {{ card.title }}
          </strong>
          <small v-if="card.note" class="mt-[5px] block text-caption/[1.35]" :class="tone.note">
            {{ card.note }}
          </small>
        </div>
        <i class="hero-sheen" />
      </div>
    </div>
  </component>
</template>
