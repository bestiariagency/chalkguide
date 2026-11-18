<script setup lang="ts">
import { Mountain } from 'lucide-vue-next'
import type { StatsData } from '~/utils/admin-stats'
import { sumCategories } from '~/utils/admin-stats'
import { fmtDay } from '~/utils/admin-stats-format'

/**
 * Fichas publicadas (README §16.5): not a series, one row per type with a bar proportional to the total: what was
 * there before the period in `line-strong` and what is new in the period in `acc`.
 */
const props = defineProps<{ data: StatsData; today: string }>()

const rows = computed(() => {
  const types = [GYM_INFO, RESOLER_INFO, SHOE_INFO]
  const max = Math.max(1, ...types.map((i) => props.data.itemsAtEnd[i.category]))
  return types.map((info) => {
    const total = props.data.itemsAtEnd[info.category]
    // Bar: «before» = published at the start of the range. The label «+N» keeps the new ones of the period
    // (`items_new_in_range`); both can differ when something was unpublished, so the bar is not forced to add up to it.
    const before = Math.min(props.data.itemsAtStart[info.category], total)
    const added = Math.min(props.data.totals.itemsNew[info.category], total)
    return { key: info.category, name: info.title, total, added, width: (total / max) * 100, before: total ? (before / total) * 100 : 0 }
  })
})
const importedLinks = [GYM_INFO, RESOLER_INFO, SHOE_INFO].map((i) => ({ to: `${adminPath(i.route)}?estado=sin-publicar`, label: i.title }))
const total = computed(() => sumCategories(props.data.itemsAtEnd))
const added = computed(() => sumCategories(props.data.totals.itemsNew))
const scope = computed(() => (props.data.range === 'custom' ? 'el periodo' : `los últimos ${props.data.range === '30d' ? '30 días' : '12 meses'}`))
const atDate = computed(() => (props.data.to < props.today ? ` al ${fmtDay(props.data.to, false)}` : ''))
</script>

<template>
  <section aria-labelledby="h-fichas" :class="admCard">
    <div class="flex min-h-11 flex-wrap items-center gap-x-4 gap-y-1 border-b border-adm-line px-4 py-2">
      <h2 id="h-fichas" class="text-sm font-semibold">Fichas publicadas</h2>
      <p v-if="total" class="ml-auto flex flex-wrap items-center gap-x-3.5 gap-y-1 text-xs text-adm-meta">
        <span class="inline-flex items-center gap-1.5"><AdminStatsSwatch kind="base" />Antes del periodo</span>
        <span class="inline-flex items-center gap-1.5"><AdminStatsSwatch kind="acc" />Nuevas en el periodo</span>
      </p>
    </div>
    <div class="p-4">
      <AdminStatsEmptyRow
        v-if="!total" :icon="Mountain" title="Aún no hay fichas publicadas"
        text="Las fichas importadas siguen en borrador hasta que las publicas."
        links-label="Ver importadas:" :links="importedLinks"
      />
      <template v-else>
        <ul class="space-y-3">
          <li v-for="r in rows" :key="r.key" class="grid grid-cols-[96px_minmax(0,1fr)_auto] items-center gap-3 text-sm sm:grid-cols-[112px_minmax(0,1fr)_88px]">
            <span class="text-adm-meta">{{ r.name }}</span>
            <span class="flex h-3 overflow-hidden rounded-[3px] bg-adm-line-strong" :style="{ width: `${r.width}%` }" aria-hidden="true">
              <i class="block h-full bg-adm-line-strong" :style="{ width: `${r.before}%` }" /><i class="block h-full bg-adm-acc" :style="{ width: `${100 - r.before}%` }" />
            </span>
            <span class="text-right whitespace-nowrap tabular-nums">
              <span class="font-semibold">{{ fmtNum(r.total) }}</span>
              <span :class="['ml-1 text-xs', r.added ? 'font-medium text-adm-ok' : 'text-adm-muted']"><span class="sr-only">, nuevas: </span>+{{ fmtNum(r.added) }}</span>
            </span>
          </li>
        </ul>
        <p class="mt-4 border-t border-adm-line pt-3 text-xs text-adm-meta tabular-nums">
          Publicadas{{ atDate }}: {{ fmtNum(total) }} · Nuevas en {{ scope }}: {{ fmtNum(added) }}. Sin contar borradores ni importadas sin publicar.
        </p>
      </template>
    </div>
  </section>
</template>
