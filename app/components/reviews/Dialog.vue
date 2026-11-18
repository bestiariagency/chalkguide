<script setup lang="ts">
import { Pencil } from 'lucide-vue-next'
import type { MyReview, ReviewCriterion } from '~/services/reviews'
import type { ReviewStep } from '~/composables/useUserReview'
import type { ReviewPhotosState } from '~/composables/useReviewPhotos'

/**
 * Review dialog (mockup opinar.html): bottom sheet on mobile, centred modal from md.
 * Same focus management as the mobile menu (trap, Esc, focus return, scroll lock).
 */
const props = defineProps<{
  itemName: string
  criteria: ReviewCriterion[]
  mine: MyReview | null
  step: ReviewStep
  submitting: boolean
  failed: boolean
  rateLimited?: boolean
  photos: ReviewPhotosState
  photoFailed: boolean
}>()
const open = defineModel<boolean>('open', { required: true })
const emit = defineEmits<{
  submit: [overall: number, scores: Record<string, number>, body: string]
  edit: []
  retryPhotos: []
  skipPhotos: []
}>()
const { t } = useI18n()

const sentEl = ref<HTMLElement | null>(null)
watch(
  () => props.step,
  async (step) => {
    if (step !== 'sent') return
    await nextTick()
    sentEl.value?.focus()
  },
)
</script>

<template>
  <UiSheet
    v-model:open="open"
    :title="t('reviews.yourReview')"
    :eyebrow="itemName"
    :close-label="t('reviews.close')"
    return-focus-to="[data-review-opener]"
    padding-class="p-6 md:p-8"
  >
    <template #default="{ close }">
      <div
        v-if="step === 'sent'"
        ref="sentEl"
        tabindex="-1"
        role="status"
        class="py-4 text-center focus-visible:shadow-none"
      >
        <UiSuccessCheck class="mx-auto" />
        <p class="mt-3 text-xl font-medium">{{ t('reviews.sent') }}</p>
        <p class="mt-1 text-body-sm text-meta">{{ t('reviews.sentHint') }}</p>
        <div class="mt-6 flex flex-col justify-center gap-3 sm:flex-row">
          <UiButton variant="ghost" :icon="Pencil" @click="emit('edit')">{{ t('reviews.edit') }}</UiButton>
          <UiButton @click="close">{{ t('reviews.close') }}</UiButton>
        </div>
      </div>
      <ReviewsForm
        v-else
        :key="`${mine?.id ?? 'new'}-${mine?.editedAt ?? ''}-${criteria.length}-${open}`"
        :criteria="criteria"
        :initial="mine"
        :submitting="submitting"
        :failed="failed"
        :rate-limited="rateLimited"
        :photos="photos"
        :photo-failed="photoFailed"
        :active="open"
        @submit="(overall, scores, body) => emit('submit', overall, scores, body)"
        @retry-photos="emit('retryPhotos')"
        @skip-photos="emit('skipPhotos')"
        @cancel="close"
      />
    </template>
  </UiSheet>
</template>
