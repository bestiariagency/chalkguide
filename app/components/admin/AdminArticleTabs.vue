<script setup lang="ts">
import { ARTICLE_VIEWS, type ArticleView } from '~/utils/admin-articles'

/** Saved views of the articles list (tabs with counts). Left/Right arrows move between them. */
defineProps<{ counts: Record<ArticleView, number> }>()
const view = defineModel<ArticleView>({ required: true })

function move(event: KeyboardEvent, index: number) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
  if (!step) return
  event.preventDefault()
  const next = ARTICLE_VIEWS[(index + step + ARTICLE_VIEWS.length) % ARTICLE_VIEWS.length]
  if (!next) return
  view.value = next.value
  void nextTick(() => document.getElementById(`art-tab-${next.value}`)?.focus())
}
</script>

<template>
  <div class="overflow-x-auto border-b border-adm-line px-4 md:px-6">
    <div role="tablist" aria-label="Vistas" class="flex min-w-max gap-5">
      <button
        v-for="(tab, index) in ARTICLE_VIEWS"
        :id="`art-tab-${tab.value}`"
        :key="tab.value"
        type="button"
        role="tab"
        :aria-selected="view === tab.value"
        :tabindex="view === tab.value ? 0 : -1"
        :class="[
          'relative inline-flex h-10 items-center gap-1.5 rounded text-[13px] max-md:h-11',
          view === tab.value ? 'font-medium text-adm-fg after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-adm-acc' : 'text-adm-meta hover:text-adm-fg',
        ]"
        @click="view = tab.value"
        @keydown="move($event, index)"
      >
        <span v-if="tab.value === 'changes'" class="size-1.5 rounded-full bg-adm-st-rev" aria-hidden="true" />
        {{ tab.label }}
        <span class="text-adm-muted tabular-nums">{{ counts[tab.value] }}</span>
      </button>
    </div>
  </div>
</template>
