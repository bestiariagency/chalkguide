<script setup lang="ts">
import { ChevronDown, CircleX, OctagonAlert, TriangleAlert } from 'lucide-vue-next'
import type { ImportIssue, ReviewRow } from '~/utils/admin-import-report'
import { LEVEL_LABEL, blockerList, formatChange, issueText } from '~/utils/admin-import-texts'

/**
 * Errors, "bloqueará publicar" and warnings of a row (README §13.3): one line per problem with icon, level for screen
 * readers (never colour alone), column letter, field and text; then "N cambios" with before -> after.
 */
const props = defineProps<{ row: ReviewRow; letters: Record<string, string>; names: Record<string, string> }>()
const issues = computed(() => {
  const all = props.row.report.issues
  return [...all.filter((i) => i.level === 'error'), ...all.filter((i) => i.level === 'warning')]
})
const blockers = computed(() => (props.row.report.action === 'error' ? [] : blockerList(props.row.report.blockers ?? [])))
const letterOf = (issue: ImportIssue) => (issue.column ? (props.letters[issue.column] ?? props.letters[issue.column.split('.')[0]!]) : undefined)
const nameOf = (issue: ImportIssue) => (issue.column ? (props.names[issue.column] ?? props.names[issue.column.split('.')[0]!]) : undefined)
const changes = computed(() => props.row.report.changes ?? [])
const empty = computed(() => !issues.value.length && !blockers.value.length && !changes.value.length)
</script>

<template>
  <div class="grid gap-1.5 text-[13px] leading-[18px]">
    <p v-if="empty" class="text-adm-muted">—</p>
    <p v-for="(issue, i) in issues.filter((i) => i.level === 'error')" :key="`e${i}`" class="flex items-start gap-1.5">
      <CircleX class="mt-0.5 size-3.5 flex-none text-adm-danger" aria-hidden="true" />
      <span><span class="sr-only">{{ LEVEL_LABEL.error }}: </span>
        <span v-if="letterOf(issue)" class="mr-1 inline-grid h-[18px] min-w-[22px] place-items-center rounded-[3px] bg-adm-subtle px-1 align-middle font-mono text-[11px] text-adm-meta" :title="`Columna ${letterOf(issue)}`">{{ letterOf(issue) }}</span>
        <template v-if="issue.column"><strong v-if="nameOf(issue)" class="font-medium" :title="issue.column">{{ nameOf(issue) }}</strong><code v-else class="rounded-[3px] bg-adm-subtle px-1 font-mono text-xs break-all">{{ issue.column }}</code>{{ ' ' }}</template>{{ issueText(issue) }}</span>
    </p>
    <p v-if="blockers.length" class="flex items-start gap-1.5">
      <OctagonAlert class="mt-0.5 size-3.5 flex-none text-adm-danger" aria-hidden="true" />
      <span><span class="sr-only">{{ LEVEL_LABEL.blocker }}: </span>No se podrá publicar hasta que tenga {{ blockers.join('; ') }}.</span>
    </p>
    <p v-for="(issue, i) in issues.filter((i) => i.level === 'warning')" :key="`w${i}`" class="flex items-start gap-1.5">
      <TriangleAlert class="mt-0.5 size-3.5 flex-none text-adm-warn-icon" aria-hidden="true" />
      <span><span class="sr-only">{{ LEVEL_LABEL.warning }}: </span>
        <span v-if="letterOf(issue)" class="mr-1 inline-grid h-[18px] min-w-[22px] place-items-center rounded-[3px] bg-adm-subtle px-1 align-middle font-mono text-[11px] text-adm-meta" :title="`Columna ${letterOf(issue)}`">{{ letterOf(issue) }}</span>
        <template v-if="issue.column"><strong v-if="nameOf(issue)" class="font-medium" :title="issue.column">{{ nameOf(issue) }}</strong><code v-else class="rounded-[3px] bg-adm-subtle px-1 font-mono text-xs break-all">{{ issue.column }}</code>{{ ' ' }}</template>{{ issueText(issue) }}</span>
    </p>
    <details v-if="changes.length" class="group">
      <summary class="inline-flex cursor-pointer list-none items-center gap-1 text-xs font-medium text-adm-st-rev marker:hidden [&::-webkit-details-marker]:hidden">
        {{ changes.length }} {{ changes.length === 1 ? 'cambio' : 'cambios' }}<ChevronDown class="size-3 transition-transform duration-150 motion-reduce:transition-none group-open:rotate-180" aria-hidden="true" />
      </summary>
      <ul class="mt-1.5 grid gap-1">
        <li v-for="change in changes" :key="change.column" class="grid gap-0.5">
          <code class="font-mono text-xs text-adm-meta">{{ change.column }}</code>
          <span class="flex flex-wrap items-baseline gap-1">
            <del class="rounded-[3px] bg-adm-diff-del px-1 break-all">{{ formatChange(change.before) }}</del>
            <span aria-hidden="true">→</span><span class="sr-only">cambia a</span>
            <ins class="rounded-[3px] bg-adm-diff-add px-1 no-underline break-all">{{ formatChange(change.after) }}</ins>
          </span>
        </li>
      </ul>
    </details>
  </div>
</template>
