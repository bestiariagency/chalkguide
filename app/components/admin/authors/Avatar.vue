<script setup lang="ts">
import type { AdminMedia } from '~/utils/admin-media'
import { authorInitial } from '~/utils/admin-authors'

/** Round author photo (cropped to the top centre of the 4:5 photo) or, without photo, the initial on `subtle`. Decorative: the name is next to it. */
const props = withDefaults(defineProps<{ media: AdminMedia | null; name: string; size?: 'sm' | 'md' | 'lg' }>(), { size: 'sm' })
const mediaUrl = useMediaUrl()
const box = { sm: 'size-10 text-sm', md: 'size-12 text-base', lg: 'size-16 text-lg' }
const px = computed(() => ({ sm: 40, md: 48, lg: 64 })[props.size])
</script>

<template>
  <NuxtImg
    v-if="media"
    :src="mediaUrl(media.storage_path)"
    alt=""
    :width="px"
    :height="px"
    loading="lazy"
    :class="[box[size], 'flex-none rounded-full bg-adm-subtle object-cover object-top']"
    :style="{ backgroundColor: media.dominant_color ?? undefined }"
  />
  <span v-else :class="[box[size], 'grid flex-none place-items-center rounded-full bg-adm-subtle font-medium text-adm-meta']" aria-hidden="true">{{ authorInitial(name) }}</span>
</template>
