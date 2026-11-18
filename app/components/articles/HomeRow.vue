<script setup lang="ts">
import type { ArticleSummary } from '~/types/domain'

/** Secondary article of the home: a readable row (thumbnail + category + title), not a photo card. */
const props = defineProps<{ article: ArticleSummary }>()
const to = computed(() => ({ name: 'blog-slug' as const, params: { slug: props.article.slug } }))
</script>

<template>
  <article class="group/card relative flex items-center gap-4 py-5 has-[a:focus-visible]:ring-focus">
    <UiPhoto
      :media="article.cover"
      sizes="128px"
      class="h-[78px] w-[104px] shrink-0 overflow-hidden rounded-xs md:h-24 md:w-32"
    />
    <div class="min-w-0">
      <p v-if="article.category" class="text-note font-medium text-meta">{{ article.category.name }}</p>
      <h3 class="mt-1 text-[18px] leading-[1.3] font-medium md:text-xl">
        <NuxtLinkLocale :to="to" class="after:absolute after:inset-0 focus-visible:shadow-none">
          <span :class="cardTitleUnderline">{{ article.title }}</span>
        </NuxtLinkLocale>
      </h3>
    </div>
  </article>
</template>
