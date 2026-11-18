<script setup lang="ts">
import { Lock, Sigma, Table2, UserPen, Users } from 'lucide-vue-next'
import { criterionEffect, formatAverage, averageOf, type AdminCriterion, type CriterionSample } from '~/utils/admin-criteria'

/** Side panel: where the active criteria count, and how one real item's score block looks with the current list. */
const props = defineProps<{ active: readonly AdminCriterion[]; samples: readonly CriterionSample[]; isGym: boolean }>()

const uses = computed(() => props.active.flatMap((c) => {
  const effect = criterionEffect(c)
  return effect ? [{ id: c.id, kind: effect.kind, title: effect.title, text: `${c.name_es}: ${effect.detail}` }] : []
}))
const sample = computed(() => props.samples.find((s) => props.active.some((c) => s.scores[c.id])))
const rows = computed(() => (sample.value ? props.active.filter((c) => sample.value!.scores[c.id]) : []))
const average = computed(() => (sample.value ? averageOf(sample.value.scores, props.active.map((c) => c.id)) : null))
</script>

<template>
  <aside class="min-w-0 space-y-4" aria-label="Cómo se usan estos criterios">
    <section :class="[admCard, 'p-4']" aria-labelledby="h-where">
      <h2 id="h-where" class="text-sm font-semibold">Dónde cuentan</h2>
      <ul class="mt-3 space-y-3 text-sm">
        <li class="flex gap-3">
          <span class="grid size-7 flex-none place-items-center rounded-md bg-adm-subtle text-adm-meta"><UserPen class="size-4" aria-hidden="true" /></span>
          <span><span class="block font-medium">Nota del autor</span><span class="block text-xs text-adm-meta">Media de los criterios activos que has puntuado en cada ficha.</span></span>
        </li>
        <li class="flex gap-3">
          <span class="grid size-7 flex-none place-items-center rounded-md bg-adm-subtle text-adm-meta"><Users class="size-4" aria-hidden="true" /></span>
          <span><span class="block font-medium">Notas de lectores</span><span class="block text-xs text-adm-meta">Media por criterio activo, con 3 opiniones o más. La nota general de lectores va aparte y no depende de esta lista.</span></span>
        </li>
        <li v-for="use in uses" :key="use.id" class="flex gap-3">
          <span class="grid size-7 flex-none place-items-center rounded-md bg-adm-subtle text-adm-meta"><Sigma v-if="use.kind === 'index'" class="size-4" aria-hidden="true" /><Table2 v-else class="size-4" aria-hidden="true" /></span>
          <span><span class="block font-medium">{{ use.title }}</span><span class="block text-xs text-adm-meta">{{ use.text }}</span></span>
        </li>
        <li v-if="isGym" class="flex gap-3">
          <span class="grid size-7 flex-none place-items-center rounded-md bg-adm-subtle text-adm-meta"><Lock class="size-4" aria-hidden="true" /></span>
          <span><span class="block font-medium">Bloqueados</span><span class="block text-xs text-adm-meta">Los criterios de un índice no se pueden desactivar ni borrar mientras la fórmula los use.</span></span>
        </li>
      </ul>
    </section>
    <section :class="[admCard, 'p-4']" aria-labelledby="h-prev">
      <div class="flex items-baseline gap-2">
        <h2 id="h-prev" class="text-sm font-semibold">Así se ve en una ficha</h2>
        <span v-if="sample" class="ml-auto truncate text-xs text-adm-meta">{{ sample.name }}</span>
      </div>
      <template v-if="sample">
        <p class="mt-0.5 text-xs text-adm-meta">Nota del autor. Solo criterios activos con nota; «Sin nota» no sale ni cuenta.</p>
        <div class="mt-3 flex items-baseline justify-between">
          <span :class="admGroupLabel">Nota del autor</span>
          <span><span class="font-mono text-2xl">{{ formatAverage(average) }}</span><span class="ml-1 text-xs text-adm-meta">/ 5</span></span>
        </div>
        <ul class="mt-2 space-y-1 text-sm">
          <li v-for="c in rows" :key="c.id" class="grid min-h-8 grid-cols-[minmax(0,1fr)_88px_2rem] items-center gap-3">
            <span class="truncate">{{ c.name_es }}</span>
            <span class="h-1.5 overflow-hidden rounded-full bg-adm-subtle" aria-hidden="true"><span class="block h-full rounded-full bg-adm-acc" :style="{ width: `${sample.scores[c.id]! * 20}%` }" /></span>
            <span class="text-right font-mono tabular-nums">{{ formatAverage(sample.scores[c.id] ?? null) }}</span>
          </li>
        </ul>
      </template>
      <p v-else class="mt-2 text-xs text-adm-meta">Todavía no hay una ficha publicada con notas en esta categoría.</p>
    </section>
  </aside>
</template>
