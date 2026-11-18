<script setup lang="ts">
import type { MediaRef } from '~/types/domain'

/**
 * Cover image from the media bucket, or the design-system placeholder when there is none.
 * `eager`: first viewport (no lazy). `priority`: the LCP image (fetchpriority high); implies eager.
 * `sizes` use nuxt-image keys (`xs:104px md:200px`); a bare `100vw` token yields a 1w srcset.
 */
const props = withDefaults(
  defineProps<{ media: MediaRef | null; sizes?: string; eager?: boolean; priority?: boolean }>(),
  { sizes: '100vw md:66vw', eager: false, priority: false },
)
const mediaUrl = useMediaUrl()
const src = computed(() => (props.media ? mediaUrl(props.media.path) : null))

// The LCP image is discovered from the SSR head instead of after the body is parsed.
useImagePreload(() => ({
  src: props.priority ? src.value : null,
  width: props.media?.width,
  height: props.media?.height,
  sizes: props.sizes,
}))
</script>

<template>
  <div class="photo-placeholder">
    <NuxtImg
      v-if="src && media"
      :src="src"
      :alt="media.alt ?? ''"
      :width="media.width ?? undefined"
      :height="media.height ?? undefined"
      :sizes="sizes"
      :loading="eager || priority ? 'eager' : 'lazy'"
      :fetchpriority="priority ? 'high' : undefined"
      class="absolute inset-0 size-full object-cover"
    />
  </div>
</template>
