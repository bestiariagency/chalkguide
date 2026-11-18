<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'
import type { MyReview, ReviewCriterion } from '~/services/reviews'
import type { ReviewPhotosState } from '~/composables/useReviewPhotos'

/**
 * Global score (required) + optional per-criterion scores + optional text. Only the global score
 * is validated; the parent does the sending.
 */
const props = defineProps<{
  criteria: ReviewCriterion[]
  initial: MyReview | null
  submitting: boolean
  failed: boolean
  rateLimited?: boolean
  photos: ReviewPhotosState
  /** A photo failed after the text was saved: offer retry or sending without it. */
  photoFailed: boolean
  /** The dialog is open (the drag-and-drop listener only exists then). */
  active: boolean
}>()
const emit = defineEmits<{
  submit: [overall: number, scores: Record<string, number>, body: string]
  cancel: []
  retryPhotos: []
  skipPhotos: []
}>()
const { t } = useI18n()

const MAX = 280
const overall = ref<number | null>(props.initial?.overall ?? null)
const scores = reactive<Record<string, number | null>>({})
const body = ref(props.initial?.body ?? '')
const overallMissing = ref(false)
const formEl = ref<HTMLFormElement | null>(null)

for (const criterion of props.criteria) scores[criterion.id] = props.initial?.scores[criterion.id] ?? null

watch(overall, (value) => {
  if (value !== null) overallMissing.value = false
})

function onSubmit() {
  if (props.submitting) return
  if (overall.value === null) {
    overallMissing.value = true
    formEl.value?.querySelector<HTMLInputElement>('input[name="score-overall"]')?.focus()
    return
  }
  if (!props.photos.requireRights()) return
  const given = Object.entries(scores).filter(
    (entry): entry is [string, number] => entry[1] !== null,
  )
  emit('submit', overall.value, Object.fromEntries(given), body.value)
}
</script>

<template>
  <form ref="formEl" novalidate @submit.prevent="onSubmit">
    <p
      v-if="failed"
      class="mb-5 flex items-start gap-2 rounded-md border border-danger-text/60 bg-danger-muted p-3 text-body-sm"
      role="alert"
    >
      <CircleAlert :size="20" class="mt-0.5 shrink-0 text-danger-text" aria-hidden="true" />
      {{ t(rateLimited ? 'reviews.rateLimited' : 'reviews.error') }}
    </p>
    <p v-if="initial" class="mb-5 text-caption text-meta">{{ t('reviews.editNote') }}</p>
    <ReviewsRating
      v-model="overall"
      name="score-overall"
      :label="t('reviews.overall')"
      :invalid="overallMissing"
      prominent
    />
    <p v-if="overallMissing" class="mt-2 flex items-center gap-1.5 text-body-sm text-danger-text" role="alert">
      <CircleAlert :size="16" aria-hidden="true" />{{ t('reviews.overallRequired') }}
    </p>
    <div v-if="criteria.length" class="mt-6 border-t-[0.5px] border-line pt-5">
      <p class="label-mini">{{ t('reviews.criteriaTitle') }}</p>
      <p class="mt-1 text-caption text-meta">{{ t('reviews.criteriaHint') }}</p>
      <div class="mt-4 space-y-5">
        <ReviewsRating
          v-for="criterion in criteria"
          :key="criterion.id"
          v-model="scores[criterion.id]"
          :name="`score-${criterion.id}`"
          :label="criterion.name"
          :help="criterion.help"
          clearable
        />
      </div>
    </div>
    <UiTextarea
      v-model="body"
      class="mt-6"
      :label="t('reviews.optionalText')"
      :placeholder="t('reviews.placeholder')"
      :maxlength="MAX"
    />
    <ReviewsPhotos :photos="photos" :disabled="submitting" :active="active" />
    <div
      v-if="photoFailed"
      class="mt-6 rounded-md border border-danger-text/60 bg-danger-muted p-3 text-body-sm"
      role="alert"
    >
      <p class="flex items-start gap-2">
        <CircleAlert :size="20" class="mt-0.5 shrink-0 text-danger-text" aria-hidden="true" />
        {{ t('reviews.photos.submitError') }}
      </p>
      <div class="mt-3 flex flex-wrap gap-2 pl-7">
        <UiButton variant="ghost" :loading="submitting" @click="emit('retryPhotos')">{{ t('reviews.photos.retry') }}</UiButton>
        <UiButton variant="ghost" :disabled="submitting" @click="emit('skipPhotos')">{{ t('reviews.photos.sendWithout') }}</UiButton>
      </div>
    </div>
    <div class="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
      <UiButton variant="ghost" @click="emit('cancel')">{{ t('reviews.cancel') }}</UiButton>
      <UiButton type="submit" :loading="submitting">
        {{ initial ? t('reviews.save') : t('reviews.submit') }}
      </UiButton>
    </div>
    <p v-if="submitting && photos.uploading" class="mt-3 text-caption text-meta sm:text-right" aria-live="polite">
      {{ t('reviews.photos.finishing', { count: photos.uploading }, photos.uploading) }}
    </p>
    <p class="mt-4 text-note text-meta">{{ t('reviews.publicName') }}</p>
  </form>
</template>
