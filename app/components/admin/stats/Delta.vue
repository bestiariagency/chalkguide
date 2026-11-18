<script setup lang="ts">
import { ArrowDownRight, ArrowUpRight, Equal } from 'lucide-vue-next'
import { statsDelta, type StatsNoun } from '~/utils/admin-stats-delta'

/** Comparison line of a KPI (README §16.11): sign and arrow carry the meaning (not red or green). */
const props = defineProps<{ current: number; previous: number | null; noun?: StatsNoun }>()
const delta = computed(() => statsDelta(props.current, props.previous, props.noun))
const icons = { up: ArrowUpRight, down: ArrowDownRight, same: Equal }
const tone = { up: 'text-adm-ok', down: 'text-adm-meta', same: 'text-adm-muted' }
</script>

<template>
  <p class="mt-2 flex items-start gap-1.5 text-xs leading-4 text-adm-meta">
    <span v-if="delta.kind === 'none' || delta.kind === 'zero'" class="w-3.5 flex-none text-center" aria-hidden="true">{{ delta.kind === 'none' ? '—' : '=' }}</span>
    <span v-else-if="delta.kind === 'new'" :class="[admChip, 'h-[18px] flex-none bg-adm-acc-soft text-adm-acc']">Nuevo</span>
    <component :is="icons[delta.kind]" v-else :class="['mt-px size-3.5 flex-none', tone[delta.kind]]" aria-hidden="true" />
    <span><b v-if="delta.strong" class="font-semibold whitespace-nowrap text-adm-fg tabular-nums">{{ delta.strong }}</b>{{ delta.strong ? ' ' : '' }}{{ delta.text }}</span>
  </p>
</template>
