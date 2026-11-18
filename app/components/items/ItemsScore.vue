<script setup lang="ts">
/**
 * Author score "4.5/5": accent tone for the best of the list, neutral otherwise; "—" without a score.
 * `large` (32 px, 24 on mobile) is the home table's: no badge, the best one is ringed in chalk.
 */
const props = defineProps<{ score: number | null; highlight?: boolean; whole?: boolean; large?: boolean }>()
const { t, locale } = useI18n()
const text = computed(() => formatScore(props.score, locale.value, props.whole ? 0 : 1))
</script>

<template>
  <span
    v-if="score !== null && large"
    class="inline-block font-mono text-2xl leading-none whitespace-nowrap md:text-[32px]"
    :aria-label="t('ratings.outOfValue', { value: text })"
  >
    <UiChalkStroke v-if="highlight" variant="circle" class="px-[.5em] py-[.28em]">
      {{ text }}<span class="text-sm text-meta">/5</span>
    </UiChalkStroke>
    <span v-else class="inline-block py-[.28em] pr-[.5em]">
      {{ text }}<span class="text-sm text-meta">/5</span>
    </span>
  </span>
  <span
    v-else-if="score !== null"
    class="inline-flex items-center rounded-sm px-2 py-1.5 font-mono text-body-sm leading-none"
    :class="highlight ? 'bg-accent-muted text-accent' : 'bg-elevated text-foreground'"
    :aria-label="t('ratings.outOfValue', { value: text })"
  >
    {{ text }}<span :class="highlight ? '' : 'text-meta'">/5</span>
  </span>
  <span v-else class="text-meta">
    <span aria-hidden="true">—</span><span class="sr-only">{{ t('common.noData') }}</span>
  </span>
</template>
