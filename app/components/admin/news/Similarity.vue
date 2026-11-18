<script setup lang="ts">
import { HIGH_SIMILARITY, similarityPercent } from '~/utils/admin-news'

/** Similarity of the summary with the source excerpt (pg_trgm, 0–1): green below 35 %, amber from there. It informs, it does not block. */
const props = defineProps<{ value: number | null }>()
const percent = computed(() => similarityPercent(props.value))
const high = computed(() => (props.value ?? 0) >= HIGH_SIMILARITY)
</script>

<template>
  <span v-if="percent != null" class="inline-flex items-center gap-2">
    Parecido con la fuente
    <span class="h-1 w-24 overflow-hidden rounded-full bg-adm-line" aria-hidden="true"><span :class="['block h-full rounded-[inherit]', high ? 'bg-adm-warn-icon' : 'bg-adm-ok']" :style="{ width: `${Math.max(percent, 2)}%` }" /></span>
    <b class="font-medium text-adm-fg tabular-nums">{{ percent }} %</b> · {{ high ? 'alto' : 'bajo' }}
  </span>
</template>
