<script setup lang="ts">
import type { AuthorProfile } from '~/types/domain'

/**
 * Sobre mí head (§13.8): ink field, the author's sentence as the first-person H1 and the 4:5 photo
 * crossing the seam. Without a photo the H1 takes 10 columns; without a sentence, the page title.
 */
const props = defineProps<{ author: AuthorProfile | null; title: string }>()
const { t } = useI18n()
const photo = computed(() => props.author?.photo ?? null)
const heading = computed(() => props.author?.lede ?? props.title)
const byline = computed(() => [props.author?.name, props.author?.role].filter(Boolean).join(' · '))
</script>

<template>
  <header class="chrome-dark">
    <div class="mx-auto max-w-page px-4 pt-6 md:px-6 md:pt-10" :class="photo ? '' : 'pb-14 md:pb-16'">
      <UiBreadcrumbs :items="[{ label: t('nav.home'), to: '/' }, { label: t('nav.about') }]" />
      <div class="mt-6 grid items-end gap-x-6 gap-y-8 lg:grid-cols-12">
        <div :class="photo ? 'lg:col-span-7 lg:pb-16' : 'lg:col-span-10'">
          <h1 class="max-w-[26ch] text-balance text-about-title font-medium text-foreground">{{ heading }}</h1>
          <p v-if="byline" class="mt-6 text-lead text-meta md:text-body-lg">{{ byline }}</p>
        </div>
        <div v-if="photo" class="-mx-4 md:mx-0 lg:col-span-5 lg:translate-y-16">
          <UiPhoto
            :media="photo"
            priority
            sizes="xs:100vw sm:100vw md:480px"
            class="aspect-[4/5] max-h-[72svh] w-full md:rounded-slab lg:max-h-[600px]"
          />
        </div>
      </div>
    </div>
  </header>
</template>
