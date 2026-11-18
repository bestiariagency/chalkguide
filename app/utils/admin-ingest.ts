import type { Database } from '~/types/database.types'
import { addDays } from '~/utils/admin-dashboard'
import { madridParts, madridToIso } from '~/utils/admin-madrid'

export type RunStatus = Database['guide']['Enums']['ingest_run_status']
export type IngestKind = Database['guide']['Enums']['ingest_kind']

/** One collection («recogida», `ingest_runs`) as the panel reads it. */
export interface AdminRun {
  id: string
  kind: IngestKind
  dryRun: boolean
  status: RunStatus
  outsideWindow: boolean
  startedAt: string
  finishedAt: string | null
  calls: number
  inserted: number
  insertedEvents: number
  insertedNews: number
  wouldInsert: number
  duplicates: number
  duplicateRejected: number
  /** Rows the database did not accept, by reason (`invalid` of the run). */
  invalid: Record<string, number>
  /** Counters the routine reports when it finishes (`stats`, numbers only). */
  stats: Record<string, number>
  /** Plain text of the routine (≤ 4 KB). Shown by interpolation only (F1). */
  errors: string | null
}

export type RunChip = 'open' | 'ok' | 'warn' | 'fail' | 'abandoned' | 'revoked'

export const RUN_ROW_LIMIT = 40
export const RUN_CALL_LIMIT = 80

/** Warnings of a run (README §19.4): the caps, matches with rejected items, injection attempts, failed sources. */
export function runWarnings(r: AdminRun): string[] {
  const out: string[] = []
  const pending = r.stats.pending_next_run ?? 0
  if (r.inserted >= RUN_ROW_LIMIT || pending > 0) out.push(`Tope de ${RUN_ROW_LIMIT} filas alcanzado${pending ? `: ${pending} no entraron` : ''}.`)
  if (r.calls >= RUN_CALL_LIMIT) out.push(`Tope de ${RUN_CALL_LIMIT} llamadas alcanzado.`)
  if (r.duplicateRejected > 0) out.push(r.duplicateRejected === 1 ? '1 coincide con una noticia o un evento que rechazaste.' : `${r.duplicateRejected} coinciden con noticias o eventos que rechazaste.`)
  if ((r.stats.injection_attempts ?? 0) > 0) out.push(r.stats.injection_attempts === 1 ? '1 intento de instrucciones ocultas en una web. No se ejecutó.' : `${r.stats.injection_attempts} intentos de instrucciones ocultas en las webs. Ninguno se ejecutó.`)
  if ((r.stats.sources_failed ?? 0) > 0) out.push(r.stats.sources_failed === 1 ? '1 fuente no se pudo leer.' : `${r.stats.sources_failed} fuentes no se pudieron leer.`)
  if (r.outsideWindow) out.push('Empezó fuera de la ventana de recogida.')
  return out
}

/** Errors of a run: one per non-empty line of its text, or the `failed` counter when only that came. */
export function runErrorLines(r: AdminRun): string[] {
  return (r.errors ?? '').split('\n').map((l) => l.trim()).filter(Boolean)
}
export const runErrorCount = (r: AdminRun) => Math.max(runErrorLines(r).length, r.stats.failed ?? 0)

export function runChip(r: AdminRun): RunChip {
  if (r.status === 'open') return 'open'
  if (r.status === 'error') return 'fail'
  if (r.status === 'abandoned') return 'abandoned'
  if (r.status === 'revoked') return 'revoked'
  return runWarnings(r).length || runErrorCount(r) ? 'warn' : 'ok'
}

export const RUN_CHIPS: Record<RunChip, string> = { open: 'En curso', ok: 'Correcta', warn: 'Con avisos', fail: 'Fallida', abandoned: 'Abandonada', revoked: 'Revocada' }

/** Items found (events + news) when the routine reported them. */
export function runFound(r: AdminRun): number | null {
  const e = r.stats.events_found
  const n = r.stats.news_found
  return e == null && n == null ? null : (e ?? 0) + (n ?? 0)
}
/** New drafts; a dry run writes nothing, so it shows what it would have written. */
export const runNew = (r: AdminRun) => (r.dryRun ? r.wouldInsert : r.inserted)
export const runRejected = (r: AdminRun) => Object.values(r.invalid).reduce((sum, n) => sum + (Number(n) || 0), 0)

export function runDuration(r: AdminRun): string | null {
  if (!r.finishedAt) return null
  const seconds = Math.max(0, Math.round((Date.parse(r.finishedAt) - Date.parse(r.startedAt)) / 1000))
  return `${Math.floor(seconds / 60)} min ${String(seconds % 60).padStart(2, '0')} s`
}

export interface RunKpis {
  ok: number
  total: number
  created: number
  duplicates: number
}

