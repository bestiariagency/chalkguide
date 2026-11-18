<script setup lang="ts">
import { CircleAlert, X } from 'lucide-vue-next'
import type { PhotoItem } from '~/composables/useReviewPhotos'

/** One photo of the form: preparing, uploading (real progress), failed (retry) or saved. */
const props = defineProps<{ item: PhotoItem; index: number; disabled: boolean }>()
const emit = defineEmits<{ remove: [id: string]; retry: [] }>()
const { t } = useI18n()

const label = computed(() => (props.item.name ? `${props.index}, ${props.item.name}` : String(props.index)))
const stateText = computed(() => {
  const { state, progress } = props.item
  return t(`reviews.photos.state.${state}`, { percent: progress })
})
</script>

<template>
  <li
    class="relative aspect-square overflow-hidden rounded-md bg-elevated"
    :class="item.state === 'error' && 'bg-danger-muted'"
    :data-photo="item.id"
  >
    <span class="sr-only">{{ t('reviews.photos.tileState', { label, state: stateText }) }}</span>
    <img
      :src="item.src"
      alt=""
      width="176"
      height="176"
      class="block size-full object-cover transition-[opacity,filter] duration-200 ease-standard motion-reduce:transition-none"
      :class="{ 'opacity-45 blur-[2px]': item.state === 'preparing', 'opacity-75': item.state === 'uploading', 'opacity-25': item.state === 'error' }"
    />
    <span
      class="pointer-events-none absolute inset-0 rounded-md"
      :class="item.state === 'error' ? 'shadow-[inset_0_0_0_1px_var(--color-danger-text)]' : 'shadow-[inset_0_0_0_0.5px_rgb(0_0_0/0.12)]'"
      aria-hidden="true"
    />

    <div v-if="item.state === 'preparing'" class="absolute inset-0 grid place-items-center" aria-hidden="true">
      <div class="flex flex-col items-center gap-1.5">
        <span class="size-5 animate-spin rounded-full border-2 border-foreground border-r-transparent motion-reduce:animate-none motion-reduce:border-r-foreground motion-reduce:opacity-60" />
        <span class="text-xs font-medium">{{ t('reviews.photos.state.preparing') }}</span>
      </div>
    </div>

    <div v-if="item.state === 'uploading'" class="absolute inset-x-0 bottom-0 bg-linear-to-b from-transparent to-[rgb(28_26_23/0.6)] p-1.5">
      <span class="block font-mono text-xs leading-none text-white" aria-hidden="true">{{ item.progress }} %</span>
      <div
        class="mt-1.5 h-1 overflow-hidden rounded-full bg-white/35"
        role="progressbar"
        :aria-label="t('reviews.photos.uploadingLabel', { n: index })"
        aria-valuemin="0"
        aria-valuemax="100"
        :aria-valuenow="item.progress"
      >
        <span class="block h-full rounded-full bg-accent-fill transition-[width] duration-200 ease-linear motion-reduce:transition-none" :style="{ width: `${item.progress}%` }" />
      </div>
    </div>

    <div v-if="item.state === 'error'" class="absolute inset-0 flex flex-col items-center justify-center gap-0.5 text-danger-text">
      <CircleAlert :size="20" aria-hidden="true" />
      <button
        type="button"
        class="min-h-11 rounded-md px-2 text-body-sm font-medium underline underline-offset-4"
        :aria-label="t('reviews.photos.retryFailed')"
        :disabled="disabled"
        @click="emit('retry')"
      >
        {{ t('reviews.photos.retry') }}
      </button>
    </div>

    <button
      type="button"
      data-photo-remove
      class="group/x absolute top-0 right-0 grid size-11 place-items-center rounded-md focus-visible:shadow-none disabled:opacity-50"
      :aria-label="t(item.name ? 'reviews.photos.removeNamed' : 'reviews.photos.remove', { n: index, name: item.name })"
      :disabled="disabled"
      @click="emit('remove', item.id)"
    >
      <span class="grid size-7 place-items-center rounded-full bg-[rgb(28_26_23/0.78)] text-white transition-[background-color,transform] duration-120 ease-standard group-hover/x:bg-[rgb(28_26_23/0.95)] group-active/x:scale-90 group-focus-visible/x:ring-focus motion-reduce:transition-none">
        <X :size="16" aria-hidden="true" />
      </span>
    </button>
  </li>
</template>
