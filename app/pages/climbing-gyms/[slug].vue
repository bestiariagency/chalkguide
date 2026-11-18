<script setup lang="ts">
import type { GymSummary } from '~/types/domain'

/**
 * Gym page (F3.5). 404 if missing or without an English version under /en (D3). Order:
 * author review first, then data, facilities + indices, readers' opinions, partner block.
 * Queries: summary (+ batched indices and score), detail, scores/ratings/reviews: all by item id.
 * SEO: item metadata + `SportsActivityLocation` (with author `Review`, and `AggregateRating` only
 * with the minimum of real reader opinions) + `BreadcrumbList`.
 */
const { t } = useI18n()
const route = useRoute()
const slug = computed(() => String(route.params.slug))

const { data } = await useGym(slug)
await useSlugRedirect(data.value, 'gym', 'climbing-gyms-slug')
useDetailLocales(data.value, 'climbing-gyms')
const gym = computed(() => data.value as GymSummary)

const itemId = gym.value.id
const [{ data: detail }, { data: feedback }, { data: settings }] = await Promise.all([
  useGymDetail(slug),
  useItemReviews(itemId),
  useSiteSettings(),
])
const minReviews = computed(() => settings.value?.minUserReviewsForAverage ?? 3)

useItemSeo(gym, 'gym')

const absolute = useAbsoluteUrl()
const { aboutUrl } = useAuthorUrl()
const mediaUrl = useMediaUrl()
useJsonLd('gym', () =>
  placeLd({
    type: 'SportsActivityLocation',
    url: absolute(route.path),
    name: gym.value.name,
    description: gym.value.summary ?? undefined,
    image: gym.value.cover ? mediaUrl(gym.value.cover.path) : undefined,
    address: detail.value?.address,
    postalCode: detail.value?.postalCode,
    city: detail.value?.city,
    websiteUrl: detail.value?.websiteUrl,
    priceRange: detail.value?.prices.day ? `${detail.value.prices.day} €` : undefined,
    openingHours: detail.value?.openingHours,
    review: authorReviewLd(detail.value?.review, gym.value.authorScore, aboutUrl),
    aggregateRating: aggregateRatingLd(feedback.value?.ratings, minReviews.value),
  }),
)
useBreadcrumbJsonLd(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.gyms'), to: { name: 'climbing-gyms' } },
  { label: gym.value.name },
])
</script>

<template>
  <div>
    <GymsGymHeader :gym="gym" :detail="detail" />

    <div class="mx-auto grid max-w-page gap-12 px-4 py-12 md:px-6 md:py-16 lg:grid-cols-12 lg:gap-16">
      <div class="min-w-0 space-y-16 md:space-y-20 lg:col-span-8">
        <ItemsGallery
          v-if="gym.cover || detail?.gallery.length"
          :cover="gym.cover" :gallery="detail?.gallery ?? []"
        />
        <ItemsAuthorReview
          :title="t('gyms.detail.nav.review')"
          :empty-text="t('gyms.detail.noReview')"
          :review="detail?.review ?? null"
          :criteria="feedback?.author ?? []"
          :overall="gym.authorScore"
        />
        <GymsStyleScales :gym="gym" />
        <template v-if="detail">
          <GymsGymPrices :detail="detail" />
          <GymsGymFacilities :gym="gym" :detail="detail" />
        </template>
        <ItemsOpinions
          v-if="feedback"
          :ratings="feedback.ratings"
          :reviews="feedback.reviews"
          :criteria="feedback.author"
          :min-reviews="minReviews"
          :item-id="gym.id"
          category="gym"
          :item-name="gym.name"
        />
        <GymsGymPartner :gym-name="gym.name" />
      </div>
      <GymsGymSidebar v-if="detail" :gym="gym" :detail="detail" />
    </div>
  </div>
</template>
