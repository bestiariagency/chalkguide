<script setup lang="ts">
import type { NavCard } from '~/types/nav-preview'
import { HERO_PLIES } from '~/utils/hero'

/**
 * Thin twin of the hero cards (292x104, same volume, sheen and edge) that slides under the nav
 * links (docs/design/site/pages/home-nav-desktop.html). Purely decorative: the links are the
 * accessible route, so it is `aria-hidden` and its faces are out of the tab order. Position,
 * lean and visibility are written by `useNavSpring` through `data-*` attributes and inline styles.
 * Faces exist only once the data has arrived (nothing is rendered on the server).
 */
defineProps<{ cards: NavCard[] }>()

const FACE =
  'hero-face flex items-center gap-3 p-2.5 text-white opacity-0 pointer-events-none transition-opacity duration-[160ms] data-[on]:pointer-events-auto data-[on]:opacity-100'
const TILE = 'relative size-21 shrink-0 overflow-hidden rounded-sm'
const BIG =
  'grid place-content-center text-center font-display text-[34px]/[.95] font-bold font-stretch-expanded tracking-[-0.03em]'
</script>

<template>
  <div
    data-nav-card
    aria-hidden="true"
    class="pointer-events-none invisible absolute top-[calc(100%+6px)] left-0 z-[45] h-26 w-73 origin-top rounded-md opacity-0 [--face-bg:var(--color-nav-card)] [--ply-step:-0.6px] [perspective:800px] [transition:opacity_180ms,visibility_0s_linear_180ms] data-[on]:pointer-events-auto data-[on]:visible data-[on]:opacity-100 data-[on]:[transition:opacity_220ms_var(--ease-out),visibility_0s] [@media(hover:none)]:hidden"
  >
    <!-- The slab keeps its own --ry (the mock does too): only the card's lean follows the motion. -->
    <div class="hero-slab [--rx:-5deg] [--ry:0deg]">
      <template v-if="cards.length">
        <i v-for="n in HERO_PLIES" :key="n" class="hero-ply" :style="{ '--i': n }" />
      </template>
      <NuxtLinkLocale
        v-for="card in cards"
        :key="card.name"
        :to="{ name: card.name }"
        tabindex="-1"
        :data-nav-face="card.name"
        :class="FACE"
      >
        <span v-if="card.tile.kind === 'photo'" :class="TILE">
          <NuxtImg
            :src="card.tile.src"
            alt=""
            width="84"
            height="84"
            loading="lazy"
            class="absolute inset-0 size-full object-cover"
          />
        </span>
        <span v-else-if="card.tile.kind === 'shoe'" :class="[TILE, 'bg-accent-fill']">
          <NuxtImg
            :src="card.tile.src"
            alt=""
            width="76"
            height="76"
            loading="lazy"
            class="absolute inset-[5%] size-[90%] object-contain mix-blend-multiply"
          />
        </span>
        <span v-else-if="card.tile.kind === 'num'" :class="[TILE, BIG, 'bg-nav-tile text-white']">
          {{ card.tile.text }}
        </span>
        <span
          v-else-if="card.tile.kind === 'date'"
          :class="[TILE, BIG, 'bg-paper text-ink uppercase']"
        >
          {{ card.tile.day }}
          <em class="mt-0.5 block text-[17px] tracking-[-0.01em] not-italic">
            {{ card.tile.month }}
          </em>
        </span>
        <span class="block min-w-0">
          <strong
            class="line-clamp-3 font-medium tracking-[-0.01em] text-balance"
            :class="card.tight ? 'text-[15px]/[1.3]' : 'text-[17px]/[1.22]'"
          >
            {{ card.title }}
          </strong>
          <small class="mt-1 block text-[14px]/[1.32] text-balance text-prose/85">
            {{ card.note }}
          </small>
        </span>
        <i class="hero-sheen" />
      </NuxtLinkLocale>
    </div>
  </div>
</template>
