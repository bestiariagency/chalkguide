<script setup lang="ts">
import { Info } from 'lucide-vue-next'
import type { GymForm } from '~/utils/gym-fields'

/** Grados y estilo: two descriptive 1–5 scales. They are not notes: they feed no average or index. */
const props = defineProps<{ changed: string[] }>()
const form = defineModel<GymForm>('form', { required: true })
const bar = (id: string) => changedBar(props.changed.includes(id))
const GRADING = ['Generosos', 'Algo generosos', 'En la media', 'Algo duros', 'Duros']
const STYLE = ['Muy técnico', 'Técnico', 'Mixto', 'Dinámico', 'Muy dinámico']
const options = (labels: string[]) => labels.map((sub, i) => ({ value: (i + 1) as number | null, label: String(i + 1), sub }))
const SCALES = [
  { id: 'grading_difficulty', title: 'Grados', hint: 'frente a la media de Barcelona', labels: GRADING, help: {} as Record<number, string> },
  { id: 'setting_dynamism', title: 'Estilo', hint: 'de técnico a dinámico', labels: STYLE, help: {
    1: 'Muy técnico: casi todo pasos de precisión (pies pequeños, equilibrio, regletas); apenas hay saltos.',
    2: 'Técnico: predominan los pasos de precisión, con algún movimiento amplio.',
    3: 'Mixto: equilibrio entre pasos de precisión y movimientos amplios.',
    4: 'Dinámico: predominan los movimientos amplios y los lances, con algún paso de precisión.',
    5: 'Muy dinámico: casi todo lances, saltos y movimientos coordinados, al estilo competición.',
  } as Record<number, string> },
] as const
const uid = useId()
/** The help follows the chosen value: only the options that have a line show one. */
const helpFor = (scale: (typeof SCALES)[number]) => {
  const value = at(scale.id)
  return value ? scale.help[value] : undefined
}
const at = (id: (typeof SCALES)[number]['id']) => form.value[id]
</script>

<template>
  <div class="space-y-6">
    <p class="flex gap-2 rounded-lg bg-adm-subtle px-3 py-2 text-[13px]" role="note">
      <Info class="mt-0.5 size-4 flex-none text-adm-info" aria-hidden="true" />
      <span><b>No son notas: describen, no puntúan.</b> Ayudan a elegir y no entran en medias ni en índices. En el sitio salen en «Cómo se escala aquí» y en la tarjeta.</span>
    </p>
    <div v-for="scale in SCALES" :key="scale.id" :class="bar(scale.id)">
      <div class="flex items-baseline gap-2">
        <p :id="`${uid}-${scale.id}`" class="text-xs font-medium">{{ scale.title }}</p>
        <span class="text-xs text-adm-meta">{{ scale.hint }}</span>
        <button type="button" class="ml-auto text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11" @click="form[scale.id] = null">Sin dato</button>
      </div>
      <div class="mt-2"><AdminSegmented v-model="form[scale.id]" stacked :options="options([...scale.labels])" :labelledby="`${uid}-${scale.id}`" /></div>
      <p v-if="helpFor(scale)" class="mt-1.5 text-xs text-adm-meta">{{ helpFor(scale) }}</p>
    </div>
    <div>
      <p class="mb-1.5 text-xs font-medium">Así se ve en la tarjeta</p>
      <dl class="inline-grid grid-cols-[48px_72px_auto] items-center gap-x-2 gap-y-1 rounded-lg border border-adm-line bg-adm-side px-3 py-2 text-xs">
        <template v-for="scale in SCALES" :key="scale.id">
          <dt class="text-adm-meta">{{ scale.title }}</dt>
          <dd class="relative mx-1 h-3.5" aria-hidden="true">
            <span class="absolute inset-x-0 top-1.5 h-0.5 rounded bg-adm-line-strong" />
            <i v-for="n in 5" :key="n" class="absolute top-[3px] h-2 w-0.5 bg-adm-control" :style="{ left: `calc(${(n - 1) * 25}% - ${n === 5 ? 2 : 0}px)` }" />
            <b v-if="at(scale.id)" class="absolute top-0.5 size-2.5 -translate-x-1/2 rounded-full bg-adm-fg shadow-[0_0_0_2px_var(--adm-elev)]" :style="{ left: `${((at(scale.id) ?? 1) - 1) * 25}%` }" />
          </dd>
          <dd>{{ at(scale.id) ? scale.labels[(at(scale.id) ?? 1) - 1] : 'Sin dato' }}</dd>
        </template>
      </dl>
    </div>
  </div>
</template>