/** KPIs of the last 30 days (dry runs and open ones do not count as drafts created). */
export function runKpis(runs: readonly AdminRun[]): RunKpis {
  const done = runs.filter((r) => r.status !== 'open')
  const real = runs.filter((r) => !r.dryRun)
  return {
    ok: done.filter((r) => r.status === 'ok').length,
    total: done.length,
    created: real.reduce((sum, r) => sum + r.insertedNews, 0),
    duplicates: runs.reduce((sum, r) => sum + r.duplicates, 0),
  }
}

// Health (job_health `ingest`) --------------------------------------------------------------------------
export interface IngestHealth {
  ok: boolean
  checkedAt: string | null
  lastOkAt: string | null
  alerts: string[]
  tokenValidUntil: string | null
}

const ALERTS: Record<string, string> = {
  abandoned: 'Hay recogidas que no se cerraron (abandonadas).',
  error: 'Hay recogidas con error esta semana.',
  duplicate_rejected: 'La rutina vuelve a proponer cosas que ya rechazaste.',
  no_active_token: 'No hay ningún token activo: la rutina no puede escribir.',
  token_expiring: 'Un token caduca en 5 días o menos.',
  outside_window: 'La rutina intentó recoger fuera de la ventana de recogida.',
}
export const alertText = (code: string) => ALERTS[code] ?? code

/** Whole days since an instant (Madrid midnight is not needed: the alert fires at 4 days). */
export const daysSince = (iso: string, now = Date.now()) => Math.floor((now - Date.parse(iso)) / 86_400_000)

// Tokens ---------------------------------------------------------------------------------------------------
export interface AdminToken {
  id: string
  label: string
  /** Last 4 characters: the panel never knows more of the token. */
  hint: string
  status: 'active' | 'expired' | 'revoked'
  createdAt: string
  expiresAt: string
  lastUsedAt: string | null
  revokedAt: string | null
  runs: number
}

/** The server accepts 1–30 days (J4). */
export const TOKEN_EXPIRY = [
  { value: '30', label: 'En 30 días (recomendado)' },
  { value: '14', label: 'En 14 días' },
  { value: '7', label: 'En 7 días' },
] as const
export const MAX_ACTIVE_TOKENS = 2

// Sources --------------------------------------------------------------------------------------------------
export interface AdminSource {
  id: string
  name: string
  domain: string
  url: string
  kind: IngestKind
  scope: Database['guide']['Enums']['news_scope']
  lang: string | null
  instructions: string | null
  trusted: boolean
  active: boolean
  lastSeenAt: string | null
  newsTotal: number
  newsPending: number
  eventsTotal: number
  approvalRate: number | null
}

export const SOURCE_KINDS: readonly { value: IngestKind; label: string }[] = [
  { value: 'events', label: 'Eventos' },
  { value: 'news', label: 'Noticias' },
  { value: 'both', label: 'Las dos' },
]
export const kindLabel = (kind: string) => SOURCE_KINDS.find((k) => k.value === kind)?.label ?? kind

export const SOURCE_LANGS = [
  { value: 'ca', label: 'Catalán' },
  { value: 'es', label: 'Español' },
  { value: 'en', label: 'Inglés' },
  { value: 'fr', label: 'Francés' },
  { value: 'it', label: 'Italiano' },
  { value: 'de', label: 'Alemán' },
  { value: 'other', label: 'Otro' },
] as const
export const langLabel = (lang: string | null) => SOURCE_LANGS.find((l) => l.value === lang)?.label ?? ''

// Schedule -----------------------------------------------------------------------------------------------
/** The routine runs on Mondays and Thursdays at 06:00 (Madrid). */
const RUN_DAYS = [1, 4]
const RUN_TIME = '06:00'

/** Next scheduled collection after `now` (ISO). */
export function nextRunAt(now = new Date()): string {
  const start = madridParts(now).date
  for (let i = 0; i < 8; i++) {
    const day = addDays(start, i)
    const parts = madridParts(madridToIso(day, '12:00'))
    const at = madridToIso(day, RUN_TIME)
    if (RUN_DAYS.includes(parts.weekday) && Date.parse(at) > now.getTime()) return at
  }
  return madridToIso(addDays(start, 7), RUN_TIME)
}

/** Runbook of the routine (token rotation). The panel does not serve repo docs: a link only exists with a configured https repo URL. */
export const RUNBOOK_PATH = 'docs/devops/f8-rutina.md'
export function runbookHref(repoUrl: string | undefined): string | null {
  const base = (repoUrl ?? '').trim().replace(/\/+$/, '')
  return /^https:\/\/[^\s/]+\/\S+$/.test(base) ? `${base}/blob/main/${RUNBOOK_PATH}` : null
}
