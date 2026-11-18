<script setup lang="ts">
import { Mail } from 'lucide-vue-next'

/** Weekly signups, plain SVG bars. The text description and the table keep it accessible. */
const props = defineProps<{ points: { bucket: string; value: number }[]; last30: number }>()

const W = 600
const H = 160
const max = computed(() => Math.max(1, ...props.points.map((p) => p.value)))
const bars = computed(() => {
  const step = (W - 28) / Math.max(props.points.length, 1)
  return props.points.map((p, i) => {
    const h = Math.round((p.value / max.value) * 140)
    return { x: 40 + i * step, y: H - h, h, w: Math.max(step - 17, 4), last: i >= props.points.length - 4, ...p }
  })
})
const description = computed(() => `Altas semanales de ${props.points.length === 1 ? 'la última semana' : `las últimas ${props.points.length} semanas`}: ${props.points.map((p) => p.value).join(', ')}.`)
const asTable = ref(false)
const empty = computed(() => props.points.every((p) => p.value === 0))
</script>

<template>
  <section aria-labelledby="h-chart" :class="admCard">
    <div class="flex h-11 items-center gap-2 border-b border-adm-line px-4">
      <h2 id="h-chart" class="text-sm font-semibold">Altas de suscriptores por semana</h2>
      <NuxtLink :to="adminPath('estadisticas')" class="ml-auto rounded text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:inline-flex max-md:min-h-11 max-md:items-center">Ver estadísticas</NuxtLink>
    </div>
    <figure class="p-4">
      <div v-if="!points.length || empty" class="flex items-center gap-3 py-1">
        <span class="grid size-8 flex-none place-items-center rounded-lg bg-adm-subtle text-adm-meta"><Mail class="size-4" aria-hidden="true" /></span>
        <div>
          <p class="text-[13px] leading-5 font-medium">Aún no hay altas</p>
          <p class="text-xs text-adm-meta">Con la primera verás aquí las altas de cada semana. La newsletter se conecta con Brevo antes del lanzamiento.</p>
        </div>
      </div>
      <template v-else>
        <svg v-if="!asTable" :viewBox="`0 -14 ${W} ${H + 34}`" class="h-40 w-full" role="img" aria-labelledby="chart-desc">
          <desc id="chart-desc">{{ description }}</desc>
          <line x1="28" :y1="H" x2="600" :y2="H" class="stroke-adm-line-strong" />
          <text x="0" y="14" class="fill-adm-muted font-mono text-[11px]">{{ max }}</text>
          <text x="6" :y="H + 4" class="fill-adm-muted font-mono text-[11px]">0</text>
          <rect v-for="b in bars" :key="b.bucket" :x="b.x" :y="b.y" :width="b.w" :height="b.h" rx="3" :class="b.last ? 'fill-adm-acc' : 'fill-adm-line-strong'" />
        </svg>
        <table v-else class="w-full text-left text-[13px] tabular-nums">
          <caption class="sr-only">Altas semanales</caption>
          <thead><tr class="text-xs text-adm-meta"><th scope="col" class="py-1 font-medium">Semana del</th><th scope="col" class="py-1 text-right font-medium">Altas</th></tr></thead>
          <tbody><tr v-for="p in points" :key="p.bucket" class="border-t border-adm-line"><td class="py-1">{{ shortDate(p.bucket) }}</td><td class="py-1 text-right">{{ p.value }}</td></tr></tbody>
        </table>
      </template>
      <figcaption v-if="!(!points.length || empty)" class="mt-2 flex flex-wrap gap-x-4 text-xs text-adm-meta">
        <span class="inline-flex items-center gap-1.5"><span class="size-2.5 rounded-sm bg-adm-acc" aria-hidden="true" />Últimos 30 días: {{ last30 }} {{ last30 === 1 ? 'alta' : 'altas' }}</span>
        <button v-if="points.length" type="button" class="ml-auto underline underline-offset-2 hover:text-adm-fg max-md:py-3" :aria-pressed="asTable" @click="asTable = !asTable">{{ asTable ? 'Ver gráfico' : 'Ver como tabla' }}</button>
      </figcaption>
    </figure>
  </section>
</template>
