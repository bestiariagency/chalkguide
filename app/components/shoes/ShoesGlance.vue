<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/**
 * Home section (D44): dark slate with chalk dust. Centred title like the hero's H1, the author's
 * note big, and the plaques as the table header. md+: transposed table; < md: rows with a plaque.
 * Without a note the quote disappears; without photos the poster takes the plaque.
 */
const props = defineProps<{ shoes: ShoeSummary[] }>()
const { t } = useI18n()

const learned = computed(() => props.shoes.find((shoe) => shoe.authorHeadline))
const hasAffiliate = computed(() => props.shoes.some((shoe) => shoe.isAffiliate))
</script>

<template>
  <section
    id="pies-de-gato"
    data-nav-section="climbing-shoes"
    class="chrome-dark dust scroll-mt-14"
    aria-labelledby="home-shoes-title"
  >
    <div class="mx-auto max-w-page px-4 py-20 md:px-6 md:py-28 lg:py-[120px]">
      <h2 id="home-shoes-title" class="title-section text-center">{{ t('home.shoes.title') }}</h2>
      <blockquote v-if="learned" class="mx-auto mt-8 max-w-[34ch] text-center">
        <p class="-rotate-1 font-hand text-[26px] leading-none text-accent">{{ t('shoes.learned') }}</p>
        <p class="mt-3 font-hand text-[32px] leading-[1.08] md:text-[44px]">{{ learned.authorHeadline }}</p>
      </blockquote>

      <ShoesGlanceTable :shoes="shoes" class="mt-14 hidden md:block" />
      <ShoesGlanceCards :shoes="shoes" class="mt-10 md:hidden" />

      <div class="mt-10 flex flex-wrap items-center justify-center gap-x-5 gap-y-3">
        <UiButton variant="ghost" arrow :to="{ name: 'climbing-shoes' }">
          {{ t('shoes.openComparator') }}
        </UiButton>
        <UiBadge v-if="hasAffiliate" kind="affiliate">{{ t('shoes.containsAffiliate') }}</UiBadge>
      </div>
    </div>
  </section>
</template>
