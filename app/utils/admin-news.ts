import type { Database } from '~/types/database.types'

export type NewsStatus = Database['guide']['Enums']['news_status']
export type NewsScope = Database['guide']['Enums']['news_scope']
export type NewsOrigin = Database['guide']['Enums']['event_source']
export type NewsWarning = 'low_confidence' | 'high_similarity' | 'possible_duplicate'

/** `agent_meta` of a news draft (F8): `{confidence, note, excerpt, found_at, inferred[], duplicate_of}`; `similarity` is a column. */
export interface NewsAgent {
  confidence: number
  note: string | null
  excerpt: string | null
  foundAt: string | null
  /** Fields the agent guessed: `title_en | summary_en | category | published_on | source_name`. */
  inferred: string[]
  duplicateOf: string | null
}

/** One news item as the panel reads it (`admin_list_news`; provenance only arrives through that RPC). */
export interface AdminNews {
  id: string
  slug: string
  status: NewsStatus
  source: NewsOrigin
  titleEs: string
  titleEn: string | null
  summaryEs: string
  summaryEn: string | null
  noteEs: string | null
  noteEn: string | null
  categoryId: string
  categoryKey: string
  scope: NewsScope
  tags: string[]
  sourceName: string
  sourceUrl: string
  sourceTitle: string | null
  sourcePublishedOn: string | null
  sourceLang: string | null
  sourceId: string | null
  sourceTrusted: boolean | null
  sourceApprovalRate: number | null
  mediaId: string | null
  imageLicense: string | null
  imageCredit: string | null
  runId: string | null
  agent: NewsAgent | null
  similarity: number | null
  warnings: NewsWarning[]
  rejectReason: string | null
  indexable: boolean
  indexableEn: boolean
  hasEn: boolean
  publishedAt: string | null
  createdAt: string
  updatedAt: string
}

export interface NewsCategory {
  id: string
  key: string
  labelEs: string
  labelEn: string
  sortOrder: number
  active: boolean
}

export interface NewsSummary {
  pending: number
  pendingAgent: number
  pendingWarnings: number
  published: number
  publishedIndexable: number
  publishedNoindex: number
  rejected: number
  total: number
  lastRun: { id: string; startedAt: string; finishedAt: string | null; status: string; dryRun: boolean; insertedNews: number; insertedEvents: number; duplicates: number } | null
  /** `job_health` of `ingest`: null when never checked. */
  health: { ok: boolean; checkedAt: string | null } | null
}

// Views and filters ------------------------------------------------------------------------------
export type NewsView = 'revisar' | 'publicadas' | 'rechazadas' | 'todas'
export const NEWS_VIEWS: readonly { value: NewsView; label: string }[] = [
  { value: 'revisar', label: 'Por revisar' },
  { value: 'publicadas', label: 'Publicadas' },
  { value: 'rechazadas', label: 'Rechazadas' },
  { value: 'todas', label: 'Todas' },
]
export const newsViewOf = (value: unknown): NewsView | undefined => NEWS_VIEWS.find((v) => v.value === value)?.value
export const statusOfView = (view: NewsView): NewsStatus | undefined => ({ revisar: 'draft', publicadas: 'published', rechazadas: 'rejected', todas: undefined })[view] as NewsStatus | undefined

export interface NewsFilters {
  search: string
  /** Category keys. */
  categories: string[]
  scope: '' | NewsScope
  /** Source ids. */
  sources: string[]
  /** Run id. */
  run: string
}
export const emptyNewsFilters = (): NewsFilters => ({ search: '', categories: [], scope: '', sources: [], run: '' })
export const hasNewsFilters = (f: NewsFilters) => !!(f.search.trim() || f.categories.length || f.scope || f.sources.length || f.run)

export const ADMIN_NEWS_SCOPES: readonly { value: NewsScope; label: string }[] = [
  { value: 'cat', label: 'Cataluña' },
  { value: 'es', label: 'España' },
  { value: 'intl', label: 'Intl.' },
]
export const scopeLabel = (scope: string) => ADMIN_NEWS_SCOPES.find((s) => s.value === scope)?.label ?? scope

