<script setup lang="ts">
import type { MediaRef } from '~/types/domain'

/** Main photo 4:3 + thumbnails; the thumbnails are buttons (aria-current marks the shown one). */
const props = defineProps<{ cover: MediaRef | null; gallery: MediaRef[]; name: string; brand?: string; model?: string }>()
const { t } = useI18n()

const photos = computed(() => {
  const seen = new Set<string>()
  return [props.cover, ...props.gallery]
    .filter((media): media is MediaRef => !!media)
    .filter((media) => !seen.has(media.path) && !!seen.add(media.path))
    .slice(0, 5)
})
const current = ref(0)
const shown = computed(() => photos.value[current.value] ?? null)
</script>

<template>
  <div>
    <UiPhoto
      v-if="shown"
      :media="shown"
      eager
      sizes="100vw lg:50vw"
      class="aspect-[4/3] rounded-xl md:aspect-[16/9] lg:aspect-[4/3]"
    />
    <!-- No photo: the name is the poster, as in the listing. -->
    <ShoesPhotoTile
      v-else
      :media="null"
      :brand="brand"
      :model="model || name"
      class="aspect-[4/3] w-full md:aspect-[16/9] lg:aspect-[4/3]"
    />
    <ul
      v-if="photos.length > 1"
      class="mt-3 grid grid-cols-4 gap-2 sm:grid-cols-[repeat(4,88px)] lg:grid-cols-4"
      :aria-label="t('shoes.detail.photos')"
    >
      <li v-for="(media, index) in photos" :key="media.path">
        <button
          type="button"
          class="block w-full overflow-hidden rounded-md border-2 border-transparent aria-[current=true]:border-accent-fill"
          :aria-current="index === current"
          :aria-label="t('shoes.detail.photoOf', { n: index + 1, total: photos.length, name: media.alt || name })"
          @click="current = index"
        >
          <UiPhoto :media="media" sizes="88px" class="aspect-square" />
        </button>
      </li>
    </ul>
  </div>
</template>
