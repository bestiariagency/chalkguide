<script setup lang="ts">
import { CircleAlert, Info, Plus } from 'lucide-vue-next'
import type { ReviewPhotosState } from '~/composables/useReviewPhotos'
import { REVIEW_PHOTO_MAX } from '~/utils/review-photos'

/**
 * Photos block of the review form (docs/design/site/README.md §11.2, with D31): up to 3, picked or
 * dragged, rights checkbox (unchecked by default) once there is something to upload, and the reason
 * of a rejected photo as a line of text. No notice about moderation (D31). The state lives in
 * `useReviewPhotos`; this component only draws it.
 */
const props = defineProps<{ photos: ReviewPhotosState; disabled: boolean; active: boolean }>()
const { t } = useI18n()

const input = ref<HTMLInputElement | null>(null)
const list = ref<HTMLElement | null>(null)
const rights = ref<{ focus: () => void } | null>(null)
const over = ref(false)
const dropActive = computed(() => over.value && !props.photos.full && !props.disabled)
const maxLabel = REVIEW_PHOTO_MAX

function onFiles(files: File[]) {
  if (!props.disabled && files.length) props.photos.add(files)
}
function onPick() {
  onFiles([...(input.value?.files ?? [])])
  if (input.value) input.value.value = ''
}

/** After removing, focus moves to the next X or to "Añadir" (keyboard users keep their place). */
async function remove(id: string, index: number) {
  props.photos.remove(id)
  await nextTick()
  const buttons = list.value?.querySelectorAll<HTMLElement>('[data-photo-remove]')
  const next = buttons?.[Math.min(index, (buttons?.length ?? 1) - 1)] ?? list.value?.querySelector<HTMLElement>('[data-photo-add]')
  next?.focus()
}
async function retry(id: string) {
  await props.photos.retryFailed()
  await nextTick()
  list.value?.querySelector<HTMLElement>(`[data-photo="${id}"] [data-photo-remove]`)?.focus()
}

watch(
  () => props.photos.rightsAttempts,
  async () => {
    await nextTick()
    rights.value?.focus()
  },
)

const addClass = computed(() => [
  'relative flex w-full flex-col items-center justify-center gap-1 rounded-md border bg-board text-center text-meta transition-[border-color,background-color,color] duration-150 ease-standard active:scale-[.98] disabled:opacity-50 motion-reduce:transition-none',
  dropActive.value ? 'border-[1.5px] border-accent bg-accent-muted text-accent' : 'border-dashed border-control hover:text-foreground',
])
</script>

<template>
  <fieldset class="mt-6 min-w-0" aria-describedby="review-photos-help">
    <ReviewsPhotosDrop v-if="active" @files="onFiles" @over="over = $event" />
    <legend class="float-left flex w-full items-baseline justify-between gap-3 text-body-sm">
      <span>{{ t('reviews.photos.legend') }}</span>
      <span class="font-mono text-caption text-meta" aria-hidden="true">{{ photos.count }} / {{ maxLabel }}</span>
    </legend>
    <p id="review-photos-help" class="clear-both pt-1 text-caption text-meta">{{ t('reviews.photos.help', { max: maxLabel }) }}</p>

    <div class="relative mt-3">
      <ul ref="list" class="grid grid-cols-3 gap-2" :aria-label="t('reviews.photos.listLabel')">
        <ReviewsPhotoTile
          v-for="(item, index) in photos.items"
          :key="item.id"
          :item="item"
          :index="index + 1"
          :disabled="disabled"
          @remove="remove($event, index)"
          @retry="retry(item.id)"
        />
        <li v-if="!photos.full" :class="photos.count === 0 && 'col-span-3'">
          <button
            type="button"
            data-photo-add
            :class="[addClass, photos.count === 0 ? 'min-h-14 flex-row gap-2 md:min-h-24 md:flex-col md:gap-1' : 'aspect-square']"
            :disabled="disabled"
            @click="input?.click()"
          >
            <Plus :size="20" aria-hidden="true" />
            <span class="text-body-sm font-medium">{{ t(photos.count === 0 ? 'reviews.photos.add' : 'reviews.photos.addOne') }}</span>
            <span class="hidden text-caption [@media(hover:hover)_and_(pointer:fine)]:block">
              {{ t(photos.count === 0 ? 'reviews.photos.dragHint' : 'reviews.photos.dragHintOne') }}
            </span>
          </button>
        </li>
      </ul>
      <div
        v-if="dropActive && photos.count > 0"
        class="pointer-events-none absolute inset-0 flex items-center justify-center rounded-md border-[1.5px] border-accent bg-accent-muted text-body-sm font-medium text-accent"
        aria-hidden="true"
      >
        {{ t('reviews.photos.dropMore', { n: maxLabel - photos.count }) }}
      </div>
    </div>
    <input
      ref="input"
      type="file"
      accept="image/*"
      multiple
      class="sr-only"
      tabindex="-1"
      aria-hidden="true"
      @change="onPick"
    />

    <p class="sr-only" role="status">{{ photos.announcement }}</p>
    <ul v-if="photos.messages.length" class="mt-3 space-y-2 text-body-sm" aria-live="polite">
      <li
        v-for="(message, index) in photos.messages"
        :key="index"
        class="flex items-start gap-2"
        :class="message.tone === 'error' ? 'text-danger-text' : 'text-meta'"
      >
        <component :is="message.tone === 'error' ? CircleAlert : Info" :size="16" class="mt-1 shrink-0" aria-hidden="true" />
        <span>{{ message.text }}</span>
      </li>
    </ul>
    <ul v-if="photos.rejected.length" class="mt-3 space-y-1 text-caption text-meta">
      <li v-for="photo in photos.rejected" :key="photo.id">
        {{ t(photo.reason ? 'reviews.photos.rejected' : 'reviews.photos.rejectedNoReason', { reason: photo.reason ? t(`reviews.photos.reject.${photo.reason}`) : '' }) }}
      </li>
    </ul>

    <UiCheckbox
      v-if="photos.hasNew"
      ref="rights"
      class="mt-3"
      :model-value="photos.rightsAccepted"
      :error="photos.rightsMissing ? t('reviews.photos.rightsRequired') : undefined"
      @update:model-value="photos.setRights"
    >
      {{ t('reviews.photos.rights') }}
    </UiCheckbox>
  </fieldset>
</template>
