<script setup lang="ts">
import { LayoutGrid, List } from 'lucide-vue-next'

/**
 * Grid/list switch (README §18.5b): two 44 px buttons with `aria-pressed`, icon + `sr-only` text. The pressed look comes from
 * the attribute of <html> (CSS), so it does not flicker; hidden without JS (`html:not(.js)`), because it would do nothing.
 */
const { t } = useI18n()
const { view, setView } = useNewsView()
const base =
  'grid size-11 place-items-center rounded-[7px] text-meta transition-colors duration-150 hover:bg-elevated hover:text-foreground focus-visible:relative focus-visible:z-[1]'
</script>

<template>
  <div
    class="inline-flex flex-none rounded-md border border-control p-px [html:not(.js)_&]:hidden"
    role="group"
    :aria-label="t('news.view.label')"
  >
    <button
      type="button"
      data-view="grid"
      :aria-pressed="view === 'grid'"
      aria-controls="news-list"
      :class="[base, 'news-grid:bg-foreground news-grid:text-background news-grid:hover:bg-foreground news-grid:hover:text-background']"
      @click="setView('grid')"
    >
      <LayoutGrid :size="20" aria-hidden="true" />
      <span class="sr-only">{{ t('news.view.grid') }}</span>
    </button>
    <button
      type="button"
      data-view="list"
      :aria-pressed="view === 'list'"
      aria-controls="news-list"
      :class="[base, 'news-list:bg-foreground news-list:text-background news-list:hover:bg-foreground news-list:hover:text-background']"
      @click="setView('list')"
    >
      <List :size="20" aria-hidden="true" />
      <span class="sr-only">{{ t('news.view.list') }}</span>
    </button>
  </div>
</template>
