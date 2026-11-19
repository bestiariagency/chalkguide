import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { parsableDate } from '~/utils/admin-dates'
import type { EventType } from '~/types/domain'
import type { AdminEvent, AgentMeta, EventQuery, EventsSummary, EventStatus } from '~/utils/admin-events'
import type { EventInsert, EventWrite } from '~/utils/admin-events-form'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>
type Row = Database['guide']['Functions']['admin_list_events']['Returns'][number]

const PAGE = 200
const MAX_PAGES = 5

/** `agent_meta` arrives as free JSON: read only what the UI knows and ignore the rest. */
function toAgent(raw: unknown): AgentMeta | null {
  if (!raw || typeof raw !== 'object') return null
  const m = raw as Record<string, unknown>
  const text = (v: unknown) => (typeof v === 'string' && v.trim() ? v : null)
  return {
    confidence: typeof m.confidence === 'number' ? m.confidence : 0,
    note: text(m.note),
    excerpt: text(m.excerpt),
    // The DB only checks the prefix of `found_at`: anything Date cannot read would throw when formatted (Intl «Invalid time value»).
    foundAt: parsableDate(text(m.found_at)),
    inferred: Array.isArray(m.inferred) ? m.inferred.filter((x): x is string => typeof x === 'string') : [],
    duplicateOf: text(m.duplicate_of),
  }
}

function toEvent(row: Row): AdminEvent {
  return {
    id: row.id,
    status: row.status,
    source: row.source,
    type: row.event_type as EventType,
    titleEs: row.title_es,
    titleEn: row.title_en,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    allDay: row.all_day,
    locationText: row.location_text,
    url: row.url,
    priceText: row.price_text,
    itemId: row.item_id,
    itemName: row.item_name,
    itemSlug: row.item_slug,
    itemPublished: row.item_published === true,
    sourceUrl: row.source_url,
    agent: toAgent(row.agent_meta),
    runId: row.run_id,
    runStartedAt: row.run_started_at,
    duplicate: row.duplicate_of ? { id: row.duplicate_of, status: row.duplicate_of_status } : null,
    rejectReason: row.reject_reason,
    hasEn: row.has_en === true,
    isPast: row.is_past === true,
    approvedAt: row.approved_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  }
}

/** Every event of a query (the agenda is small: a handful of 200-row pages at most). */
export async function fetchEvents(client: Client, q: EventQuery): Promise<AdminEvent[]> {
  const rows: AdminEvent[] = []
  for (let page = 0; page < MAX_PAGES; page++) {
    const batch = unwrap(
      await guideSchema(client).rpc('admin_list_events', {
        p_status: q.status,
        p_source: q.source,
        p_when: q.when,
        p_from: q.from,
        p_to: q.to,
        p_item_id: q.itemId,
        p_event_types: q.types?.length ? q.types : undefined,
        p_query: q.search?.trim() || undefined,
        p_sort: q.sort,
        p_limit: PAGE,
        p_offset: page * PAGE,
      }),
    )
    rows.push(...batch.map(toEvent))
    if (!batch.length || rows.length >= Number(batch[0]?.total_count ?? 0)) break
  }
  return rows
}

export async function fetchEvent(client: Client, id: string): Promise<AdminEvent | null> {
  const rows = unwrap(await guideSchema(client).rpc('admin_list_events', { p_id: id, p_limit: 1 }))
  return rows[0] ? toEvent(rows[0]) : null
}

/** Counters of the tabs, the menu badge and the type filter, in a single call. */
export async function fetchEventsSummary(client: Client): Promise<EventsSummary> {
  const s = unwrap(await guideSchema(client).rpc('admin_events_summary')) as Record<string, unknown>
  const num = (key: string) => Number(s[key] ?? 0)
  return {
    badge: num('badge'),
    pending: num('pending'),
    pendingAgent: num('pending_agent'),
    pendingPast: num('pending_past'),
    upcoming: num('upcoming'),
    cancelledUpcoming: num('cancelled_upcoming'),
    pastPublished: num('past_published'),
    rejected: num('rejected'),
    total: num('total'),
    byType: (s.by_type as Record<string, number> | undefined) ?? {},
  }
}

export interface GymOption {
  id: string
  name: string
  slug: string
}

/** Published gyms only: the site links the place to `climbing-gyms-slug`. */
export async function fetchGymOptions(client: Client): Promise<GymOption[]> {
  return unwrap(await guideSchema(client).from('items').select('id, name, slug').eq('category', 'gym').eq('published', true).order('name'))
}

/** New manual event, as a draft or already approved. Returns its id. */
export async function createEvent(client: Client, write: EventInsert, status: 'draft' | 'approved'): Promise<string> {
  const row = unwrap(await guideSchema(client).from('events').insert({ ...write, status }).select('id').single())
  return row.id
}

export async function updateEvent(client: Client, id: string, write: EventWrite): Promise<void> {
  unwrap(await guideSchema(client).from('events').update(write).eq('id', id).select('id').single())
}

/** Drafts and rejected ones only: a live event is withdrawn or cancelled first (PT423). */
export async function deleteEvent(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).from('events').delete().eq('id', id).select('id').single())
}

export async function approveEvent(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('approve_event', { p_id: id }))
}

/** `reason` null = sin motivo. */
export async function rejectEvent(client: Client, id: string, reason: string | null): Promise<void> {
  unwrap(await guideSchema(client).rpc('reject_event', { p_id: id, p_reason: reason ?? undefined }))
}

/** Back to a draft: Retirar, Recuperar and the "Deshacer" of approve/reject. */
export async function reopenEvent(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('reopen_event', { p_id: id }))
}

/** approved → cancelled («Marcar como cancelado») and cancelled → approved («Volver a la agenda»). */
export async function setEventStatus(client: Client, id: string, status: EventStatus): Promise<void> {
  unwrap(await guideSchema(client).rpc('set_event_status', { p_id: id, p_status: status }))
}

export interface BatchResult {
  ok: string[]
  failed: { id: string; code: string; message: string }[]
}

/** Several events at once; every id goes in its own transaction, so a failure does not undo the rest. */
export async function setEventsStatus(client: Client, ids: string[], status: EventStatus, reason?: string | null): Promise<BatchResult> {
  const r = unwrap(await guideSchema(client).rpc('set_events_status', { p_ids: ids, p_status: status, p_reject_reason: reason ?? undefined })) as {
    ok?: { id?: string }[]
    failed?: BatchResult['failed']
  }
  return { ok: (r.ok ?? []).map((x) => String(x.id ?? '')).filter(Boolean), failed: r.failed ?? [] }
}
