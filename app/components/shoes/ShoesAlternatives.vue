<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/** Three models of the same level / profile, plus the way into the comparator. */
defineProps<{ shoes: ShoeSummary[] }>()
const { t, locale } = useI18n()
const meta = (s: ShoeSummary) =>
  [s.profile && t(`shoes.profile.${s.profile}`), s.closure && t(`shoes.closure.${s.closure}`).toLowerCase(), s.rubber]
    .filter(Boolean)
    .join(' · ')
</script>

<template>
  <section v-if="shoes.length" id="alternatives" class="scroll-mt-20 border-t-[0.5px] border-line" aria-labelledby="shoe-alt">
    <div class="mx-auto max-w-page px-4 py-12 md:px-6 md:py-16">
      <h2 id="shoe-alt" class="text-title-2 font-medium">{{ t('shoes.detail.alternatives') }}</h2>
      <ul class="mt-6 grid gap-3 tabular-nums sm:grid-cols-3">
        <li v-for="s in shoes" :key="s.id">
          <article :class="[cardSurface, 'group/card h-full p-5']">
            <p class="text-caption text-meta">{{ s.brand }}</p>
            <h3 class="text-lg font-medium">
              <NuxtLinkLocale
                :to="{ name: 'climbing-shoes-slug', params: { slug: s.slug } }"
                :class="rowOverlayLink"
              >
                <span :class="cardTitleUnderline">{{ s.model }}</span>
              </NuxtLinkLocale>
            </h3>
            <p class="mt-1 text-caption text-meta">{{ meta(s) }}</p>
            <p class="mt-3 font-mono" :class="s.priceMin !== null ? 'text-accent' : 'text-meta'">
              {{ formatEurRange(s.priceMin, s.priceMax, locale) ?? t('common.priceUnavailable') }}
            </p>
          </article>
        </li>
      </ul>
      <UiButton variant="ghost" arrow class="mt-6" :to="{ name: 'climbing-shoes' }">
        {{ t('shoes.openComparator') }}
      </UiButton>
    </div>
  </section>
</template>
