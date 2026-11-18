<script setup lang="ts">
import type { ReviewCounts, ReviewFilter } from '~/utils/admin-import-report'

/** Summary that also filters (README §13.3): buttons with `aria-pressed` and `aria-controls`; focus stays on the stat. */
defineProps<{ counts: ReviewCounts; controls: string }>()
const filter = defineModel<ReviewFilter>({ required: true })

const cards = (c: ReviewCounts): { value: ReviewFilter; label: string; note: string; n: number; tone?: 'warn' | 'err' }[] => [
  { value: 'all', label: 'Filas', note: 'Todas las del archivo', n: c.all },
  { value: 'created', label: 'Nuevas', note: 'Se crean sin publicar', n: c.created },
  { value: 'changed', label: 'Actualizan', note: `${c.drafted} publicadas, a borrador`, n: c.changed },
  { value: 'unchanged', label: 'Sin cambios', note: 'No se tocan', n: c.unchanged },
  { value: 'warnings', label: 'Con avisos', note: `${c.blocked} bloquearán publicar`, n: c.warnings, tone: 'warn' },
  { value: 'errors', label: 'Con error', note: 'No se importan', n: c.errors, tone: 'err' },
]
</script>

<template>
  <div class="grid grid-cols-3 gap-2 lg:grid-cols-6" role="group" aria-label="Resumen de la revisión; cada cifra filtra la tabla">
    <button
      v-for="card in cards(counts)"
      :key="card.value"
      type="button"
      :aria-pressed="filter === card.value"
      :aria-controls="controls"
      :class="[
        'flex min-w-0 flex-col items-start gap-0.5 rounded-lg border bg-adm-elev px-3 py-2.5 text-left transition-colors duration-150 hover:border-adm-control focus-visible:outline-2 focus-visible:outline-offset-1 focus-visible:outline-adm-acc',
        filter === card.value ? (card.tone === 'err' ? 'border-adm-danger bg-adm-danger-soft shadow-[inset_0_0_0_1px_var(--adm-danger)]' : 'border-adm-fg shadow-[inset_0_0_0_1px_var(--adm-fg)]') : 'border-adm-line',
      ]"
      @click="filter = card.value"
    >
      <b :class="['text-xl leading-7 font-semibold tabular-nums', card.tone === 'err' && card.n > 0 && 'text-adm-danger', card.tone === 'warn' && card.n > 0 && 'text-adm-warn']">{{ card.n }}</b>
      <span class="text-xs text-adm-meta">{{ card.label }}</span>
      <small :class="['text-xs', filter === card.value && card.tone === 'err' ? 'text-adm-meta' : 'text-adm-muted']">{{ card.note }}</small>
    </button>
  </div>
</template>
