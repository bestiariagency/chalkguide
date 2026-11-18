<script setup lang="ts">
import { ChartNoAxesColumn, Plug } from 'lucide-vue-next'

/** Visitas por página: the gap of D5. No numbers, no sample rows, no skeleton that suggests data is coming (README §16.5). */
</script>

<template>
  <section aria-labelledby="h-visits" :class="admCard">
    <div class="flex min-h-11 items-center gap-2 border-b border-adm-line px-4 py-2">
      <h2 id="h-visits" class="text-sm font-semibold">Visitas por página</h2>
      <span :class="[admChip, 'ml-auto bg-adm-st-draft-bg text-adm-st-draft']"><Plug aria-hidden="true" />Sin conectar</span>
    </div>
    <div class="p-4">
      <AdminStatsEmptyRow
        :icon="ChartNoAxesColumn" title="Aún no medimos visitas"
        text="Cuando conectemos la analítica (sin cookies) verás aquí las páginas más vistas de este periodo. No hay datos anteriores: se empieza a contar desde ese día."
      />
    </div>
  </section>
</template>
