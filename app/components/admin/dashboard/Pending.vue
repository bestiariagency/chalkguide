<script setup lang="ts">
import { BadgeCheck, Bot, CalendarPlus, Check, ChevronRight, CircleAlert, Clock, FilePen, FileText, GitCompareArrows, ImageOff, TriangleAlert, Images, MessageSquare, Newspaper, PackagePlus } from 'lucide-vue-next'
import type { Component } from 'vue'
import type { PendingGroup, PendingIcon, PendingRow, PendingTone } from '~/utils/admin-dashboard-pending'

/** "Pendiente" (README §14.2): up to three groups side by side from 1024 px, each row opens its filtered inbox. */
const props = defineProps<{ groups: PendingGroup[] }>()

const icons: Record<PendingIcon, Component> = {
  reviews: MessageSquare,
  photos: Images,
  events: CalendarPlus,
  news: Newspaper,
  ingest: Bot,
  changes: GitCompareArrows,
  imported: PackagePlus,
  drafts: FilePen,
  stale: BadgeCheck,
  alt: ImageOff,
  pages: FileText,
  cleanup: TriangleAlert,
}
/** The failed cleanup is the only confirmed failure: it takes the danger tone and its own icon. */
const iconOf = (row: PendingRow) => (row.icon === 'cleanup' && row.tone === 'danger' ? CircleAlert : icons[row.icon])
const helpOpen = ref<string | null>(null)
const tones: Record<PendingTone, string> = {
  acc: 'bg-adm-acc-soft text-adm-acc',
  rev: 'bg-adm-st-rev-bg text-adm-st-rev',
  subtle: 'bg-adm-subtle text-adm-meta',
  warn: 'bg-adm-warn-soft text-adm-warn',
  danger: 'bg-adm-danger-soft text-adm-danger',
}
const rowClass = 'flex min-h-14 items-center gap-3 px-4 py-2'
const columns = ['', 'lg:grid-cols-1', 'lg:grid-cols-2', 'lg:grid-cols-3']
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
    <div :class="['grid', columns[Math.min(groups.length, 3)]]">
      <div v-for="group in groups" :key="group.key" class="border-t border-adm-line first:border-t-0 lg:border-t-0 lg:border-l lg:first:border-l-0">
        <h3 :id="`pend-${group.key}`" class="px-4 pt-3 pb-1 text-xs font-semibold text-adm-meta">
          {{ group.label }} <span class="font-normal text-adm-muted tabular-nums">{{ group.rows.length }}</span>
        </h3>
        <ul :aria-labelledby="`pend-${group.key}`">
          <li v-for="row in group.rows" :key="row.key">
            <NuxtLink v-if="row.to" :to="row.to" :class="[rowClass, 'group hover:bg-adm-subtle focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-adm-acc']">
              <span :class="['grid size-8 flex-none place-items-center rounded-lg', tones[row.tone]]"><component :is="iconOf(row)" class="size-4" aria-hidden="true" /></span>
              <span class="min-w-0 flex-1">
                <span class="block text-[13px] leading-5 font-medium tabular-nums">{{ row.strong }}</span>
                <span class="block text-xs leading-4 text-adm-meta">{{ row.context }}</span>
                <span v-if="row.deadline" class="mt-0.5 flex items-center gap-1 text-xs leading-4 font-medium text-adm-warn"><Clock class="size-3.5 flex-none" aria-hidden="true" />{{ row.deadline }}</span>
              </span>
              <ChevronRight class="size-4 flex-none text-adm-muted transition-transform duration-150 group-hover:translate-x-0.5 motion-reduce:transition-none motion-reduce:group-hover:translate-x-0" aria-hidden="true" />
            </NuxtLink>
            <div v-else>
              <div :class="rowClass">
                <span :class="['grid size-8 flex-none place-items-center rounded-lg', tones[row.tone]]"><component :is="iconOf(row)" class="size-4" aria-hidden="true" /></span>
                <span class="min-w-0 flex-1">
                  <span class="block text-[13px] leading-5 font-medium tabular-nums">{{ row.strong }}</span>
                  <span class="block text-xs leading-4 text-adm-meta">{{ row.context }}</span>
                </span>
                <button
                  v-if="row.help"
                  type="button"
                  :class="[admBtnQuiet, 'flex-none']"
                  :aria-expanded="helpOpen === row.key"
                  :aria-controls="`pend-help-${row.key}`"
                  @click="helpOpen = helpOpen === row.key ? null : row.key"
                >
                  Cómo arreglarlo
                </button>
              </div>
              <p v-if="row.help" v-show="helpOpen === row.key" :id="`pend-help-${row.key}`" class="px-4 pb-3 pl-15 text-xs leading-4 text-adm-meta">{{ row.help }}</p>
            </div>
          </li>
        </ul>
      </div>
    </div>
  </section>
</template>
