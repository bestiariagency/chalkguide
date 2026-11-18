<script setup lang="ts">
import { ChevronLeft, ChevronRight, X } from 'lucide-vue-next'

/**
 * Full-screen photo viewer (design §11.4): dark background, counter, arrows and keys, swipe over
 * 48 px, focus trapped and returned to the thumbnail (useSheetBehaviour), photo credit for transparency.
 */
const props = defineProps<{
  photos: readonly { id: string; src: string; width: number; height: number }[]
  author: string
  itemName: string
  dateLabel: string
  own?: boolean
}>()
const open = defineModel<boolean>('open', { required: true })
const index = defineModel<number>('index', { required: true })
const { t } = useI18n()

const panel = ref<HTMLElement | null>(null)
const titleId = useId()
useSheetBehaviour(open, panel)

const total = computed(() => props.photos.length)
const current = computed(() => props.photos[index.value])
const many = computed(() => total.value > 1)
const go = (delta: number) => {
  if (many.value) index.value = (index.value + delta + total.value) % total.value
}

function onKey(event: KeyboardEvent) {
  if (!open.value) return
  if (event.key === 'ArrowLeft') go(-1)
  else if (event.key === 'ArrowRight') go(1)
}
let startX = 0
const onTouchStart = (event: TouchEvent) => (startX = event.touches[0]?.clientX ?? 0)
function onTouchEnd(event: TouchEvent) {
  const delta = (event.changedTouches[0]?.clientX ?? startX) - startX
  if (Math.abs(delta) > 48) go(delta < 0 ? 1 : -1)
}
onMounted(() => window.addEventListener('keydown', onKey))
onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
</script>

<template>
  <div
    class="fixed inset-0 z-60 bg-[#0f0f0f] text-white transition-[opacity,visibility] duration-200 ease-standard motion-reduce:transition-none"
    :class="open ? 'visible opacity-100' : 'invisible opacity-0'"
    :aria-hidden="!open"
  >
    <div ref="panel" role="dialog" aria-modal="true" :aria-labelledby="titleId" class="flex h-full flex-col">
      <header class="flex h-16 flex-none items-center gap-3 px-4 md:px-6">
        <div class="min-w-0 flex-1">
          <h2 :id="titleId" class="truncate text-body-sm font-medium">{{ t(own ? 'reviews.photos.viewer.titleMine' : 'reviews.photos.viewer.title', { name: author }) }}</h2>
          <p class="truncate font-mono text-xs text-[#A19D94]">{{ dateLabel }} · {{ itemName }}</p>
        </div>
        <p v-if="many" class="font-mono text-xs text-[#A19D94]" aria-live="polite">{{ index + 1 }} / {{ total }}</p>
        <button type="button" class="grid size-11 place-items-center rounded-md text-white/80 hover:text-white" :aria-label="t('reviews.close')" @click="open = false">
          <X :size="22" aria-hidden="true" />
        </button>
      </header>
      <div class="relative flex min-h-0 flex-1 items-center justify-center px-4 md:px-20" @touchstart.passive="onTouchStart" @touchend.passive="onTouchEnd">
        <button v-if="many" type="button" class="absolute left-4 hidden size-11 place-items-center rounded-full bg-white/10 hover:bg-white/20 md:grid" :aria-label="t('reviews.photos.viewer.prev')" @click="go(-1)">
          <ChevronLeft :size="22" aria-hidden="true" />
        </button>
        <img
          v-if="current"
          :key="current.id"
          :src="current.src"
          :alt="t('reviews.photos.viewer.alt', { n: index + 1, total, name: own ? t('reviews.photos.viewer.you') : author, item: itemName })"
          :width="current.width || undefined"
          :height="current.height || undefined"
          class="max-h-[calc(100dvh-168px)] max-w-full object-contain transition-[opacity,transform] duration-200 ease-standard md:max-h-[calc(100dvh-140px)] motion-reduce:transition-none motion-reduce:transform-none"
          :class="open ? 'scale-100 opacity-100' : 'scale-98 opacity-0'"
        />
        <button v-if="many" type="button" class="absolute right-4 hidden size-11 place-items-center rounded-full bg-white/10 hover:bg-white/20 md:grid" :aria-label="t('reviews.photos.viewer.next')" @click="go(1)">
          <ChevronRight :size="22" aria-hidden="true" />
        </button>
      </div>
      <footer class="flex-none px-4 pb-3 text-center md:pb-6">
        <p class="text-caption text-[#A19D94]">{{ t(own ? 'reviews.photos.viewer.captionMine' : 'reviews.photos.viewer.caption', { name: author }) }}</p>
        <div v-if="many" class="mt-2 flex h-14 items-center justify-center gap-6 md:hidden">
          <button type="button" class="grid size-11 place-items-center rounded-full bg-white/10" :aria-label="t('reviews.photos.viewer.prev')" @click="go(-1)"><ChevronLeft :size="22" aria-hidden="true" /></button>
          <button type="button" class="grid size-11 place-items-center rounded-full bg-white/10" :aria-label="t('reviews.photos.viewer.next')" @click="go(1)"><ChevronRight :size="22" aria-hidden="true" /></button>
        </div>
      </footer>
    </div>
  </div>
</template>
