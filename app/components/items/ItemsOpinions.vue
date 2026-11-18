<script setup lang="ts">
import { Info, Pencil } from 'lucide-vue-next'
import type { AuthorScore, UserRatings, UserReview } from '~/types/domain'
import { reviewPhotoPublicUrl } from '~/utils/review-photos'

/**
 * Readers' opinions below the author's review. The average (overall and per criterion) only
 * exists with ≥ N opinions: the view returns null otherwise and we show the explanation.
 * "Opinar" is a link to sign-in (works without JS); with a session it opens the review dialog.
 * Everything tied to the user (own review, dialog) lives in <ClientOnly>: the ISR-cached HTML is
 * the same for everyone.
 */
const props = defineProps<{
  ratings: UserRatings
  reviews: UserReview[]
  criteria: AuthorScore[]
  minReviews: number
  /** Empty-state hint, e.g. "Si has resolado aquí, cuéntalo." (defaults to the generic one). */
  emptyHint?: string
  itemId: string
  /** guide.items.category, to load the criteria to score. */
  category: string
  itemName: string
}>()
const { t, locale } = useI18n()

const initials = (name: string) =>
  name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part.charAt(0).toUpperCase())
    .join('')
const date = (iso: string) =>
  formatDate(iso, locale.value, { day: '2-digit', month: '2-digit', year: '2-digit' })
const flow = useUserReview(() => props.itemId, props.category)
const supabaseUrl = String(useRuntimeConfig().public.supabase?.url ?? '')
const mineViewable = computed(() =>
  flow.myPhotos.value.flatMap((p) => (p.status !== 'rejected' && p.src ? [{ id: p.id, src: p.src, width: p.width, height: p.height }] : [])),
)
const viewer = reactive({ open: false, index: 0, own: false, author: '', date: '', photos: [] as { id: string; src: string; width: number; height: number }[] })
function openViewer(
  photos: typeof viewer.photos,
  index: number,
  info: { own: boolean; author: string; date: string },
) {
  Object.assign(viewer, info, { photos, index, open: true })
}
function openPublic(review: UserReview, index: number) {
  const photos = review.photos.map((p) => ({ id: p.id, src: reviewPhotoPublicUrl(supabaseUrl, p.path), width: p.width, height: p.height }))
  openViewer(photos, index, { own: false, author: review.authorName, date: date(review.createdAt) })
}
const hasAverage = computed(() => props.ratings.avgOverall !== null)
</script>

<template>
  <section id="opinions" class="scroll-mt-20" aria-labelledby="item-opinions-title">
    <div class="flex flex-wrap items-end justify-between gap-4">
      <div>
        <h2 id="item-opinions-title" class="text-title-2 font-medium">{{ t('reviews.title') }}</h2>
        <p class="mt-1 text-caption text-meta">
          {{ t('ratings.reviewsCount', ratings.reviewCount) }}
        </p>
      </div>
      <UiButton
        v-if="!flow.mine.value"
        :variant="reviews.length ? 'primary' : 'ghost'"
        :to="flow.isSignedIn.value ? undefined : flow.signInLink.value"
        :icon="Pencil"
        data-review-opener
        @click="flow.onWrite"
      >
        {{ t('reviews.write') }}
      </UiButton>
    </div>

    <ClientOnly>
      <ReviewsMine
        v-if="flow.mine.value"
        :review="flow.mine.value"
        :criteria="flow.criteria.value"
        :deleting="flow.deleting.value"
        :photos="mineViewable"
        class="mt-6"
        @open-photo="(i) => openViewer(mineViewable, i, { own: true, author: '', date: date(flow.mine.value!.createdAt) })"
        @edit="flow.openForm"
        @remove="flow.remove"
      />
      <ReviewsDialog
        v-model:open="flow.open.value"
        :item-name="itemName"
        :criteria="flow.criteria.value"
        :mine="flow.mine.value"
        :step="flow.step.value"
        :submitting="flow.submitting.value"
        :failed="flow.failed.value"
        :rate-limited="flow.rateLimited.value"
        :photos="flow.photos"
        :photo-failed="flow.photoFailed.value"
        @submit="flow.submit"
        @retry-photos="flow.retryPhotos()"
        @skip-photos="flow.retryPhotos(true)"
        @edit="flow.openForm"
      />
    </ClientOnly>
    <ReviewsViewer
      v-model:open="viewer.open"
      v-model:index="viewer.index"
      :photos="viewer.photos"
      :author="viewer.author"
      :item-name="itemName"
      :date-label="viewer.date"
      :own="viewer.own"
    />

    <ItemsCriteria
      v-if="hasAverage"
      :title="t('ratings.readers')"
      :overall="ratings.avgOverall"
      :criteria="criteria"
      :scores="ratings.byCriterion"
      tone="readers"
      class="mt-6"
    />
    <div
      v-else-if="ratings.reviewCount > 0"
      class="mt-6 flex items-start gap-3 rounded-lg border-[0.5px] border-line-strong bg-board p-5"
    >
      <Info :size="20" class="mt-0.5 shrink-0 text-meta" aria-hidden="true" />
      <div>
        <p class="font-medium">{{ t('ratings.readers') }}</p>
        <p class="mt-1 text-caption text-meta">
          {{ t('ratings.notEnough', { min: minReviews }) }}
        </p>
      </div>
    </div>

    <ul v-if="reviews.length" class="mt-4 space-y-3">
      <li
        v-for="review in reviews"
        :key="review.id"
        class="rounded-lg border-[0.5px] border-line-strong bg-board p-5"
      >
        <div class="flex items-center justify-between gap-3">
          <div class="flex items-center gap-3">
            <div
              class="grid size-9 place-items-center rounded-full border-[0.5px] border-line bg-elevated text-xs font-medium text-accent"
              aria-hidden="true"
            >
              {{ initials(review.authorName) }}
            </div>
            <div>
              <p class="text-caption font-medium">{{ review.authorName }}</p>
              <p class="font-mono text-xs text-meta">{{ date(review.createdAt) }}</p>
            </div>
          </div>
          <ItemsScore :score="review.overall" whole class="shrink-0" />
        </div>
        <p v-if="review.body" class="mt-3 text-body-sm leading-[1.6] text-prose">
          {{ review.body }}
        </p>
        <ReviewsThumbs
          :photos="review.photos.map((p) => ({ id: p.id, src: reviewPhotoPublicUrl(supabaseUrl, p.path) }))"
          :label="(n, total) => t('reviews.photos.view', { n, total, name: review.authorName })"
          class="mt-3"
          @open="(i) => openPublic(review, i)"
        />
      </li>
    </ul>
    <UiEmptyState
      v-else
      variant="board"
      class="mt-6"
      :hand-title="t('reviews.cleanBoard')"
      :title="t('reviews.empty')"
      :body="emptyHint ?? t('reviews.emptyHint')"
    >
      <template #action>
        <UiButton
          :to="flow.isSignedIn.value ? undefined : flow.signInLink.value"
          :icon="Pencil"
          data-review-opener
          @click="flow.onWrite"
        >
          {{ t('reviews.beFirst') }}
        </UiButton>
      </template>
    </UiEmptyState>
  </section>
</template>
