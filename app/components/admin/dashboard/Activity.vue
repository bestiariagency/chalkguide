<script setup lang="ts">
import { Download, FileMinus, FilePen, FilePlus2, GitCompareArrows, Trash2 } from 'lucide-vue-next'
import type { Component } from 'vue'
import { NuxtLink } from '#components'
import type { ActivityEntry } from '~/utils/admin-dashboard'

/** Last activity entries. The server masks the labels of private tables (admin_dashboard_stats). */
defineProps<{ entries: ActivityEntry[] }>()

const icons: Record<string, Component> = {
  insert: FilePlus2,
  update: FilePen,
  delete: Trash2,
  draft_publish: GitCompareArrows,
  draft_discard: GitCompareArrows,
  export: Download,
  unpublish: FileMinus,
}
function when(iso: string) {
  const day = dayKey(iso)
  const time = hhmm(iso)
  return day === dayKey(new Date()) ? time : `${shortDate(iso)}, ${time}`
}
</script>

<template>
  <section aria-labelledby="h-act" :class="admCard">
    <div class="flex h-11 items-center gap-2 border-b border-adm-line px-4">
      <h2 id="h-act" class="text-sm font-semibold">Actividad reciente</h2>
      <NuxtLink :to="adminPath('actividad')" class="ml-auto rounded text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg">Ver toda la actividad</NuxtLink>
    </div>
    <ol v-if="entries.length" class="px-4 py-2 text-sm">
      <li v-for="entry in entries" :key="entry.id" class="flex gap-3 py-2">
        <component :is="icons[entry.action] ?? FilePen" class="mt-0.5 size-4 flex-none text-adm-meta" aria-hidden="true" />
        <p class="min-w-0 flex-1">
          <component :is="activityLink(entry.table) ? NuxtLink : 'span'" :to="activityLink(entry.table) ?? undefined" :class="{ 'hover:underline': activityLink(entry.table) }">
            {{ activityText(entry).lead }}<template v-if="activityText(entry).label">: <span class="font-medium">{{ activityText(entry).label }}</span></template>
          </component>
          <span class="block text-xs text-adm-muted tabular-nums"><time :datetime="entry.occurredAt">{{ when(entry.occurredAt) }}</time><template v-if="entry.changedCount"> · {{ entry.changedCount }} {{ entry.changedCount === 1 ? 'campo' : 'campos' }}</template></span>
        </p>
      </li>
    </ol>
    <p v-else class="px-4 py-6 text-center text-[13px] text-adm-meta">Aún no hay actividad registrada.</p>
  </section>
</template>
