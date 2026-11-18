<script setup lang="ts">
import { Pencil, Trash2 } from 'lucide-vue-next'
import type { MyReview, ReviewCriterion } from '~/services/reviews'

/** "Tu opinión": own review with edit and delete (inline confirmation, no window.confirm). */
const props = defineProps<{
  review: MyReview
  criteria: ReviewCriterion[]
  deleting: boolean
  /** Own photos to show (no moderation state: D31). */
  photos: readonly { id: string; src: string }[]
}>()
const emit = defineEmits<{ edit: []; remove: []; openPhoto: [index: number, event: Event] }>()
const { t, locale } = useI18n()

/** Criteria the user did score, in display order. */
const scored = computed(() =>
  props.criteria.flatMap((c) => {
    const score = props.review.scores[c.id]
    return score === undefined ? [] : [{ id: c.id, name: c.name, score }]
  }),
)

const confirming = ref(false)
const askBtn = ref<{ $el: HTMLElement } | null>(null)

async function ask() {
  confirming.value = true
  await nextTick()
  const el = document.querySelector<HTMLElement>('#my-review-confirm button')
  el?.focus()
}
async function cancel() {
  confirming.value = false
  await nextTick()
  askBtn.value?.$el.focus()
}
</script>

<template>
  <section
    class="rounded-lg border-[0.5px] border-accent bg-board p-5"
    aria-labelledby="my-review-title"
  >
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div>
        <h3 id="my-review-title" class="text-body font-medium">{{ t('reviews.yourReview') }}</h3>
        <p class="font-mono text-xs text-meta">
          {{ formatDate(review.createdAt, locale, { day: '2-digit', month: '2-digit', year: '2-digit' }) }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <UiBadge v-if="review.status === 'hidden'">{{ t('reviews.status.hidden') }}</UiBadge>
        <ItemsScore :score="review.overall" highlight whole />
      </div>
    </div>
    <ul v-if="scored.length" class="mt-3 flex flex-wrap gap-x-4 gap-y-1 text-caption tabular-nums">
      <li v-for="item in scored" :key="item.id">
        <span class="text-meta">{{ item.name }}</span>
        <span class="ml-1.5 font-mono">{{ formatScore(item.score, locale, 0) }}</span>
      </li>
    </ul>
    <p v-if="review.body" class="mt-3 text-body-sm leading-[1.6] text-prose">{{ review.body }}</p>

    <ReviewsThumbs
      v-if="photos.length"
      class="mt-3"
      plain
      :photos="photos"
      :label="(n, total) => t('reviews.photos.viewMine', { n, total })"
      @open="(i, e) => emit('openPhoto', i, e)"
    />

    <div v-if="!confirming" class="mt-4 flex flex-wrap gap-2">
      <UiButton variant="ghost" :icon="Pencil" @click="emit('edit')">{{ t('reviews.edit') }}</UiButton>
      <UiButton ref="askBtn" variant="ghost" :icon="Trash2" @click="ask">
        {{ t('reviews.delete') }}
      </UiButton>
    </div>
    <div
      v-else
      id="my-review-confirm"
      class="mt-4 rounded-md border border-danger-text/60 bg-danger-muted p-4"
      role="group"
      :aria-label="t('reviews.deleteConfirmTitle')"
    >
      <p class="text-body-sm font-medium">{{ t('reviews.deleteConfirmTitle') }}</p>
      <p class="mt-1 text-caption text-meta">{{ t('reviews.deleteConfirmBody') }}</p>
      <div class="mt-3 flex flex-wrap gap-2">
        <UiButton variant="ghost" :loading="deleting" @click="emit('remove')">
          {{ t('reviews.deleteConfirm') }}
        </UiButton>
        <UiButton variant="ghost" :disabled="deleting" @click="cancel">
          {{ t('reviews.cancel') }}
        </UiButton>
      </div>
    </div>
  </section>
</template>
