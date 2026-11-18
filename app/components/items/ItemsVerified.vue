<script setup lang="ts">
/**
 * "Dato verificado el …" (green badge) or, past 6 months, the dashed "puede haber cambiado".
 * `compact` uses a numeric short date for tables and cards.
 */
const props = defineProps<{ date: string | null; compact?: boolean }>()
const { t, locale } = useI18n()

const stale = computed(() => (props.date ? isStale(props.date) : false))
const label = computed(() => {
  if (!props.date) return ''
  const text = props.compact
    ? formatDate(props.date, locale.value, { day: '2-digit', month: '2-digit', year: '2-digit' })
    : formatDate(props.date, locale.value)
  if (props.compact && stale.value) return t('transparency.staleShort', { date: text })
  return t(stale.value ? 'transparency.stale' : 'transparency.verified', { date: text })
})
</script>

<template>
  <UiBadge v-if="date" :kind="stale ? 'stale' : 'verified'">{{ label }}</UiBadge>
</template>
