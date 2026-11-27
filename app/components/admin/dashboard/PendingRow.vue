<script setup lang="ts">
import { BadgeCheck, Bot, CalendarPlus, ChartNoAxesColumn, ChevronRight, CircleAlert, Clock, FilePen, FileText, GitCompareArrows, ImageOff, Images, MessageSquare, Newspaper, PackagePlus, ShieldAlert, ShieldQuestionMark, TimerOff, TriangleAlert } from 'lucide-vue-next'
import type { Component } from 'vue'
import type { PendingIcon, PendingRow, PendingTone } from '~/utils/admin-dashboard-pending'

/** One row of "Pendiente" (README §14.2, §20.3): opens its inbox, or is a notice with an on-demand remedy. */
const props = defineProps<{ row: PendingRow }>()

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
  consent: ShieldAlert,
  'consent-unknown': ShieldQuestionMark,
  analytics: ChartNoAxesColumn,
  stopped: TimerOff,
}
/** The failed cleanup is a confirmed failure: it takes the danger tone and its own icon. */
const icon = computed(() => (props.row.icon === 'cleanup' && props.row.tone === 'danger' ? CircleAlert : icons[props.row.icon]))
const tones: Record<PendingTone, string> = {
  acc: 'bg-adm-acc-soft text-adm-acc',
  rev: 'bg-adm-st-rev-bg text-adm-st-rev',
  subtle: 'bg-adm-subtle text-adm-meta',
  warn: 'bg-adm-warn-soft text-adm-warn',
  danger: 'bg-adm-danger-soft text-adm-danger',
}
const rowClass = 'flex min-h-14 items-center gap-3 px-4 py-2'
const open = ref(false)
const helpParts = computed(() => (props.row.helpCode ? (props.row.help ?? '').split('{code}') : null))
</script>

<template>
  <NuxtLink v-if="row.to" :to="row.to" :class="[rowClass, 'group hover:bg-adm-subtle focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-adm-acc']">
    <span :class="['grid size-8 flex-none place-items-center rounded-lg', tones[row.tone]]"><component :is="icon" class="size-4" aria-hidden="true" /></span>
    <span class="min-w-0 flex-1">
      <span class="block text-[13px] leading-5 font-medium tabular-nums"><span v-if="row.sr" class="sr-only">{{ row.sr }}</span>{{ row.strong }}</span>
      <span class="block text-xs leading-4 text-adm-meta">{{ row.context }}</span>
      <span v-if="row.deadline" class="mt-0.5 flex items-center gap-1 text-xs leading-4 font-medium text-adm-warn"><Clock class="size-3.5 flex-none" aria-hidden="true" />{{ row.deadline }}</span>
    </span>
    <ChevronRight class="size-4 flex-none text-adm-muted transition-transform duration-150 group-hover:translate-x-0.5 motion-reduce:transition-none motion-reduce:group-hover:translate-x-0" aria-hidden="true" />
  </NuxtLink>
  <div v-else>
    <div :class="[rowClass, 'max-md:flex-wrap']">
      <span :class="['grid size-8 flex-none place-items-center rounded-lg', tones[row.tone]]"><component :is="icon" class="size-4" aria-hidden="true" /></span>
      <span class="min-w-0 flex-1 max-md:basis-[calc(100%-44px)]">
        <span class="block text-[13px] leading-5 font-medium tabular-nums"><span v-if="row.sr" class="sr-only">{{ row.sr }}</span>{{ row.strong }}</span>
        <span class="block text-xs leading-4 text-adm-meta">{{ row.context }}</span>
      </span>
      <button
        v-if="row.help"
        type="button"
        :class="[admBtnQuiet, 'flex-none max-md:ml-11 max-md:h-11!']"
        :aria-expanded="open"
        :aria-controls="`pend-help-${row.key}`"
        @click="open = !open"
      >
        Cómo arreglarlo
      </button>
    </div>
    <p v-if="row.help" v-show="open" :id="`pend-help-${row.key}`" class="max-w-[72ch] px-4 pb-3 pl-15 text-xs leading-4 text-adm-meta">
      <template v-if="helpParts">{{ helpParts[0] }}<code class="font-mono">{{ row.helpCode }}</code>{{ helpParts[1] }}</template>
      <template v-else>{{ row.help }}</template>
    </p>
  </div>
</template>
