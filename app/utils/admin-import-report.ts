/** Report of `admin_import_items` (audit F6.15b, "Implementación") and what the review derives from it. */
export interface ImportIssue {
  column?: string
  code: string
  level: 'error' | 'warning'
  params?: Record<string, unknown>
  /** Position inside `gallery`. */
  index?: number
}

export interface ImportChange {
  column: string
  before?: unknown
  after?: unknown
}

export type ImportAction = 'created' | 'updated' | 'drafted' | 'unchanged' | 'error'

export interface ImportRowReport {
  row: number
  key?: string
  action: ImportAction
  item_id?: string
  published?: boolean
  hidden?: boolean
  blockers?: string[]
  issues: ImportIssue[]
  changes?: ImportChange[]
}

export interface ImportSummary {
  rows: number
  created: number
  updated: number
  drafted: number
  unchanged: number
  errors: number
  warnings: number
}

export interface ImportReport {
  mode: 'dry_run' | 'apply'
  applied: boolean
  stale: boolean
  noop?: boolean
  hash: string
  batch_id?: string | null
  elapsed_ms?: number
  summary: ImportSummary
  rows: ImportRowReport[]
}

/** A row of the review: what the file said and what the server answered (or the client, if it never got that far). */
export interface ReviewRow {
  row: number
  name: string
  slug: string
  /** Name of the cover file as it came in the file (empty = none). */
  cover: string
  report: ImportRowReport
}

export type ReviewFilter = 'all' | 'created' | 'changed' | 'unchanged' | 'warnings' | 'errors'

/** Rows that carry a warning or a publish blocker but are not errors. */
export const hasNotice = (row: ReviewRow) => row.report.action !== 'error' && (row.report.issues.some((i) => i.level === 'warning') || (row.report.blockers?.length ?? 0) > 0)

export function matchesReviewFilter(row: ReviewRow, filter: ReviewFilter): boolean {
  const action = row.report.action
  switch (filter) {
    case 'all': return true
    case 'created': return action === 'created'
    case 'changed': return action === 'updated' || action === 'drafted'
    case 'unchanged': return action === 'unchanged'
    case 'warnings': return hasNotice(row)
    case 'errors': return action === 'error'
  }
}

export interface ReviewCounts {
  all: number
  created: number
  changed: number
  drafted: number
  unchanged: number
  warnings: number
  blocked: number
  errors: number
}

export function reviewCounts(rows: readonly ReviewRow[]): ReviewCounts {
  const count = (filter: ReviewFilter) => rows.filter((r) => matchesReviewFilter(r, filter)).length
  return {
    all: rows.length,
    created: count('created'),
    changed: count('changed'),
    drafted: rows.filter((r) => r.report.action === 'drafted').length,
    unchanged: count('unchanged'),
    warnings: count('warnings'),
    blocked: rows.filter((r) => r.report.action !== 'error' && (r.report.blockers?.length ?? 0) > 0).length,
    errors: count('errors'),
  }
}

export type ReviewChip = { label: string; tone: 'acc' | 'neutral' | 'hidden' | 'rev' | 'danger'; icon?: 'plus' | 'branch' }

/** The chip of "Qué pasará" (README §13.3). */
export function reviewChip(report: ImportRowReport): ReviewChip {
  switch (report.action) {
    case 'created': return { label: 'Nueva', tone: 'acc', icon: 'plus' }
    case 'drafted': return { label: 'Publicada · a borrador', tone: 'rev', icon: 'branch' }
    case 'updated': return report.hidden ? { label: 'Actualiza · sigue oculta', tone: 'hidden' } : { label: 'Actualiza borrador', tone: 'neutral' }
    case 'unchanged': return { label: 'Sin cambios', tone: 'neutral' }
    case 'error': return { label: 'No se importa', tone: 'danger' }
  }
}

export interface ImportTotals {
  created: number
  updated: number
  drafted: number
  unchanged: number
  withoutCover: number
  ready: number
  ids: string[]
}

/** Totals of what was written, from the reports of the applied chunks. */
export function resultTotals(reports: readonly ImportReport[]): ImportTotals {
  const sum = (key: keyof ImportSummary) => reports.reduce((total, r) => total + r.summary[key], 0)
  const rows = reports.flatMap((r) => r.rows)
  return {
    created: sum('created'),
    updated: sum('updated'),
    drafted: sum('drafted'),
    unchanged: sum('unchanged'),
    withoutCover: rows.filter((r) => (r.action === 'created' || r.action === 'updated') && !r.published && r.blockers?.includes('cover')).length,
    ready: rows.filter((r) => (r.action === 'created' || r.action === 'updated') && !r.published && !r.hidden && (r.blockers?.length ?? 0) === 0).length,
    ids: rows.filter((r) => r.item_id && r.action !== 'unchanged' && r.action !== 'error').map((r) => r.item_id!),
  }
}
