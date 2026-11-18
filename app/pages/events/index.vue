<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Agenda hub (F3.9): approved events of the next ~60 days as monthly chalkboards, with a type
 * filter. In English only events with an English version (D3). Past months stay reachable.
 */
const { t } = useI18n()
const { data: events, error, refresh } = await useUpcomingEvents(60)

const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.events') },
])

// The English agenda is indexable (and gets hreflang) with at least one English event in the window.
const robots = await useListingSeo('event', () => events.value?.length ?? 0)
usePageSeo(() => ({ title: t('events.seoTitle'), description: t('events.seoDescription'), robots }))
useBreadcrumbJsonLd(crumbs)
</script>

<template>
  <div>
    <section class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10">
      <UiBreadcrumbs :items="crumbs" />
      <h1 class="mt-5 title-section">{{ t('nav.events') }}</h1>
      <p class="mt-4 max-w-read text-body-lg text-meta">{{ t('events.intro') }}</p>
    </section>

    <section
      class="mx-auto max-w-page px-4 py-8 md:px-6 md:py-10"
      :aria-label="t('events.boardsLabel')"
    >
      <HomeSectionError v-if="error" :on-retry="() => refresh()" />
      <UiEmptyState
        v-else-if="!events?.length"
        variant="board"
        :hand-title="t('events.cleanBoard')"
        :title="t('events.emptyAgendaTitle')"
        :body="t('events.emptyAgendaBody')"
      />
      <EventsAgendaBoards v-else :events="events" highlight-next />
    </section>

    <section class="mx-auto max-w-page space-y-4 px-4 pb-16 md:px-6 md:pb-24">
      <p class="text-body-sm text-meta">{{ t('events.disclaimer') }}</p>
      <EventsMonthLinks :month="startOfToday()" hide-next />
    </section>
  </div>
</template>
