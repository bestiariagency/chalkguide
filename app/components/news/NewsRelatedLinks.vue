<script setup lang="ts">
import { ArrowRight } from 'lucide-vue-next'
import type { NewsRelated } from '~/types/news'

/** «En ChalkGuide» (README §18.9.6): up to 3 pages chosen by Xavi (gym, article, event...), as real `<a href>` boxes of 72 px, 2 columns from 640. */
defineProps<{ items: NewsRelated[] }>()
const { t } = useI18n()
</script>

<template>
  <section v-if="items.length" aria-labelledby="news-related-title">
    <h2 id="news-related-title" class="text-caption font-medium text-meta">{{ t('news.related.title') }}</h2>
    <ul class="mt-3 grid gap-2 sm:grid-cols-2 sm:gap-3">
      <li v-for="item in items" :key="`${item.kind}:${item.slug ?? item.label}`">
        <NuxtLinkLocale
          :to="newsRelatedTo(item.kind, item.slug)"
          class="group/rel relative flex min-h-18 flex-col justify-center rounded-md border border-line-strong py-3 pr-11 pl-4 transition-colors duration-150 hover:border-control hover:bg-board"
        >
          <span class="font-mono text-micro tracking-[.1em] text-meta uppercase">{{ t(`news.detail.relatedKind.${item.kind}`) }}</span>
          <span class="mt-0.5 text-[17px] leading-[1.3] font-medium text-balance">{{ item.label }}</span>
          <ArrowRight
            :size="18"
            aria-hidden="true"
            class="absolute top-1/2 right-4 -translate-y-1/2 text-meta transition-[translate,color] duration-150 group-hover/rel:translate-x-[3px] group-hover/rel:text-foreground motion-reduce:transition-none"
          />
        </NuxtLinkLocale>
      </li>
    </ul>
  </section>
</template>
