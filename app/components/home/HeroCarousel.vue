<script setup lang="ts">
import type { HeroCardData } from '~/types/ui'

/**
 * Home hero (D38-D41): the page's only h1 and a cylindrical carousel of the most relevant
 * content. Manual only (no autoplay). Sits under the real header, so it is 100svh minus the
 * header; its ground is the header's #0f0f0f. The rope overflows into "¿Por dónde empiezas?".
 */
const props = defineProps<{ cards: HeroCardData[] }>()
const { t } = useI18n()

const hero = ref<HTMLElement | null>(null)
const ring = ref<HTMLElement | null>(null)
const scene = ref<HTMLElement | null>(null)
const rope = ref<HTMLElement | null>(null)

const { live, ready, dragging, moving, layoutKey, spinIn } = useHeroRing({ hero, ring, scene })
useHeroRope({ hero, ring, rope, layoutKey })
const intro = useHeroIntro(spinIn)

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
      class="hero-edge--l pointer-events-none absolute inset-y-0 left-0 z-2 w-[clamp(24px,11vw,190px)] opacity-70 transition-opacity duration-500 ease-out group-[.is-moving]/hero:opacity-100"
      aria-hidden="true"
    />
    <i
      class="hero-edge--r pointer-events-none absolute inset-y-0 right-0 z-2 w-[clamp(24px,11vw,190px)] opacity-70 transition-opacity duration-500 ease-out group-[.is-moving]/hero:opacity-100"
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
      role="group"
      :aria-roledescription="t('home.hero.regionRole')"
      :aria-label="t('home.hero.regionLabel')"
      tabindex="-1"
      class="hero-ring relative z-1 mt-[clamp(4px,1.5svh,18px)] mb-[clamp(64px,11svh,108px)] min-h-80 flex-1 touch-pan-y select-none [--h:calc(var(--w)/.74)] [--p:1000px] [--w:min(21vw,52svh)] perspective-(--p) max-[899px]:mb-19 max-[899px]:min-h-75 max-[899px]:[--h:calc(var(--w)/.76)] max-[899px]:[--w:min(74vw,50svh)] min-[600px]:max-[899px]:[--w:min(46vw,50svh)]"
      :class="[ready && 'is-ready', dragging ? 'cursor-grabbing' : 'cursor-grab']"
    >
      <div ref="scene" class="hero-scene absolute inset-0 transform-3d">
        <HomeHeroCard
          v-for="(card, i) in props.cards"
          :key="card.key"
          :card="card"
          :eager="i === 0"
          :plies="ready"
        />
      </div>
    </div>

    <div
      v-if="props.cards.length"
      ref="rope"
      class="hero-rope pointer-events-none absolute bottom-[calc(14px-var(--drop,0px))] left-1/2 z-0 h-[calc(var(--rest,120px)-14px+var(--drop,0px))] w-0 origin-top"
    >
      <HomeHeroRope />
    </div>
    <p class="sr-only" aria-live="polite">{{ live }}</p>
  </section>
</template>
