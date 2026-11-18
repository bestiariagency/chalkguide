<script setup lang="ts">
import type { MediaRef } from '~/types/domain'

/** Round author photo (signature). Decorative: the name sits next to it, so the alt is empty. */
const props = defineProps<{ media: MediaRef; size: 32 | 48 | 96 }>()
const mediaUrl = useMediaUrl()
</script>

<template>
  <NuxtImg
    :src="mediaUrl(props.media.path)"
    alt=""
    :width="size"
    :height="size"
    :sizes="`${size}px`"
    loading="lazy"
    class="shrink-0 rounded-full object-cover object-[50%_30%]"
    :class="size === 32 ? 'size-8' : size === 48 ? 'size-12' : 'size-24'"
  />
</template>
