<script setup lang="ts">
import type { CategoryNavItem } from '~/types/domain'

/** Blog category chips (links, not filters): "Todo" + the pillars that have articles. */
defineProps<{ items: CategoryNavItem[]; total: number; current?: string | null }>()
const { t } = useI18n()

const chip =
  'inline-flex min-h-11 items-center gap-1.5 rounded-sm border px-[.85rem] text-body-sm font-medium transition-[background-color,border-color,color] duration-200 ease-standard'
const idle = 'border-control text-foreground hover:border-meta hover:bg-elevated'
const active = 'border-accent bg-accent-muted text-accent'
</script>

<template>
  <nav :aria-label="t('blog.categoriesLabel')" class="-mx-1 -my-1 overflow-x-auto px-1 py-1">
    <ul class="flex gap-2 whitespace-nowrap">
      <li>
        <NuxtLinkLocale
          :to="{ name: 'blog' }"
          :class="[chip, current ? idle : active]"
          :aria-current="current ? undefined : 'page'"
        >
          {{ t('blog.all') }}
          <span class="font-mono text-note" :class="current ? 'text-meta' : 'opacity-80'">
            {{ total }}
          </span>
        </NuxtLinkLocale>
      </li>
      <li v-for="item in items" :key="item.slug">
        <NuxtLinkLocale
          :to="{ name: 'blog-category-slug', params: { slug: item.slug } }"
          :class="[chip, item.slug === current ? active : idle]"
          :aria-current="item.slug === current ? 'page' : undefined"
        >
          {{ item.name }}
          <span
            class="font-mono text-note"
            :class="item.slug === current ? 'opacity-80' : 'text-meta'"
          >
            {{ item.count }}
          </span>
        </NuxtLinkLocale>
      </li>
    </ul>
  </nav>
</template>
