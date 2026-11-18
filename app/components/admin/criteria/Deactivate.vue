<script setup lang="ts">
import { ListX, Loader2, TriangleAlert, UserPen, Users } from 'lucide-vue-next'
import { averageOf, criterionEffect, formatAverage, pluralItems, type AdminCriterion, type CriterionSample, type CriterionUsage } from '~/utils/admin-criteria'

/**
 * Confirmation to deactivate a criterion that has notes (alertdialog, focus on Cancel). Lists only the
 * effects that apply; the "before -> after" of the author's score is computed here from the samples.
 */
const props = defineProps<{
  criterion: AdminCriterion
  usage: CriterionUsage
  /** Active criteria of the category (before the change). */
  active: readonly AdminCriterion[]
  samples: readonly CriterionSample[]
  categoryLabel: string
  busy: boolean
  /** Open on top of the edit drawer. */
  stacked?: boolean
}>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [] }>()

const MAX_ROWS = 3
const effect = computed(() => criterionEffect(props.criterion))
const rows = computed(() => {
  const before = props.active.map((c) => c.id)
  const after = before.filter((id) => id !== props.criterion.id)
  return props.samples
    .filter((s) => s.scores[props.criterion.id])
    .slice(0, MAX_ROWS)
    .map((s) => ({ id: s.id, name: s.name, before: averageOf(s.scores, before), after: averageOf(s.scores, after) }))
})
const description = computed(() =>
  'Deja de contar en el sitio en cuanto confirmes. Las notas no se borran: si lo reactivas, vuelven a contar.'
  + (props.usage.user_reviews ? ' Si un lector reenvía su opinión mientras esté desactivado, perderá su nota en este criterio.' : ''),
)
const more = computed(() => Math.max(props.usage.author_items - rows.value.length, 0))
</script>

<template>
  <AdminModal
    v-model:open="open"
    alert
    :stacked="stacked"
    :busy="busy"
    :title="`¿Desactivar «${criterion.name_es}»?`"
    :description="description"
  >
    <div class="space-y-4 text-sm">
      <div v-if="usage.author_items">
        <p class="flex items-center gap-2 font-medium"><UserPen class="size-4 text-adm-meta" aria-hidden="true" />Cambia tu nota media en {{ pluralItems(usage.author_items) }}</p>
        <table v-if="rows.length" class="mt-2 w-full tabular-nums">
          <caption class="sr-only">Nota del autor antes y después</caption>
          <thead class="sr-only"><tr><th scope="col">Ficha</th><th scope="col">Ahora</th><th scope="col">Después</th></tr></thead>
          <tbody>
            <tr v-for="row in rows" :key="row.id" class="border-t border-adm-line">
              <th scope="row" class="py-1.5 pr-2 text-left font-normal">{{ row.name }}</th>
              <td class="py-1.5 text-right font-mono text-adm-meta">{{ formatAverage(row.before) }}</td>
              <td class="w-6 py-1.5 text-center text-adm-muted" aria-hidden="true">→</td>
              <td class="w-10 py-1.5 text-right font-mono font-medium">{{ formatAverage(row.after) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="more" class="mt-1 text-xs text-adm-meta">y {{ more }} más. La media se recalcula con los demás criterios.</p>
      </div>
      <div v-if="usage.user_reviews">
        <p class="flex items-center gap-2 font-medium"><Users class="size-4 text-adm-meta" aria-hidden="true" />Sale de las notas de lectores</p>
        <p class="mt-0.5 text-adm-meta">«{{ criterion.name_es }}» deja de mostrarse en la media por criterio ({{ usage.user_reviews }} {{ usage.user_reviews === 1 ? 'nota' : 'notas' }}). La nota general de lectores no cambia.</p>
      </div>
      <p v-if="effect?.kind === 'table'" class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5">
        <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
        <span>La {{ effect.detail.replace(/\.$/, '') }} se oculta mientras esté inactivo.</span>
      </p>
      <div>
        <p class="flex items-center gap-2 font-medium"><ListX class="size-4 text-adm-meta" aria-hidden="true" />Deja de pedirse al puntuar</p>
        <p class="mt-0.5 text-adm-meta">En tus fichas de {{ categoryLabel.toLowerCase() }} y en el formulario de opiniones.</p>
      </div>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnDanger" :disabled="busy" :aria-busy="busy || undefined" @click="emit('confirm')">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Desactivar
      </button>
    </template>
  </AdminModal>
</template>
