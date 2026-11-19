<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

// Shoe page (3.17): 404 if missing or without an English version
// under /en (D3); the language switcher learns which versions exist.
const { t } = useI18n()
const route = useRoute()
const slug = computed(() => String(route.params.slug))

const { data } = await useShoe(slug)
await useSlugRedirect(data.value, 'shoe', 'climbing-shoes-slug')
useTrackContext().setTrackContext({ contentType: 'shoe', contentSlug: data.value?.slug }) // analytics (D69)
useDetailLocales(data.value, 'climbing-shoes')
const title = computed(() => data.value?.name ?? slug.value)

// SEO: item metadata + `Product` with a price range (no affiliate URL in the data) + breadcrumbs.
const shoe = computed(() => data.value as ShoeSummary)

// Readers' opinions and the review/gallery extras (fetched by item id).
const [{ data: feedback }, { data: settings }, { data: extras }, { data: allShoes }] = await Promise.all([
  useItemReviews(shoe.value.id),
  useSiteSettings(),
  useShoeExtras(slug),
  useShoes('all'),
])
const minReviews = computed(() => settings.value?.minUserReviewsForAverage ?? 3)
const alternatives = computed(() => pickAlternatives(shoe.value, allShoes.value ?? []))
const review = computed(() => extras.value?.review ?? null)
useItemSeo(shoe, 'shoe')
const absolute = useAbsoluteUrl()
const { aboutUrl } = useAuthorUrl()
const mediaUrl = useMediaUrl()
useJsonLd('shoe', () =>
  productLd({
    url: absolute(route.path),
    name: shoe.value.name,
    brand: shoe.value.brand,
    description: shoe.value.summary ?? undefined,
    image: shoe.value.cover ? mediaUrl(shoe.value.cover.path) : undefined,
    priceMin: shoe.value.priceMin,
    priceMax: shoe.value.priceMax,
    // Only models the author has really used carry his score.
    review: shoe.value.ownedByAuthor
      ? authorReviewLd(
          review.value ?? { headline: shoe.value.authorHeadline, bodyHtml: shoe.value.authorHeadline ?? '' },
          shoe.value.authorScore,
          aboutUrl,
        )
      : undefined,
  }),
)
useBreadcrumbJsonLd(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.shoes'), to: { name: 'climbing-shoes' } },
  { label: title.value },
])
</script>

<template>
  <div>
    <ShoesHeader
      :shoe="shoe"
      :gallery="extras?.gallery ?? []"
      :ratings="feedback?.ratings ?? null"
      :has-review="!!review"
    />

    <div class="mx-auto grid max-w-page gap-12 px-4 py-12 md:px-6 md:py-16 lg:grid-cols-12 lg:gap-14">
      <div class="min-w-0 lg:col-span-7">
        <ItemsAuthorReview
          v-if="review"
          :title="t('shoes.detail.nav.review')"
          :empty-text="t('shoes.detail.noReview.title')"
          :review="review"
          :criteria="feedback?.author ?? []"
          :overall="shoe.authorScore"
          :date-label="t('shoes.detail.usingSince')"
          month-only
          :learned-title="t('shoes.learned')"
        >
          <template #after-author><ShoesSizeStrip :shoe="shoe" /></template>
        </ItemsAuthorReview>
        <ShoesNoReview v-else />
      </div>
      <ShoesSpecs :shoe="shoe" />
    </div>

    <div class="border-t-[0.5px] border-line">
      <div class="mx-auto max-w-page px-4 py-12 md:px-6 md:py-16">
        <ItemsOpinions
          v-if="feedback"
          :ratings="feedback.ratings"
          :reviews="feedback.reviews"
          :criteria="feedback.author"
          :min-reviews="minReviews"
          :item-id="shoe.id"
          category="shoe"
          :item-name="shoe.name"
          :empty-hint="t('shoes.emptyHint')"
        />
      </div>
    </div>

    <ShoesAlternatives :shoes="alternatives" />
  </div>
</template>
