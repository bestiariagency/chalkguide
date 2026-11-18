<script setup lang="ts">
import type { BreadcrumbItem } from '~/types/ui'

/**
 * Month view of the agenda (`/agenda/aaaa-mm`). Invalid months (not aaaa-mm, month 13…) and months
 * outside ±12 months are rejected by `validate` → 404. Past months stay accessible. Indexing (§6): current/future months with >= 1 event only;
 * no cross-locale hreflang (each locale's month is its own page).
 */
definePageMeta({
  validate: (route) => {
    const month = parseMonthKey(String(route.params.month))
    return month !== null && isMonthInRange(month)
  },
})

const { t, locale } = useI18n()
const route = useRoute()
const month = computed(() => parseMonthKey(String(route.params.month)) ?? new Date())
const title = computed(() => formatMonthYear(month.value, locale.value))
const monthKey = computed(() => String(route.params.month))
const isPast = computed(() => addMonths(month.value, 1) <= startOfToday())
const isFuture = computed(() => month.value > startOfToday())
const nextMonth = computed(() => addMonths(month.value, 1))
const nextMonthTo = computed(() => ({ name: 'events-month' as const, params: { month: toMonthKey(nextMonth.value) } }))

const { data: events, error, refresh } = await useEventsOfMonth(month)

const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.events'), to: { name: 'events' } },
  { label: title.value },
])

// Past or empty months stay reachable but out of the index (README §6, same rule as the sitemap).
const seoText = useSeoText()
const hreflang = useState<{ path: string; locales: ('es' | 'en')[] } | null>('seo-hreflang', () => null)
hreflang.value = { path: route.path, locales: [locale.value === 'en' ? 'en' : 'es'] }
usePageSeo(() => ({
  title: t('events.monthSeoTitle', { month: title.value }),
  description: seoText('monthDescription', { month: title.value }),
  robots: isMonthIndexable(monthKey.value, events.value?.length ?? 0) ? undefined : ROBOTS_NOINDEX_FOLLOW,
}))
useBreadcrumbJsonLd(crumbs)
</script>

<template>
  <div>
    <section class="mx-auto max-w-page px-4 pt-8 md:px-6 md:pt-10">
      <UiBreadcrumbs :items="crumbs" />
      <h1 class="mt-5 title-section">
        {{ t('events.monthTitle', { month: title }) }}
      </h1>
      <p v-if="isPast && events?.length" class="mt-4 max-w-read text-body-lg text-meta">{{ t('events.archiveNote') }}</p>
    </section>

    <section class="mx-auto max-w-page px-4 py-8 md:px-6 md:py-10" :aria-label="title">
      <HomeSectionError v-if="error" :on-retry="() => refresh()" />
      <EventsAgendaBoards v-else-if="events?.length" :events="events" :highlight-next="!isPast" :archive="isPast" />
      <!-- One message per state (§13.7): never "ya ha pasado" next to "aún no hay". -->
      <div v-else class="max-w-read py-6">
        <p class="text-title-3 font-medium">
          {{ isPast ? t('events.nonePast', { month: title }) : isFuture ? t('events.noneFuture', { month: title }) : t('events.noneLeft') }}
        </p>
        <p v-if="isFuture" class="mt-2 text-body-lg text-meta">{{ t('events.noneFutureHint') }}</p>
        <UiTextLink v-else-if="!isPast" :to="nextMonthTo" class="mt-2 inline-flex min-h-11 items-center">
          {{ t('events.noneLeftNext', { month: formatMonthYear(nextMonth, locale) }) }}
        </UiTextLink>
      </div>
    </section>

    <section class="mx-auto max-w-page space-y-4 px-4 pb-16 md:px-6 md:pb-24">
      <p class="text-body-sm text-meta">{{ t('events.disclaimer') }}</p>
      <EventsMonthLinks :month="month" />
    </section>
  </div>
</template>
