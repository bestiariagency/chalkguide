<script setup lang="ts">
import type { EventMonth } from '~/utils/events'

/**
 * One month of the agenda (§13.7): H2 in display-date with the count on the right, "el siguiente"
 * (when it falls here; not repeated below) and the poster rows. `archive`: past month, grey photos.
 */
const props = defineProps<{ month: EventMonth; nextId?: string | null; archive?: boolean }>()
const { t, locale } = useI18n()
const titleId = useId()
const next = computed(() => props.month.events.find((event) => event.id === props.nextId) ?? null)
const rest = computed(() => props.month.events.filter((event) => event.id !== props.nextId))
</script>

<template>
  <section :aria-labelledby="titleId">
    <div class="flex items-baseline justify-between gap-4 border-b border-foreground pb-3">
      <h2 :id="titleId" class="display-date text-[32px] md:text-[44px]">{{ formatMonthName(month.date, locale) }}</h2>
      <p class="shrink-0 font-mono text-note whitespace-nowrap text-meta">{{ t('events.count', month.events.length) }}</p>
    </div>
    <div v-if="next" class="mt-6"><EventsEventNext :event="next" /></div>
    <ol v-if="rest.length" :class="next ? 'mt-2' : ''">
      <EventsEventRow v-for="event in rest" :key="event.id" :event="event" :archive="archive" />
    </ol>
  </section>
</template>
