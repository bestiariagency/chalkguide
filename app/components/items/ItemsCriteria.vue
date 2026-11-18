<script setup lang="ts">
import type { AuthorScore } from '~/types/domain'

/**
 * Scores per criterion (1–5) with an index bar each. `scores` maps criterion key → value, so
 * the same card shows the author's notes and, once there are enough opinions, the readers'.
 */
const props = defineProps<{
  title: string
  overall: number | null
  criteria: AuthorScore[]
  scores?: Record<string, number>
  tone?: 'author' | 'readers'
}>()
const { t, locale } = useI18n()

const rows = computed(() =>
  props.criteria.flatMap((criterion) => {
    const value = props.scores ? props.scores[criterion.criterionKey] : criterion.score
    return value === undefined ? [] : [{ key: criterion.criterionKey, name: criterion.name, value }]
  }),
)
</script>

<template>
  <div class="max-w-read rounded-lg border-[0.5px] border-line-strong bg-board p-5 tabular-nums md:p-6">
    <div class="flex items-baseline justify-between gap-3">
      <p class="label-mini">{{ title }}</p>
      <p v-if="overall !== null">
        <span class="font-mono text-3xl" :class="tone === 'readers' ? 'text-foreground' : 'text-accent'">
          {{ formatScore(overall, locale) }}
        </span>
        <span class="ml-1 text-meta">{{ t('ratings.outOf') }}</span>
      </p>
    </div>
    <ul class="mt-4 space-y-1 text-caption">
      <li
        v-for="row in rows"
        :key="row.key"
        class="grid min-h-8 grid-cols-[minmax(0,1fr)_88px_2.25rem] items-center gap-3"
      >
        <span>{{ row.name }}</span>
        <UiIndexBar :value="row.value" />
        <span class="text-right font-mono">{{ formatScore(row.value, locale) }}</span>
      </li>
    </ul>
  </div>
</template>
