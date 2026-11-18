<script setup lang="ts">
import type { ArticleSummary } from '~/types/domain'

/** "Sigue leyendo": 3 articles with 4:3 photo, category and reading minutes (D48: no newsletter card here). */
defineProps<{ articles: ArticleSummary[] }>()
const { t } = useI18n()
</script>

<template>
  <section v-if="articles.length" class="border-t-[0.5px] border-line" aria-labelledby="keep-reading">
    <div class="mx-auto max-w-page px-4 py-12 md:px-6 md:py-16">
      <div class="flex items-end justify-between gap-4">
        <h2 id="keep-reading" class="text-title-2 font-medium">{{ t('blog.keepReading') }}</h2>
        <UiTextLink :to="{ name: 'blog' }" class="max-sm:hidden inline-flex min-h-11 items-center text-body-sm">{{ t('blog.allBlog') }}</UiTextLink>
      </div>
      <ul class="mt-6 grid gap-x-6 gap-y-8 md:grid-cols-3">
        <li v-for="(article, i) in articles" :key="article.id">
          <UiReveal :index="i" class="group/card relative flex flex-col gap-1 has-[a:focus-visible]:ring-focus">
            <UiPhoto
              :media="article.cover"
              sizes="xs:100vw sm:100vw md:33vw"
              class="mb-2 aspect-[4/3] w-full overflow-hidden rounded-slab"
            />
            <p v-if="article.category" class="text-caption font-medium text-meta">{{ article.category.name }}</p>
            <h3 class="text-title-4 leading-snug font-medium">
              <NuxtLinkLocale
                :to="{ name: 'blog-slug', params: { slug: article.slug } }"
                class="after:absolute after:inset-0 after:z-[1] focus-visible:shadow-none"
              >
                <span :class="cardTitleUnderline">{{ article.title }}</span>
              </NuxtLinkLocale>
            </h3>
            <p v-if="article.readingMinutes" class="font-mono text-note text-meta">{{ t('blog.readingTime', { count: article.readingMinutes }) }}</p>
          </UiReveal>
        </li>
      </ul>
    </div>
  </section>
</template>
