<script setup lang="ts">
/**
 * Previous/next month links (README §6: past months stay reachable; no links beyond +3 months).
 * `month` is the month on screen (the hub passes the current one: only "previous" shows).
 */
const props = defineProps<{ month: Date; hideNext?: boolean }>()
const { t, locale } = useI18n()

const previous = computed(() => addMonths(props.month, -1))
const next = computed(() => addMonths(props.month, 1))
const showPrevious = computed(() => isMonthInRange(previous.value))
const showNext = computed(
  () => !props.hideNext && isMonthInRange(next.value) && next.value <= addMonths(startOfToday(), 3),
)
const to = (date: Date) => ({ name: 'events-month' as const, params: { month: toMonthKey(date) } })
</script>

<template>
  <nav
    :aria-label="t('events.monthNav')"
    class="flex flex-wrap items-center justify-between gap-4 text-body-sm text-meta"
  >
    <p v-if="showPrevious">
      {{ t('events.previousMonth') }}
      <UiTextLink :to="to(previous)">{{ formatMonthYear(previous, locale) }}</UiTextLink>
    </p>
    <p v-if="showNext">
      {{ t('events.nextMonth') }}
      <UiTextLink :to="to(next)">{{ formatMonthYear(next, locale) }}</UiTextLink>
    </p>
  </nav>
</template>
