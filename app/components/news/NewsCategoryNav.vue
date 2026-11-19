<script setup lang="ts">
import type { NewsCategoryNavItem } from '~/types/news'

/** News category chips (links, not filters): "Todo" (no icon) + the categories that have news, with their icon (§18.14) and count. */
defineProps<{ items: NewsCategoryNavItem[]; total: number; current?: string | null }>()
const { t } = useI18n()

const chip =
  'group/chip inline-flex min-h-11 items-center gap-2 rounded-sm border px-[.85rem] text-body-sm font-medium transition-[background-color,border-color,color] duration-200 ease-standard'
const idle = 'border-control text-foreground hover:border-meta hover:bg-elevated'
const active = 'border-accent bg-accent-muted text-accent'
</script>

<template>
  <nav :aria-label="t('news.categoriesLabel')" class="-mx-1 -my-1 overflow-x-auto px-1 py-1">
    <ul class="flex gap-2 whitespace-nowrap">
      <li>
        <NuxtLinkLocale
          :to="{ name: 'news' }"
          :class="[chip, current ? idle : active]"
          :aria-current="current ? undefined : 'page'"
        >
          {{ t('news.all') }}
          <span class="font-mono text-note" :class="current ? 'text-meta' : 'opacity-80'">{{ total }}</span>
        </NuxtLinkLocale>
      </li>
      <li v-for="item in items" :key="item.slug">
        <NuxtLinkLocale
          :to="{ name: 'news-category-slug', params: { slug: item.slug } }"
          :class="[chip, item.slug === current ? active : idle]"
          :aria-current="item.slug === current ? 'page' : undefined"
        >
          <NewsCategoryIcon
            :slug="item.slug"
            class="transition-colors duration-200"
            :class="item.slug === current ? 'text-accent' : 'text-meta group-hover/chip:text-foreground'"
          />
          {{ item.name }}
          <span class="font-mono text-note" :class="item.slug === current ? 'opacity-80' : 'text-meta'">{{ item.count }}</span>
        </NuxtLinkLocale>
      </li>
    </ul>
  </nav>
</template>
