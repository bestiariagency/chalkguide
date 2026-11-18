<script setup lang="ts">
import type { ResolerSummary } from '~/types/domain'

/**
 * Resoler page (F3.6). 404 if missing or without an English version under /en (D3).
 * Order: author review first, gallery only with media, readers' opinions; side column with
 * prices (dated), contact and related articles. Queries are by item id, in parallel.
 * SEO: item metadata + `LocalBusiness` (author `Review`, `AggregateRating` only with the minimum
 * of real reader opinions) + `BreadcrumbList`.
 */
const { t } = useI18n()
const route = useRoute()
const slug = computed(() => String(route.params.slug))

const { data } = await useResoler(slug)
await useSlugRedirect(data.value, 'resoler', 'climbing-shoe-resoling-slug')
useDetailLocales(data.value, 'climbing-shoe-resoling')
const resoler = computed(() => data.value as ResolerSummary)

const itemId = resoler.value.id
const [{ data: detail }, { data: feedback }, { data: settings }] = await Promise.all([
  useResolerDetail(slug),
  useItemReviews(itemId),
  useSiteSettings(),
])
const minReviews = computed(() => settings.value?.minUserReviewsForAverage ?? 3)

useItemSeo(resoler, 'resoler')

const absolute = useAbsoluteUrl()
const { aboutUrl } = useAuthorUrl()
const mediaUrl = useMediaUrl()
useJsonLd('resoler', () =>
  placeLd({
    type: 'LocalBusiness',
    url: absolute(route.path),
    name: resoler.value.name,
    description: resoler.value.summary ?? undefined,
    image: resoler.value.cover ? mediaUrl(resoler.value.cover.path) : undefined,
    address: detail.value?.address,
    postalCode: detail.value?.postalCode,
    city: detail.value?.city,
    websiteUrl: detail.value?.websiteUrl,
    priceRange: resoler.value.pricePerPair ? `${resoler.value.pricePerPair} €` : undefined,
    review: authorReviewLd(detail.value?.review, resoler.value.authorScore, aboutUrl),
    aggregateRating: aggregateRatingLd(feedback.value?.ratings, minReviews.value),
  }),
)
useBreadcrumbJsonLd(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.resoling'), to: { name: 'climbing-shoe-resoling' } },
  { label: resoler.value.name },
])
</script>

<template>
  <div>
    <ResolersResolerHeader :resoler="resoler" />

    <div class="mx-auto grid max-w-page gap-12 px-4 py-12 md:px-6 md:py-16 lg:grid-cols-12 lg:gap-16">
      <div class="min-w-0 space-y-16 md:space-y-20 lg:col-span-8">
        <ItemsAuthorReview
          :title="t('resolers.detail.reviewTitle')"
          :empty-text="t('resolers.detail.noReview')"
          :date-label="t('resolers.detail.resoledIn')"
          month-only
          hide-empty-title
          :paid-label="t('resolers.detail.paidByMe')"
          :guest-label="t('resolers.detail.guest')"
          :review="detail?.review ?? null"
          :criteria="feedback?.author ?? []"
          :overall="resoler.authorScore"
        />
        <ItemsGallery
          v-if="resoler.cover || detail?.gallery.length"
          :cover="resoler.cover"
          :gallery="detail?.gallery ?? []"
        />
        <ItemsOpinions
          v-if="feedback"
          :ratings="feedback.ratings"
          :reviews="feedback.reviews"
          :criteria="feedback.author"
          :min-reviews="minReviews"
          :item-id="resoler.id"
          category="resoler"
          :item-name="resoler.name"
          :empty-hint="t('resolers.detail.emptyHint')"
        />
      </div>
      <ResolersResolerSidebar :resoler="resoler" :detail="detail ?? null" />
    </div>
  </div>
</template>
