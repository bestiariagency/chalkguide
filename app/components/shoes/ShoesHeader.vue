<script setup lang="ts">
import { Plus } from 'lucide-vue-next'
import type { MediaRef, ShoeSummary, UserRatings } from '~/types/domain'
import type { BreadcrumbItem } from '~/types/ui'

/** Shoe page header (README §9.5): gallery, summary, 3 key facts, affiliate mark and section nav. */
const props = defineProps<{
  shoe: ShoeSummary
  gallery: MediaRef[]
  ratings: UserRatings | null
  hasReview: boolean
}>()
const { t, locale } = useI18n()

const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.shoes'), to: { name: 'climbing-shoes' } },
  { label: props.shoe.name },
])
const badges = computed(() =>
  [
    props.shoe.levels.length && props.shoe.levels.map((l) => t(`shoes.level.${l}`)).join(' · '),
    props.shoe.profile && t(`shoes.profile.${props.shoe.profile}`),
    props.shoe.closure && t(`shoes.closure.${props.shoe.closure}`),
    props.shoe.recommendedUse.length &&
      props.shoe.recommendedUse.map((u) => t(`shoes.use.${u}`)).join(' · '),
  ].filter((b): b is string => typeof b === 'string' && b.length > 0),
)
const price = computed(() => formatEurRange(props.shoe.priceMin, props.shoe.priceMax, locale.value))
const checked = computed(() =>
  props.shoe.priceCheckedAt ? formatDate(props.shoe.priceCheckedAt, locale.value, SHORT_MONTH_DATE) : null,
)
const sections = computed(() => [
  ...(props.hasReview ? ['review'] : []),
  'data',
  'opinions',
  'alternatives',
])
</script>

<template>
  <section class="border-b-[0.5px] border-line board-tex">
    <div class="mx-auto max-w-page px-4 pt-8 pb-10 md:px-6 md:pt-10 md:pb-12">
      <UiBreadcrumbs :items="crumbs" />
      <div class="mt-6 grid items-start gap-8 lg:grid-cols-12 lg:gap-12">
        <ShoesGallery
          class="lg:col-span-6"
          :cover="shoe.cover"
          :gallery="gallery"
          :name="shoe.name"
          :brand="shoe.brand"
          :model="shoe.model"
        />
        <div class="min-w-0 lg:col-span-6">
          <p class="label-mini">{{ shoe.brand }}</p>
          <h1 class="mt-3 text-title-1 font-medium">{{ shoe.model }}</h1>
          <p v-if="shoe.summary" class="mt-4 max-w-read text-body-lg text-meta">{{ shoe.summary }}</p>
          <ul v-if="badges.length" class="mt-5 flex flex-wrap gap-2" :aria-label="t('shoes.detail.summaryLabel')">
            <li v-for="badge in badges" :key="badge"><UiBadge>{{ badge }}</UiBadge></li>
          </ul>

          <dl class="mt-6 grid grid-cols-3 gap-4 border-t-[0.5px] border-line-strong pt-5 tabular-nums">
            <div>
              <dt class="text-caption text-meta">{{ t('shoes.detail.price') }}</dt>
              <dd class="mt-1 font-mono text-[22px] leading-tight md:text-[26px]" :class="price ? 'text-accent' : 'text-meta'">
                {{ price ?? t('common.priceUnavailable') }}
              </dd>
              <dd v-if="checked" class="mt-1 font-mono text-micro text-meta">
                {{ t('shoes.detail.priceChecked', { date: checked }) }}
              </dd>
            </div>
            <div>
              <dt class="text-caption text-meta">{{ t('ratings.author') }}</dt>
              <dd v-if="shoe.authorScore !== null" class="mt-1">
                <span class="font-mono text-[22px] leading-tight text-accent md:text-[26px]">{{ formatScore(shoe.authorScore, locale) }}</span>
                <span class="ml-1 text-caption text-meta">{{ t('ratings.outOf') }}</span>
              </dd>
              <dd v-else class="mt-1 text-body-sm">{{ t('shoes.compare.notUsed') }}</dd>
            </div>
            <div>
              <dt class="text-caption text-meta">{{ t('shoes.detail.readers') }}</dt>
              <dd v-if="ratings?.avgOverall != null" class="mt-1">
                <span class="font-mono text-[22px] leading-tight md:text-[26px]">{{ formatScore(ratings.avgOverall, locale) }}</span>
                <span class="ml-1 text-caption text-meta">{{ t('ratings.outOf') }}</span>
              </dd>
              <dd v-else class="mt-1 text-body-sm">
                {{ ratings?.reviewCount ? t('shoes.detail.noAverage') : t('shoes.detail.noOpinions') }}
              </dd>
              <dd v-if="ratings?.reviewCount" class="mt-1 font-mono text-micro text-meta">
                <UiTextLink href="#opinions">{{ t('ratings.reviewsCount', ratings.reviewCount) }}</UiTextLink>
              </dd>
            </div>
          </dl>

          <div class="mt-6 flex flex-wrap items-start gap-3">
            <ShoesAffiliate :shoe="shoe" variant="hero" />
            <UiButton
              variant="inline"
              :icon="Plus"
              :to="{ name: 'climbing-shoes', query: { comparar: shoe.slug }, hash: '#comparacion' }"
            >
              {{ t('common.compare') }}
            </UiButton>
          </div>
        </div>
      </div>
      <nav :aria-label="t('shoes.detail.onThisPage')" class="-mx-4 mt-10 overflow-x-auto px-4">
        <ul class="flex gap-6 text-body-sm whitespace-nowrap">
          <li v-for="id in sections" :key="id">
            <a
              :href="`#${id}`"
              class="inline-flex min-h-11 items-center text-meta transition-colors duration-150 hover:text-foreground focus-visible:text-foreground"
            >
              {{ t(`shoes.detail.nav.${id}`) }}
            </a>
          </li>
        </ul>
      </nav>
    </div>
  </section>
</template>
