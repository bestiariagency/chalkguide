<script setup lang="ts">
import { ChevronLeft, ChevronRight } from 'lucide-vue-next'
import type { HeroCardData } from '~/types/ui'

/**
 * Home hero (D38-D41, §19): the page's only h1 and a carousel of the most relevant content. Manual
 * only (no autoplay). One markup, two layouts decided by CSS (900px): a flat native scroll-snap row
 * below it (pager, still rope), the cylinder ring above it (useHeroRing, swaying rope). Sits under
 * the real header, so it is 100svh minus the header; its ground is the header's #0f0f0f. The rope
 * overflows into "¿Por dónde empiezas?".
 */
const props = defineProps<{ cards: HeroCardData[] }>()
const { t } = useI18n()

const hero = ref<HTMLElement | null>(null)
const ring = ref<HTMLElement | null>(null)
const scene = ref<HTMLElement | null>(null)
const rope = ref<HTMLElement | null>(null)

const { live, ready, dragging, moving, ropeRest, ropeMaxDrop, spinIn } = useHeroRing({ hero, ring, scene })
useHeroRope({ rope, rest: ropeRest, maxDrop: ropeMaxDrop })
const intro = useHeroIntro(spinIn)
const total = computed(() => props.cards.length)
const snap = useHeroSnap(scene, total)

const pagerButton =
  'grid size-11 place-items-center rounded-full border border-foreground/45 text-foreground transition-[background-color,opacity] duration-150 hover:bg-foreground/8 active:bg-foreground/16 aria-disabled:cursor-default aria-disabled:opacity-35 aria-disabled:hover:bg-transparent motion-reduce:transition-none'

const title = computed(() => splitHeroTitle(t('home.hero.title')))
</script>

<template>
  <section
    ref="hero"
    class="hero-ground chrome-dark group/hero relative isolate z-10 flex min-h-[calc(100svh-4rem)] flex-col overflow-x-clip bg-background text-foreground md:min-h-[calc(100svh-5rem)]"
    :class="{ 'is-moving': moving }"
    aria-labelledby="home-hero-title"
  >
    <HomeHeroIntro
      v-if="intro.active.value"
      :up="intro.up.value"
      :open="intro.open.value"
      :grade="intro.grade.value"
      @skip="intro.finish"
    />
    <i
      class="hero-edge--l pointer-events-none absolute inset-y-0 left-0 z-2 w-5 min-[900px]:w-[clamp(24px,11vw,190px)] min-[900px]:opacity-70 min-[900px]:transition-opacity min-[900px]:duration-500 min-[900px]:ease-out min-[900px]:group-[.is-moving]/hero:opacity-100"
      aria-hidden="true"
    />
    <i
      class="hero-edge--r pointer-events-none absolute inset-y-0 right-0 z-2 w-5 min-[900px]:w-[clamp(24px,11vw,190px)] min-[900px]:opacity-70 min-[900px]:transition-opacity min-[900px]:duration-500 min-[900px]:ease-out min-[900px]:group-[.is-moving]/hero:opacity-100"
      aria-hidden="true"
    />

    <h1
      id="home-hero-title"
      class="hero-title relative z-1 mt-[clamp(4px,2.2svh,28px)] px-4 text-center font-display text-[clamp(30px,10vw,76px)]/[1.04] font-bold tracking-[-0.02em] text-white uppercase font-stretch-expanded min-[900px]:text-[clamp(44px,5.05vw,92px)]/none min-[900px]:whitespace-nowrap"
    >
      <span class="block min-[900px]:inline-block">{{ title[0] }}</span>
      {{ ' ' }}
      <span class="block min-[900px]:inline-block">{{ title[1] }}</span>
    </h1>

    <div
      v-if="props.cards.length"
      ref="ring"
      role="region"
      :aria-roledescription="t('home.hero.regionRole')"
      :aria-label="t('home.hero.regionLabel')"
      tabindex="-1"
      class="hero-ring relative z-1 mt-[clamp(12px,2.4svh,24px)] [--cw:min(82vw,340px,calc((100svh-330px)*.76))] [--gap:12px] min-[600px]:[--cw:min(44vw,360px,calc((100svh-330px)*.76))] min-[600px]:[--gap:16px] min-[900px]:mt-[clamp(4px,1.5svh,18px)] min-[900px]:mb-[clamp(64px,11svh,108px)] min-[900px]:min-h-80 min-[900px]:flex-1 min-[900px]:touch-pan-y min-[900px]:select-none min-[900px]:[--h:calc(var(--w)/.74)] min-[900px]:[--w:min(21vw,52svh)]"
      :class="[ready && 'is-ready', dragging ? 'min-[900px]:cursor-grabbing' : 'min-[900px]:cursor-grab']"
    >
      <ul id="hero-track" ref="scene" class="hero-scene">
        <li
          v-for="(card, i) in props.cards"
          :key="card.key"
          class="hero-slide"
          role="group"
          :aria-roledescription="t('home.hero.slideRole')"
          :aria-label="t('home.hero.slideLabel', { n: i + 1, total })"
        >
          <HomeHeroCard :card="card" :eager="i === 0" />
        </li>
      </ul>
    </div>

    <!-- Pager: phones only (the ring has its own gestures). Dots are decorative. -->
    <div
      v-if="props.cards.length"
      class="relative z-1 mt-1 flex items-center justify-center gap-3 min-[900px]:hidden [html:not(.js)_&]:hidden"
    >
      <button
        type="button"
        :aria-label="t('home.hero.prev')"
        aria-controls="hero-track"
        :aria-disabled="snap.atStart.value"
        :class="pagerButton"
        @click="snap.prev"
      >
        <ChevronLeft class="size-5" aria-hidden="true" />
      </button>
      <span class="flex h-11 items-center gap-1.5 px-1" aria-hidden="true">
        <i
          v-for="(card, i) in props.cards"
          :key="card.key"
          class="block h-1.5 rounded-[3px] transition-[width,background-color] duration-180 motion-reduce:transition-none"
          :class="i === snap.active.value ? 'w-5 bg-accent' : 'w-1.5 bg-hero-dot'"
        />
      </span>
      <button
        type="button"
        :aria-label="t('home.hero.next')"
        aria-controls="hero-track"
        :aria-disabled="snap.atEnd.value"
        :class="pagerButton"
        @click="snap.next"
      >
        <ChevronRight class="size-5" aria-hidden="true" />
      </button>
    </div>

    <div
      v-if="props.cards.length"
      ref="rope"
      class="hero-rope pointer-events-none relative z-0 mx-auto -mt-2.5 -mb-10 w-0 flex-[1_0_96px] origin-top min-[900px]:absolute min-[900px]:bottom-[calc(14px-var(--drop,0px))] min-[900px]:left-1/2 min-[900px]:m-0 min-[900px]:h-[calc(var(--rest,120px)-14px+var(--drop,0px))] min-[900px]:flex-none"
    >
      <HomeHeroRope />
    </div>
    <p class="sr-only" aria-live="polite">{{ live }}</p>
    <p class="sr-only" aria-live="polite">{{ snap.live.value }}</p>
  </section>
</template>
