<script setup lang="ts">
import type { BucketView } from '~/utils/admin-stats-buckets'
import { STATS_COLS, STATS_TITLES, type StatsCardId } from '~/utils/admin-stats-series'

/**
 * Card shell (README §16.5): title + legend in the head, the chart (default slot) or the empty row (`empty` slot), and
 * the foot with «Periodo en curso o recortado» and «Ver como tabla» (`aria-pressed`). `foot` slot: extra lines.
 */
const props = defineProps<{
  id: StatsCardId
  buckets: BucketView[]
  /** Column title of the table: «Mes», «Semana», «Día». */
  grainLabel: string
  /** Range and grouping, for the label and the table caption. */
  subtitle: string
  empty: boolean
  /** One series only (Artículos): the title says it all. */
  noLegend?: boolean
}>()

const asTable = ref(false)
const cols = computed(() => STATS_COLS[props.id])
const title = computed(() => STATS_TITLES[props.id])
const partial = computed(() => props.buckets.some((b) => b.partial && cols.value.some((c) => c.value(b))))
const heading = useId()
</script>

<template>
  <section :aria-labelledby="heading" :class="admCard">
    <div class="flex min-h-11 flex-wrap items-center gap-x-4 gap-y-1 border-b border-adm-line px-4 py-2">
      <h2 :id="heading" class="text-sm font-semibold">{{ title }}</h2>
      <p v-if="!empty && !noLegend" class="ml-auto flex flex-wrap items-center gap-x-3.5 gap-y-1 text-xs text-adm-meta">
        <span v-for="c in cols" :key="c.label" class="inline-flex items-center gap-1.5"><AdminStatsSwatch :kind="c.swatch" />{{ c.label }}</span>
      </p>
    </div>
    <div v-if="empty" class="p-4"><slot name="empty" /><slot name="foot" /></div>
    <figure v-else :class="$slots.foot ? 'px-4 pt-4' : 'p-4'">
      <AdminStatsTable v-if="asTable" :buckets="buckets" :cols="cols" :first="grainLabel" :caption="`${title}, ${subtitle}`" />
      <slot v-else />
      <figcaption class="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-adm-meta">
        <span v-if="partial && !asTable" class="inline-flex items-center gap-1.5"><AdminStatsSwatch kind="partial" />Periodo en curso o recortado</span>
        <button type="button" class="ml-auto rounded underline underline-offset-2 hover:text-adm-fg max-md:inline-flex max-md:min-h-11 max-md:items-center" :aria-pressed="asTable" @click="asTable = !asTable">
          {{ asTable ? 'Ver gráfico' : 'Ver como tabla' }}
        </button>
      </figcaption>
    </figure>
    <div v-if="!empty && $slots.foot" class="px-4 pb-4"><slot name="foot" /></div>
  </section>
</template>
