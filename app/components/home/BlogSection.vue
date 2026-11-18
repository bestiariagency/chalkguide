<script setup lang="ts">
import type { ArticleSummary } from '~/types/domain'

/**
 * Blog of the home (D44), mirror of "¿Por dónde empiezas?": the main article on the left at full
 * height, the title and up to two rows on the right. With 2 articles: main + one row; with 1: main.
 */
const props = defineProps<{ articles: ArticleSummary[] }>()
const { t } = useI18n()
const main = computed(() => props.articles[0])
const rows = computed(() => props.articles.slice(1, 3))
</script>

<template>
  <section
    v-if="main"
    id="blog"
    data-nav-section="blog"
    class="scroll-mt-20 bg-background"
    aria-labelledby="home-blog-title"
  >
    <div class="mx-auto max-w-page px-4 py-20 md:px-6 md:py-28 lg:py-[120px]">
      <div class="grid gap-x-8 gap-y-8 lg:grid-cols-12">
        <h2 id="home-blog-title" class="title-section lg:col-span-5 lg:col-start-8 lg:row-start-1">
          {{ t('home.blog.title') }}
        </h2>
        <ArticlesOverlayCard
          :article="main"
          flat
          class="aspect-4/3 lg:col-span-7 lg:col-start-1 lg:row-span-2 lg:row-start-1 lg:aspect-auto lg:min-h-[560px]"
          sizes="100vw lg:58vw"
        />
        <div class="flex flex-col lg:col-span-5 lg:col-start-8 lg:row-start-2">
          <ul v-if="rows.length" class="border-t border-foreground">
            <li v-for="article in rows" :key="article.id" class="border-b border-line-strong">
              <ArticlesHomeRow :article="article" />
            </li>
          </ul>
          <UiButton variant="ghost" arrow :to="{ name: 'blog' }" class="mt-6 self-start">
            {{ t('home.blog.seeAll') }}
          </UiButton>
        </div>
      </div>
    </div>
  </section>
</template>
