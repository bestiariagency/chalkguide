<script setup lang="ts">
import type { NewsRelated } from '~/types/news'

/** "Relacionado" (spec SEO §13): up to 3 pages chosen by Xavi (gym, article or agenda), as real `<a href>` links. */
defineProps<{ items: NewsRelated[] }>()
const { t } = useI18n()
</script>

<template>
  <section v-if="items.length" aria-labelledby="news-related-title">
    <h2 id="news-related-title" class="text-caption font-medium text-meta">{{ t('news.detail.related') }}</h2>
    <ul class="mt-2 border-t border-foreground">
      <li v-for="item in items" :key="`${item.kind}:${item.slug ?? item.label}`" class="border-b border-line-strong">
        <NuxtLinkLocale
          :to="newsRelatedTo(item.kind, item.slug)"
          class="group/card flex min-h-11 flex-wrap items-baseline gap-x-3 gap-y-0.5 py-3"
        >
          <span class="font-mono text-micro tracking-[.06em] text-meta uppercase">{{ t(`news.detail.relatedKind.${item.kind}`) }}</span>
          <span class="text-[17px] font-medium"><span :class="cardTitleUnderline">{{ item.label }}</span></span>
        </NuxtLinkLocale>
      </li>
    </ul>
  </section>
</template>
