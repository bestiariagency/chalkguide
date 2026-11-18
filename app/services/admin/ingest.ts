import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { AdminRun, AdminSource, AdminToken, IngestHealth } from '~/utils/admin-ingest'
import { sourceWrite, type SourceForm } from '~/utils/admin-ingest-form'
import { guideSchema, unwrap, unwrapMaybe } from '../client'

type Client = SupabaseClient<Database>

const numbers = (raw: unknown): Record<string, number> => {
  if (!raw || typeof raw !== 'object') return {}
  return Object.fromEntries(Object.entries(raw as Record<string, unknown>).filter(([, v]) => typeof v === 'number')) as Record<string, number>
}

/** Collections of the last `days` days, the latest first. `errors` is plain text written by the routine. */
export async function fetchRuns(client: Client, days = 30): Promise<AdminRun[]> {
  const since = new Date(Date.now() - days * 86_400_000).toISOString()
  const rows = unwrap(await guideSchema(client).from('ingest_runs').select('*').gte('started_at', since).order('started_at', { ascending: false }).limit(200))
  return rows.map((r) => ({
    id: r.id,
    kind: r.kind,
    dryRun: r.dry_run,
    status: r.status,
    outsideWindow: r.outside_window,
    startedAt: r.started_at,
    finishedAt: r.finished_at,
    calls: r.calls,
    inserted: r.inserted,
    insertedEvents: r.inserted_events,
    insertedNews: r.inserted_news,
    wouldInsert: r.would_insert,
    duplicates: r.duplicates,
    duplicateRejected: r.duplicate_rejected,
    invalid: numbers(r.invalid),
    stats: numbers(r.stats),
    errors: r.errors,
  }))
}

/** Row `ingest` of `job_health` (the hourly check, J35); null when it never ran. */
export async function fetchIngestHealth(client: Client): Promise<IngestHealth | null> {
  const row = unwrapMaybe(await guideSchema(client).from('job_health').select('checked_at, status_code, details').eq('job', 'ingest').maybeSingle())
  if (!row) return null
  const d = (row.details && typeof row.details === 'object' ? row.details : {}) as Record<string, unknown>
  return {
    ok: row.status_code === 200,
    checkedAt: row.checked_at,
    lastOkAt: typeof d.last_ok_at === 'string' ? d.last_ok_at : null,
    alerts: Array.isArray(d.alerts) ? d.alerts.filter((a): a is string => typeof a === 'string') : [],
    tokenValidUntil: typeof d.token_valid_until === 'string' ? d.token_valid_until : null,
  }
}

/** End of the manual collection window (R1); null or past = closed. */
export async function fetchWindowUntil(client: Client): Promise<string | null> {
  const row = unwrapMaybe(await guideSchema(client).from('ingest_config').select('window_open_until').maybeSingle())
  return row?.window_open_until ?? null
}

export async function setIngestWindow(client: Client, open: boolean): Promise<void> {
  unwrap(await guideSchema(client).rpc('admin_set_ingest_window', { p_open: open }))
}

// Sources -----------------------------------------------------------------------------------------------
export async function fetchSources(client: Client): Promise<AdminSource[]> {
  const rows = unwrap(await guideSchema(client).rpc('admin_list_news_sources'))
  return rows.map((r) => ({
    id: r.id,
    name: r.name,
    domain: r.domain,
    url: r.url,
    kind: r.kind,
    scope: r.scope,
    lang: r.lang,
    instructions: r.instructions,
    trusted: r.trusted,
    active: r.active,
    lastSeenAt: r.last_seen_at,
    newsTotal: Number(r.news_total),
    newsPending: Number(r.news_pending),
    eventsTotal: Number(r.events_total),
    approvalRate: r.approval_rate == null ? null : Number(r.approval_rate),
  }))
}

export async function createSource(client: Client, form: SourceForm): Promise<void> {
  unwrap(await guideSchema(client).from('news_sources').insert(sourceWrite(form)).select('id').single())
}

export async function updateSource(client: Client, id: string, form: SourceForm): Promise<void> {
  unwrap(await guideSchema(client).from('news_sources').update(sourceWrite(form)).eq('id', id).select('id').single())
}

export async function setSourceActive(client: Client, id: string, active: boolean): Promise<void> {
  unwrap(await guideSchema(client).from('news_sources').update({ active }).eq('id', id).select('id').single())
}

/** Only a source without news or events (FK restrict): the others are deactivated. */
export async function deleteSource(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).from('news_sources').delete().eq('id', id).select('id').single())
}

// Tokens -------------------------------------------------------------------------------------------------
export async function fetchTokens(client: Client): Promise<AdminToken[]> {
  const rows = unwrap(await guideSchema(client).rpc('admin_list_ingest_tokens'))
  return rows.map((r) => ({
    id: r.id,
    label: r.label,
    hint: r.hint,
    status: r.status === 'revoked' ? 'revoked' : r.status === 'expired' ? 'expired' : 'active',
    createdAt: r.created_at,
    expiresAt: r.expires_at,
    lastUsedAt: r.last_used_at,
    revokedAt: r.revoked_at,
    runs: Number(r.runs_count),
  }))
}

/**
 * Creates a token. The server returns the plain text **once**: it goes straight to the caller and nowhere else (no state,
 * no log, no toast). The panel only ever keeps `hint`.
 */
export async function createToken(client: Client, label: string, expiresDays: number): Promise<string> {
  const result = unwrap(await guideSchema(client).rpc('admin_create_ingest_token', { p_label: label, p_expires_days: expiresDays })) as { token?: string }
  if (typeof result.token !== 'string') throw new Error('token_missing')
  return result.token
}

export async function revokeToken(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('admin_revoke_ingest_token', { p_id: id }))
}
