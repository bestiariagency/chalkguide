<script setup lang="ts">
import { Download, EyeOff, FileMinus, FilePen, FilePlus2, FileUp, GitCompareArrows, Send, ShieldAlert, Sparkles, Trash2, Undo2, Upload } from 'lucide-vue-next'
import type { Component } from 'vue'
import { NuxtLink } from '#components'
import type { ActivityRecord } from '~/utils/admin-activity'
import { activityHref, activityMeta, activitySegments } from '~/utils/admin-activity-text'

/** One entry of the feed: icon by kind, sentence with the entity as a link (if it still exists), second line, time. */
const props = defineProps<{ entry: ActivityRecord }>()
defineEmits<{ detail: [] }>()

const ICONS: Record<string, [Component, string]> = {
  insert: [FilePlus2, 'text-adm-meta'],
  update: [FilePen, 'text-adm-meta'],
  delete: [Trash2, 'text-adm-danger'],
  draft_publish: [Upload, 'text-adm-st-rev'],
  draft_discard: [GitCompareArrows, 'text-adm-meta'],
  unpublish: [FileMinus, 'text-adm-meta'],
  export: [Download, 'text-adm-fg'],
  import: [FileUp, 'text-adm-meta'],
  import_undo: [Undo2, 'text-adm-meta'],
}
const icon = computed<[Component, string]>(() => {
  const e = props.entry
  if (e.actor === 'system' && e.group === 'pub') return [Send, 'text-adm-ok']
  if (e.actor === 'agent') return [Sparkles, 'text-adm-meta']
  if (e.group === 'mod' && e.details.to === 'hidden') return [EyeOff, 'text-adm-meta']
  return ICONS[e.action] ?? [FilePen, 'text-adm-meta']
})
const isExport = computed(() => props.entry.action === 'export')
const href = computed(() => activityHref(props.entry))
const gone = computed(() => !isExport.value && !!props.entry.label && !props.entry.target.exists && props.entry.action !== 'delete')
const personal = computed(() => isExport.value && props.entry.details.personal_data === true)
const meta = computed(() => activityMeta(props.entry))
const segments = computed(() => activitySegments(props.entry))
</script>

<template>
  <li :class="['flex gap-3 px-4 py-3', isExport && 'bg-adm-side']">
    <span :class="['grid size-7 flex-none place-items-center rounded-md border border-adm-line bg-adm-elev [&_svg]:size-4', icon[1]]"><component :is="icon[0]" aria-hidden="true" /></span>
    <div class="min-w-0 flex-1 text-sm">
      <p class="break-words">
        <template v-for="(seg, i) in segments" :key="i">
          <component :is="href ? NuxtLink : 'b'" v-if="seg.label" :to="href ?? undefined" :class="href ? 'font-medium underline underline-offset-2 hover:text-adm-meta' : 'font-medium'">{{ entry.label }}</component>
          <b v-else-if="seg.b" class="font-semibold">{{ seg.t }}</b>
          <template v-else>{{ seg.t }}</template>
        </template>
        <span v-if="gone" class="text-adm-muted"> · ya no existe</span>
      </p>
      <p v-if="meta.length || personal" class="mt-0.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-adm-meta">
        <span v-for="line in meta" :key="line">{{ line }}</span>
        <span v-if="personal" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><ShieldAlert aria-hidden="true" />Datos personales</span>
      </p>
    </div>
    <div class="flex-none text-right">
      <p class="text-xs text-adm-muted tabular-nums"><time :datetime="entry.occurredAt" :title="adminDateTime(entry.occurredAt)">{{ hhmm(entry.occurredAt) }}</time></p>
      <button v-if="isExport" type="button" class="mt-1 rounded text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11" @click="$emit('detail')">Detalle<span class="sr-only"> de la exportación de las {{ hhmm(entry.occurredAt) }}</span></button>
    </div>
  </li>
</template>
