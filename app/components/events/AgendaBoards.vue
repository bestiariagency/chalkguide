<script setup lang="ts">
import type { GuideEvent } from '~/types/domain'

/**
 * Agenda body (editorial v2): type filter + months stacked, each with poster rows. The next
 * upcoming event (if any) gets its own slab in its month. Used by the hub (~60 days) and the month
 * view; `archive` (past month) shows the same rows without "el siguiente" and with grey photos.
 */
const props = defineProps<{ events: GuideEvent[]; highlightNext?: boolean; archive?: boolean }>()
const { t } = useI18n()
const { types, filtered, isSelected, toggle, clear, hasFilter } = useEventTypeFilter(
  () => props.events,
)
const months = computed(() => groupEventsByMonth(filtered.value))
const nextId = computed(() => {
  const now = Date.now()
  return props.highlightNext && !props.archive
    ? (filtered.value.find((event) => !event.cancelled && new Date(event.startsAt).getTime() >= now)?.id ?? null)
    : null
})
</script>

<template>
  <div>
    <div v-if="types.length > 1">
      <div
        class="flex flex-wrap gap-2"
        role="group"
        :aria-label="t('events.filterLabel')"
      >
        <UiChip
          v-for="type in types"
          :key="type"
          :pressed="isSelected(type)"
          @update:pressed="toggle(type, $event)"
        >
          {{ t(`events.types.${type}`) }}
        </UiChip>
      </div>
      <p v-if="hasFilter" class="mt-4 text-body-sm text-meta" aria-live="polite">
        {{ t('events.count', filtered.length) }}
      </p>
    </div>

    <div v-if="months.length" class="mt-8 space-y-14 md:space-y-16">
      <UiReveal v-for="(month, i) in months" :key="month.key" :index="i">
        <EventsEventMonth :month="month" :next-id="nextId" :archive="archive" />
      </UiReveal>
    </div>
    <UiEmptyState
      v-else
      variant="board"
      class="mt-8"
      :hand-title="t('events.cleanBoard')"
      :title="t('states.noResultsTitle')"
      :body="t('states.noResultsBody')"
    >
      <template v-if="hasFilter" #action>
        <UiButton variant="ghost" @click="clear">{{ t('common.clearFilters') }}</UiButton>
      </template>
    </UiEmptyState>
  </div>
</template>
