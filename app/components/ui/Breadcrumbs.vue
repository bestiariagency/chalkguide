<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/** Breadcrumbs = URL (§6). The current page (last item) is not a link. */
defineProps<{ items: BreadcrumbItem[] }>()
const { t } = useI18n()
</script>

<template>
  <nav :aria-label="t('nav.breadcrumbs')">
    <ol
      class="flex flex-wrap items-center gap-x-2 gap-y-1 font-mono text-micro tracking-[.06em] text-meta uppercase"
    >
      <li v-for="(item, i) in items" :key="i" class="flex items-center gap-2">
        <span v-if="i > 0" class="text-hint" aria-hidden="true">/</span>
        <NuxtLinkLocale
          v-if="item.to && i < items.length - 1"
          :to="item.to"
          class="inline-flex min-h-8 items-center transition-colors duration-150 ease-standard hover:text-foreground"
        >
          {{ item.label }}
        </NuxtLinkLocale>
        <span v-else aria-current="page" class="text-foreground">{{ item.label }}</span>
      </li>
    </ol>
  </nav>
</template>
