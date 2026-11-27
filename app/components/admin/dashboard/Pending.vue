<script setup lang="ts">
import { Check } from 'lucide-vue-next'
import type { PendingGroup } from '~/utils/admin-dashboard-pending'

/** "Pendiente" (README §14.2, §20): «Sistema» at full width, then up to three groups side by side from 1024 px; each row opens its filtered inbox. */
const props = defineProps<{ groups: PendingGroup[] }>()

const columns = ['', 'lg:grid-cols-1', 'lg:grid-cols-2', 'lg:grid-cols-3']
const system = computed(() => props.groups.find((g) => g.key === 'system'))
const others = computed(() => props.groups.filter((g) => g.key !== 'system'))
const tasks = computed(() => props.groups.reduce((sum, g) => sum + g.rows.length, 0))
</script>

<template>
  <section v-if="!groups.length" aria-labelledby="h-pend" :class="[admCard, 'flex min-h-14 items-center gap-3 px-4 py-2']">
    <span class="grid size-8 flex-none place-items-center rounded-lg bg-adm-ok-soft text-adm-ok"><Check class="size-4" aria-hidden="true" /></span>
    <div>
      <h2 id="h-pend" class="text-[13px] leading-5 font-medium">Todo al día</h2>
      <p class="text-xs text-adm-meta">Nada que moderar, publicar ni revisar.</p>
    </div>
  </section>
  <section v-else aria-labelledby="h-pend" :class="[admCard, 'overflow-hidden']">
    <div class="flex h-11 items-center gap-2 border-b border-adm-line px-4">
      <h2 id="h-pend" class="text-sm font-semibold">Pendiente</h2>
      <span class="text-xs text-adm-muted tabular-nums">{{ tasks }} {{ tasks === 1 ? 'tarea' : 'tareas' }}</span>
      <span class="ml-auto hidden text-xs text-adm-muted md:block">De más urgente a menos</span>
    </div>
    <div v-if="system" class="border-b border-adm-line last:border-b-0">
      <h3 id="pend-system" class="px-4 pt-3 pb-1 text-xs font-semibold text-adm-meta">
        {{ system.label }} <span class="font-normal text-adm-muted tabular-nums">{{ system.rows.length }}</span>
      </h3>
      <ul aria-labelledby="pend-system" :class="['grid', system.rows.length > 1 && 'lg:grid-cols-2 lg:[&>li:nth-child(even)]:border-l lg:[&>li:nth-child(even)]:border-adm-line']">
        <li v-for="row in system.rows" :key="row.key"><AdminDashboardPendingRow :row="row" /></li>
      </ul>
    </div>
    <div v-if="others.length" :class="['grid', columns[Math.min(others.length, 3)]]">
      <div v-for="group in others" :key="group.key" class="border-t border-adm-line first:border-t-0 lg:border-t-0 lg:border-l lg:first:border-l-0">
        <h3 :id="`pend-${group.key}`" class="px-4 pt-3 pb-1 text-xs font-semibold text-adm-meta">
          {{ group.label }} <span class="font-normal text-adm-muted tabular-nums">{{ group.rows.length }}</span>
        </h3>
        <ul :aria-labelledby="`pend-${group.key}`">
          <li v-for="row in group.rows" :key="row.key"><AdminDashboardPendingRow :row="row" /></li>
        </ul>
      </div>
    </div>
  </section>
</template>
