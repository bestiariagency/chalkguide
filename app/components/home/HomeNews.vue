<script setup lang="ts">
import type { NewsSummary } from '~/types/news'

/**
 * News block of the home (D77, option B, §15.4): own section between Blog and Newsletter on
 * `elevated`, same composition as "¿Por dónde empiezas?": title, lede and button on the left (4 columns),
 * text rows on the right (7). No cards or photos. The caller only renders it with >= 2 items.
 */
defineProps<{ news: NewsSummary[] }>()
const { t } = useI18n()
</script>

<template>
  <section id="news" data-nav-section="news" class="scroll-mt-20 bg-elevated" aria-labelledby="home-news-title">
    <div class="mx-auto max-w-page px-4 py-20 md:px-6 md:py-28 lg:py-[120px]">
      <div class="grid gap-x-8 gap-y-8 lg:grid-cols-12">
        <div class="lg:col-span-4">
          <h2 id="home-news-title" class="title-section">{{ t('nav.news') }}</h2>
          <p class="mt-4 max-w-[34ch] text-[17px] leading-[1.55] text-meta md:text-[18px]">{{ t('home.news.lede') }}</p>
          <UiButton variant="ghost" arrow :to="{ name: 'news' }" class="mt-6 max-lg:hidden">{{ t('home.news.seeAll') }}</UiButton>
        </div>
        <div class="lg:col-span-7 lg:col-start-6">
          <ul class="border-t border-foreground" :aria-label="t('home.news.list')">
            <li v-for="item in news" :key="item.id" class="border-b border-line-strong">
              <NewsRow :news="item" variant="home" />
            </li>
          </ul>
          <UiButton variant="ghost" :to="{ name: 'news' }" class="mt-6 w-full lg:hidden">{{ t('home.news.seeAll') }}</UiButton>
        </div>
      </div>
    </div>
  </section>
</template>
