<script setup lang="ts">
import { summaryCells, type SubscribersSummary } from '~/utils/admin-subscribers'

/** Header summary (`dl`, 4 cells, 2x2 under 1024). Dashes while it loads. The charts are 6.16. */
const props = defineProps<{ summary?: SubscribersSummary }>()
const cells = computed(() => summaryCells(props.summary))
const format = (n: number | null) => (n == null ? '—' : new Intl.NumberFormat('es-ES').format(n))
</script>

<template>
  <dl class="grid grid-cols-2 overflow-hidden rounded-lg border border-adm-line bg-adm-elev text-sm lg:grid-cols-4" :aria-busy="!summary || undefined">
    <div v-for="(cell, i) in cells" :key="cell.key" :class="['border-adm-line p-3', i < 2 && 'border-b lg:border-b-0', i % 2 === 0 && 'border-r', i === 1 && 'lg:border-r']">
      <dt class="text-xs text-adm-meta">{{ cell.title }}</dt>
      <dd class="text-xl font-semibold tabular-nums">{{ format(cell.value) }}</dd>
      <dd class="text-xs text-adm-meta">{{ cell.hint }}</dd>
    </div>
  </dl>
</template>
