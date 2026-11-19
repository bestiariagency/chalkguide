<script setup lang="ts">
import { ExternalLink, LoaderCircle, Play } from 'lucide-vue-next'
import { YOUTUBE_ID } from '~/utils/article-embeds'

/**
 * Click-to-load facade (D26) for a video outside the article body (news, FV2). Same DOM as `renderVideoFacades()`
 * (`figure[data-video-facade]` + `[data-video-frame]`, button, no-JS link and hidden loading layer), so the one client
 * plugin builds the player when the reader clicks. No `<img>`, no remote asset (FV1/FV5). Everything is interpolated.
 * The ID is revalidated here too (FV3): an invalid one paints nothing. The caption goes in the default slot.
 */
const props = defineProps<{ id: string; title?: string | null; describedby: string }>()
const { t } = useI18n()
const valid = computed(() => YOUTUBE_ID.test(props.id))
const watchUrl = computed(() => youtubeWatchUrl(props.id))
const focus = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent'
</script>

<template>
  <figure v-if="valid" :data-video-facade="id" :data-video-title="title ?? undefined">
    <div data-video-frame class="relative aspect-video w-full rounded-lg">
      <button type="button" data-video-play :aria-describedby="describedby" :class="['group photo-placeholder absolute inset-0 rounded-lg', focus]">
        <span class="chrome-dark absolute inset-0 flex items-center justify-center bg-transparent">
          <span class="label-mini absolute top-4 left-4 md:top-5 md:left-5">{{ t('blog.video.kicker') }}</span>
          <span class="inline-flex min-h-12 items-center gap-2.5 rounded-md bg-accent-fill px-5 text-body-sm font-medium text-on-accent transition-[background-color,scale] duration-150 ease-standard group-hover:bg-accent-hover group-active:scale-[.98] motion-reduce:transition-none motion-reduce:group-active:scale-100">
            <Play :size="18" fill="currentColor" aria-hidden="true" />{{ t('blog.video.play') }}<span v-if="title" class="sr-only">: {{ title }}</span>
          </span>
        </span>
      </button>
      <a data-video-nojs :href="watchUrl" rel="noopener" :class="['photo-placeholder absolute inset-0 rounded-lg', focus]">
        <span class="chrome-dark absolute inset-0 flex items-center justify-center bg-transparent">
          <span class="label-mini absolute top-4 left-4 md:top-5 md:left-5">{{ t('blog.video.kicker') }}</span>
          <span class="inline-flex min-h-12 items-center gap-2 rounded-md border border-control px-5 text-body-sm font-medium text-foreground">
            {{ t('blog.video.watch') }}<ExternalLink :size="16" aria-hidden="true" /><span v-if="title" class="sr-only">: {{ title }}</span>
          </span>
        </span>
      </a>
      <!-- Loading layer: emitted hidden, the plugin only removes `hidden`. -->
      <span data-video-loading hidden class="chrome-dark absolute inset-0 flex flex-col items-center justify-center gap-3 bg-transparent">
        <LoaderCircle :size="28" class="animate-spin text-accent motion-reduce:animate-none" aria-hidden="true" />
        <span class="text-note text-meta">{{ t('blog.video.loading') }}</span>
      </span>
    </div>
    <slot />
  </figure>
</template>