/** Reasons of `reject_news` (`null` = sin motivo). */
export const NEWS_REJECT_REASONS = [
  { value: 'duplicate', label: 'Duplicada' },
  { value: 'not_climbing', label: 'No es de escalada' },
  { value: 'outside_area', label: 'Fuera de alcance' },
  { value: 'not_relevant', label: 'Poco relevante' },
  { value: 'wrong_data', label: 'Datos incorrectos' },
  { value: 'unreliable_source', label: 'Fuente poco fiable' },
] as const
export const newsReasonLabel = (reason: string | null) => NEWS_REJECT_REASONS.find((r) => r.value === reason)?.label ?? 'Sin motivo'

// Warnings -----------------------------------------------------------------------------------------
export const HIGH_SIMILARITY = 0.35
export const similarityPercent = (s: number | null) => (s == null ? null : Math.round(s * 100))

/** Text of a warning; `news` gives the numbers («Confianza baja (0,58)»). */
export function warningText(warning: NewsWarning, news: Pick<AdminNews, 'agent' | 'similarity'>): string {
  if (warning === 'low_confidence') return `Confianza baja${news.agent ? ` (${news.agent.confidence.toFixed(2).replace('.', ',')})` : ''}`
  if (warning === 'high_similarity') return `Parecido alto con la fuente${news.similarity != null ? ` (${similarityPercent(news.similarity)} %)` : ''}`
  return 'Posible duplicado'
}

export const hasWarnings = (n: Pick<AdminNews, 'warnings'>) => n.warnings.length > 0

// Indexing (D73 / D79) -----------------------------------------------------------------------------
/** «Nota de Xavi» of at least this many words makes the card indexable (the database computes `indexable` the same way). */
export const NOTE_MIN_WORDS = 60
export const wordCount = (text: string) => (text.trim() ? text.trim().split(/\s+/).length : 0)

/** `inferred` keys that map to a field of the editor. */
export const newsInferred = (n: Pick<AdminNews, 'agent'>, key: string) => !!n.agent?.inferred.includes(key)

export const NEWS_LIMITS = { title: 140, summary: 600, note: 600, tags: 10 } as const

export const IMAGE_LICENSES = [
  { value: 'own', label: 'Propia' },
  { value: 'permission', label: 'Cedida con permiso' },
  { value: 'cc-by-4.0', label: 'CC BY 4.0' },
  { value: 'cc-by-sa-4.0', label: 'CC BY-SA 4.0' },
  { value: 'cc0', label: 'CC0' },
] as const

/** Splits a selection for the batch dialog: those without warnings go straight through. */
export function splitByWarnings<T extends Pick<AdminNews, 'warnings'>>(rows: readonly T[]): { clean: T[]; warned: T[] } {
  return { clean: rows.filter((r) => !hasWarnings(r)), warned: rows.filter(hasWarnings) }
}

/** Facets of the filter menus, counted over the rows the server returned (before the category and source filters). */
export function facetCounts<T>(rows: readonly T[], key: (row: T) => string | null): Map<string, number> {
  const counts = new Map<string, number>()
  for (const row of rows) {
    const k = key(row)
    if (k) counts.set(k, (counts.get(k) ?? 0) + 1)
  }
  return counts
}

export function applyLocalFilters(rows: readonly AdminNews[], f: Pick<NewsFilters, 'categories' | 'sources'>): AdminNews[] {
  return rows.filter((r) => (!f.categories.length || f.categories.includes(r.categoryKey)) && (!f.sources.length || (!!r.sourceId && f.sources.includes(r.sourceId))))
}

// Live similarity (the same idea as pg_trgm: shared trigrams over all trigrams) -----------------------------
function trigrams(text: string): Set<string> {
  const grams = new Set<string>()
  const words = text.toLowerCase().normalize('NFC').split(/[^\p{L}\p{N}]+/u).filter(Boolean)
  for (const word of words) {
    const padded = `  ${word} `
    for (let i = 0; i + 3 <= padded.length; i++) grams.add(padded.slice(i, i + 3))
  }
  return grams
}

/** 0–1 similarity between the summary being written and the excerpt the agent read; `null` when there is nothing to compare. */
export function liveSimilarity(summary: string, excerpt: string | null | undefined): number | null {
  if (!excerpt || !summary.trim()) return null
  const a = trigrams(summary)
  const b = trigrams(excerpt)
  if (!a.size || !b.size) return null
  let shared = 0
  for (const g of a) if (b.has(g)) shared++
  return shared / (a.size + b.size - shared)
}
