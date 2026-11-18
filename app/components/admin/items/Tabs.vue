<script setup lang="ts">
import type { ItemTab } from '~/utils/item-tabs'

/**
 * Section tabs of the editor. Panels stay mounted (hidden) so nothing resets; each tab can carry an
 * error count, a violet dot (unpublished changes) and a number (gallery). Arrows, Home and End move.
 */
const props = defineProps<{ tabs: readonly ItemTab[]; errors: Record<string, number>; changed: Set<string>; gallery: number }>()
const tab = defineModel<string>({ required: true })

/** On small screens the tab bar scrolls sideways: keep the chosen tab in view. */
watch(tab, (key) => nextTick(() => document.getElementById(`item-tab-${key}`)?.scrollIntoView({ inline: 'nearest', block: 'nearest' })))

function move(event: KeyboardEvent, index: number) {
  const last = props.tabs.length - 1
  const target = event.key === 'ArrowRight' ? (index + 1) % props.tabs.length : event.key === 'ArrowLeft' ? (index + last) % props.tabs.length : event.key === 'Home' ? 0 : event.key === 'End' ? last : -1
  if (target < 0) return
  event.preventDefault()
  const next = props.tabs[target]!
  tab.value = next.key
  void nextTick(() => document.getElementById(`item-tab-${next.key}`)?.focus())
}
</script>

<template>
  <div class="sticky top-[104px] z-20 overflow-x-auto border-b border-adm-line bg-adm-bg px-4 md:top-12 md:px-6">
    <div role="tablist" aria-label="Secciones de la ficha" class="flex min-w-max gap-5">
      <button
        v-for="(item, index) in tabs"
        :id="`item-tab-${item.key}`"
        :key="item.key"
        type="button"
        role="tab"
        :aria-selected="tab === item.key"
        :aria-controls="`item-panel-${item.key}`"
        :tabindex="tab === item.key ? 0 : -1"
        :class="['relative inline-flex h-10 items-center gap-1.5 rounded text-[13px] whitespace-nowrap max-md:h-11', tab === item.key ? 'font-medium text-adm-fg after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-adm-acc' : 'text-adm-meta hover:text-adm-fg']"
        @click="tab = item.key"
        @keydown="move($event, index)"
      >
        <span v-if="props.changed.has(item.key)" class="size-1.5 rounded-full bg-adm-st-rev" aria-hidden="true" /><span v-if="props.changed.has(item.key)" class="sr-only">(con cambios) </span>
        {{ item.label }}
        <span v-if="item.key === 'gallery'" class="text-adm-muted tabular-nums">{{ gallery }}</span>
        <span v-if="errors[item.key]" class="inline-grid min-w-4 place-items-center rounded-full bg-adm-danger px-1 text-[11px] leading-4 font-semibold text-adm-on-danger" :aria-label="`${errors[item.key]} ${errors[item.key] === 1 ? 'error' : 'errores'}`">{{ errors[item.key] }}</span>
      </button>
    </div>
  </div>
</template>
