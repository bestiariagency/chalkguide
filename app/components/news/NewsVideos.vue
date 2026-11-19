<script setup lang="ts">
import { Shield } from 'lucide-vue-next'
import type { NewsVideo } from '~/types/news'

/**
 * «Vídeos relacionados» of the news page (D84/D88, F8.18 FV1–FV5): up to 2 YouTube videos below the summary, stacked, with
 * the click-to-load facade of D26. Nothing is asked from Google before the click: no thumbnail, no preconnect. Title,
 * channel and «Ver en YouTube» go as the credit of each video (third-party text, interpolated). Nothing is painted
 * without a valid video.
 */
const props = defineProps<{ videos: readonly NewsVideo[] }>()
const { t, locale } = useI18n()
const localePath = useLocalePath()
const { linkFor } = usePageLinks()
const uid = useId()
const list = computed(() => cleanNewsVideos(props.videos))
const many = computed(() => list.value.length > 1)
const language = (lang: string | null) => videoLanguageName(lang, locale.value)
const credit = (v: NewsVideo) => [v.channel, language(v.lang) ? t('news.detail.inLanguage', { language: language(v.lang) }) : null].filter((p): p is string => !!p)
</script>

<template>
  <section v-if="list.length" :aria-labelledby="`${uid}-title`" data-video-root>
    <h2 :id="`${uid}-title`" class="text-caption font-medium text-meta">{{ t(many ? 'news.detail.videos.titleMany' : 'news.detail.videos.titleOne') }}</h2>
    <p :id="`${uid}-note`" class="mt-2 flex gap-2 text-note text-meta">
      <Shield :size="14" class="mt-0.5 flex-none" aria-hidden="true" />
      <span>{{ t(many ? 'news.detail.videos.noticeMany' : 'news.detail.videos.noticeOne') }} <NuxtLink :to="localePath('cookies', linkFor('cookies').locale)" class="text-foreground underline underline-offset-2">{{ t('blog.video.cookies') }}</NuxtLink></span>
    </p>
    <ul class="mt-4 space-y-8">
      <li v-for="video in list" :key="video.youtubeId">
        <UiVideoFacade :id="video.youtubeId" :title="video.title" :describedby="`${uid}-note`">
          <figcaption class="mt-3">
            <p v-if="video.title" class="text-[17px] leading-[1.35] font-medium text-foreground [text-wrap:pretty]" :lang="video.lang && video.lang !== locale ? video.lang : undefined">{{ video.title }}</p>
            <p class="mt-1 text-body-sm text-meta">
              <template v-for="part in credit(video)" :key="part">{{ part }} · </template>
              <a :href="youtubeWatchUrl(video.youtubeId)" rel="noopener" class="text-foreground underline underline-offset-2">{{ t('blog.video.watch') }}<span class="sr-only"> {{ t('blog.video.external') }}</span></a>
            </p>
          </figcaption>
        </UiVideoFacade>
      </li>
    </ul>
  </section>
</template>
