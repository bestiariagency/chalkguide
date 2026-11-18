<script setup lang="ts">
import type { MediaRef } from '~/types/domain'

/**
 * Product tile on a paper-tone tray: the whole shoe is shown (object-contain) and the white photo
 * background melts into the tray (mix-blend-multiply). Without a cover, the model name is the
 * poster (Archivo Expanded, one word per line, like the hero's "7 NOV"); under 120 px wide the
 * brand disappears and a wide name becomes initials.
 * Decorative: the surrounding link carries the name. Parent needs `group/card` for the hover.
 */
const props = withDefaults(
  defineProps<{
    media: MediaRef | null
    brand?: string
    model?: string
    sizes?: string
    eager?: boolean
    /** Poster text at the top (the home plaque, where nothing sits above it). */
    top?: boolean
  }>(),
  { sizes: '160px lg:300px', brand: '', model: '' },
)
const mediaUrl = useMediaUrl()
const src = computed(() => (props.media ? mediaUrl(props.media.path) : null))
const poster = computed(() => posterLayout(props.model || props.brand))
</script>

<template>
  <span
    class="relative block overflow-hidden rounded-slab bg-tray-paper text-ink transition-colors duration-200 ease-standard [container-type:size] group-hover/card:bg-tray-paper-hover"
    aria-hidden="true"
  >
    <NuxtImg
      v-if="src && media"
      :src="src"
      alt=""
      :width="media.width ?? undefined"
      :height="media.height ?? undefined"
      :sizes="sizes"
      :loading="eager ? 'eager' : 'lazy'"
      class="absolute inset-0 size-full object-contain p-2 mix-blend-multiply motion-safe:transition-transform motion-safe:duration-600 motion-safe:ease-out motion-safe:group-hover/card:scale-[1.04] md:p-3"
    />
    <span
      v-else
      class="absolute inset-x-[5.5cqw]"
      :class="top ? 'top-[6cqw]' : 'bottom-[5cqw]'"
      :style="{ '--n': poster.n, '--l': poster.lines.length }"
    >
      <span
        v-if="brand"
        class="mb-[.5em] block text-[clamp(12px,4.4cqw,14px)] leading-tight font-medium text-meta-ink @max-[119px]:hidden"
      >
        {{ brand }}
      </span>
      <span
        class="block origin-bottom-left font-display text-[min(31cqw,calc(89cqw/var(--n)),calc(58cqh/var(--l)))] leading-[.92] font-bold font-stretch-expanded tracking-[-0.03em] uppercase motion-safe:transition-transform motion-safe:duration-600 motion-safe:ease-out motion-safe:group-hover/card:scale-[1.02]"
        :class="poster.long && '@max-[119px]:hidden'"
      >
        <span v-for="line in poster.lines" :key="line" class="block whitespace-nowrap">{{ line }}</span>
      </span>
      <span
        v-if="poster.long"
        class="hidden font-display text-[44cqw] leading-[.9] font-bold font-stretch-expanded tracking-[-0.03em] uppercase @max-[119px]:block"
      >
        {{ poster.mono }}
      </span>
    </span>
  </span>
</template>
