<script setup lang="ts">
import type { ItemCriterion } from '~/services/admin/item-editor'
import type { GymIndices } from '~/services/admin/gym-editor'

/** Author score per criterion (1–5, "Sin nota" does not count in the average); gyms also show their derived indices. */
const props = defineProps<{ criteria: ItemCriterion[]; nouns: string; indices?: GymIndices | null; familyComplete?: boolean; showIndices?: boolean; changed: boolean }>()
const scores = defineModel<Record<string, number>>({ required: true })
const OPTIONS = [1, 2, 3, 4, 5].map((n) => ({ value: n as number | null, label: String(n) })).concat([{ value: null, label: 'Sin nota' }])
const uid = useId()

function setScore(id: string, value: number | null) {
  const { [id]: _removed, ...rest } = scores.value
  scores.value = value === null ? rest : { ...rest, [id]: value }
}
const average = computed(() => {
  const values = props.criteria.map((c) => scores.value[c.id]).filter((n): n is number => typeof n === 'number')
  return values.length ? (values.reduce((a, b) => a + b, 0) / values.length).toFixed(1).replace('.', ',') : '—'
})
const cards = computed(() => [
  { label: 'Índice principiante', value: props.indices?.beginner ?? null, incomplete: !!props.indices && !props.indices.beginnerComplete },
  { label: 'Índice familiar', value: props.indices?.family ?? null, incomplete: !!props.indices && !props.familyComplete },
  { label: 'Precio (5 = más barato)', value: props.indices?.price ?? null, incomplete: false },
])
const fmt = (n: number | null) => (n === null ? '—' : n.toFixed(1).replace('.', ','))
</script>

<template>
  <div :class="changedBar(changed)">
    <div class="flex items-end gap-3">
      <div>
        <h3 class="text-sm font-semibold">Notas por criterio</h3>
        <p class="mt-0.5 text-xs text-adm-meta">1 a 5. «Sin nota» no cuenta en la media. Flechas ← → para cambiar.</p>
      </div>
      <div class="ml-auto text-right">
        <p class="text-[11px] text-adm-meta">Media</p>
        <p class="text-2xl leading-7 font-semibold tabular-nums" aria-live="polite">{{ average }}</p>
      </div>
    </div>
    <p v-if="!criteria.length" class="mt-3 rounded-lg border border-dashed border-adm-line-strong p-4 text-sm text-adm-meta">No hay criterios activos para {{ nouns }}. Se gestionan en Criterios de nota.</p>
    <ul v-else class="mt-3 divide-y divide-adm-line rounded-lg border border-adm-line bg-adm-elev">
      <li v-for="criterion in criteria" :key="criterion.id" class="flex flex-wrap items-center gap-x-3 gap-y-2 px-3 py-2">
        <span :id="`${uid}-${criterion.id}`" class="min-w-[160px] flex-1 text-sm">{{ criterion.name }}</span>
        <AdminSegmented :model-value="scores[criterion.id] ?? null" :options="OPTIONS" :labelledby="`${uid}-${criterion.id}`" @update:model-value="setScore(criterion.id, $event)" />
      </li>
    </ul>
    <dl v-if="showIndices" class="mt-3 grid grid-cols-3 gap-3 text-sm">
      <div v-for="index in cards" :key="index.label" class="rounded-lg border border-adm-line bg-adm-elev p-3">
        <dt class="text-xs text-adm-meta">{{ index.label }}</dt>
        <dd class="mt-0.5 font-semibold tabular-nums">{{ fmt(index.value) }}<span class="text-xs font-normal text-adm-meta"> /5</span><span v-if="index.incomplete" class="ml-1 rounded bg-adm-warn-soft px-1 text-[11px] font-medium text-adm-warn">incompleto</span></dd>
      </div>
    </dl>
    <p v-if="showIndices" class="mt-1.5 text-xs text-adm-meta">Índices calculados con las notas y los datos del formulario, también antes de publicar.</p>
  </div>
</template>
