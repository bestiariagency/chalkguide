import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { ConsentText, Subscriber, SubscriberDetail, SubscriberEvent, SubscriberList, SubscribersSummary, SubscriberStatus, SubscriberView } from '~/utils/admin-subscribers'
import { emptyRelated, type ConsentPurpose, type RelatedStatus, type SubscriberRelated } from '~/utils/admin-subscribers-related'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>
type Raw = Record<string, unknown>

/**
 * Suscriptores del panel (F6.14, D35). The table is not readable by the admin (42501): everything goes through
 * the RPCs, which never return tokens or `user_id`. The JSON is read defensively and mapped to the panel's types.
 */
const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {})
const str = (v: unknown): string | null => (typeof v === 'string' && v ? v : null)
const num = (v: unknown, fallback = 0): number => (typeof v === 'number' && Number.isFinite(v) ? v : fallback)
const counts = (v: unknown): Record<string, number> => Object.fromEntries(Object.entries(obj(v)).map(([k, n]) => [k, num(n)]))

const RELATED_STATES: readonly string[] = ['none', 'pending', 'granted', 'withdrawn']
function toRelated(r: Raw): SubscriberRelated {
  const status = str(r.related_status)
  if (!status || !RELATED_STATES.includes(status)) return emptyRelated()
  return {
    status: status as RelatedStatus,
    consentAt: str(r.related_consent_at),
    source: str(r.related_consent_source),
    version: typeof r.related_consent_version === 'number' ? r.related_consent_version : null,
    confirmedAt: str(r.related_confirmed_at),
    withdrawnAt: str(r.related_withdrawn_at),
    withdrawSource: str(r.related_withdraw_source),
  }
}

function toSubscriber(raw: unknown): Subscriber {
  const r = obj(raw)
  return {
    id: String(r.id),
    email: str(r.email) ?? '',
    status: (str(r.status) ?? 'pending') as SubscriberStatus,
    locale: r.locale === 'en' ? 'en' : 'es',
    source: str(r.consent_source) ?? '',
    version: num(r.consent_version),
    consentAt: str(r.consent_at) ?? '',
    confirmedAt: str(r.confirmed_at),
    unsubscribedAt: str(r.unsubscribed_at),
    unsubscribeSource: str(r.unsubscribe_source),
    unsubscribeReason: str(r.unsubscribe_reason),
    hasAccount: r.has_account === true,
    expiresAt: str(r.expires_at),
    anonymizeAt: str(r.anonymize_at),
    related: toRelated(r),
  }
}

export async function fetchSubscribers(client: Client, args: Database['guide']['Functions']['admin_list_subscribers']['Args']): Promise<SubscriberList> {
  const r = obj(unwrap(await guideSchema(client).rpc('admin_list_subscribers', args)))
  const tabs = counts(r.tab_counts)
  const view = (key: SubscriberView) => tabs[key] ?? 0
  const related = counts(r.related_counts)
  return {
    total: num(r.total_count),
    tabCounts: { active: view('active'), pending: view('pending'), unsubscribed: view('unsubscribed'), all: view('all') },
    sourceCounts: counts(r.source_counts),
    versionCounts: counts(r.version_counts),
    relatedCounts: { none: related.none ?? 0, pending: related.pending ?? 0, granted: related.granted ?? 0, withdrawn: related.withdrawn ?? 0 },
    rows: Array.isArray(r.rows) ? r.rows.map(toSubscriber) : [],
  }
}

export async function fetchSubscribersSummary(client: Client): Promise<SubscribersSummary> {
  const r = obj(unwrap(await guideSchema(client).rpc('admin_subscribers_summary')))
  return {
    active: num(r.active),
    active30d: num(r.active_confirmed_30d),
    pending: num(r.pending),
    expired: num(r.expired),
    unsubscribed: num(r.unsubscribed) + num(r.bounced),
    unsubscribed30d: num(r.unsubscribed_30d),
    signups30d: num(r.signups_30d),
    signups30dConfirmed: num(r.signups_30d_confirmed),
    confirmRate: typeof r.confirm_rate_30d === 'number' ? r.confirm_rate_30d : null,
    erased: num(r.erased),
  }
}

function toEvent(raw: unknown): SubscriberEvent {
  const r = obj(raw)
  return {
    at: str(r.occurred_at) ?? '',
    event: str(r.event) ?? '',
    source: str(r.source),
    version: typeof r.consent_version === 'number' ? r.consent_version : null,
    locale: str(r.locale),
    page: str(r.page),
    actor: str(r.actor),
    reason: str(r.reason),
    purpose: (r.purpose === 'related_products' ? 'related_products' : 'newsletter') as ConsentPurpose,
  }
}

function toTexts(raw: unknown): Record<number, ConsentText> {
  const texts: Record<number, ConsentText> = {}
  for (const [version, value] of Object.entries(obj(raw))) {
    const t = obj(value)
    texts[Number(version)] = { es: str(t.text_es), en: str(t.text_en), preserved: t.preserved !== false, validFrom: str(t.valid_from), validTo: str(t.valid_to) }
  }
  return texts
}

export async function fetchSubscriber(client: Client, id: string): Promise<SubscriberDetail> {
  const r = obj(unwrap(await guideSchema(client).rpc('admin_get_subscriber', { p_id: id })))
  const s = obj(r.subscriber)
  return {
    subscriber: { ...toSubscriber(s), consentPage: str(s.consent_page) },
    events: Array.isArray(r.events) ? r.events.map(toEvent) : [],
    texts: toTexts(r.consent_texts),
    relatedTexts: toTexts(r.related_consent_texts),
  }
}

/** All or nothing: if any id is invalid nobody is unsubscribed (P0002 / 22023). */
export async function unsubscribeSubscribers(client: Client, ids: string[], reason: string): Promise<number> {
  const r = obj(unwrap(await guideSchema(client).rpc('admin_unsubscribe_subscribers', { p_ids: ids, p_reason: reason })))
  return num(r.unsubscribed)
}

/** RGPD art. 17: the typed email must match (22023 otherwise). Not undoable. */
export async function eraseSubscriber(client: Client, id: string, emailConfirm: string, reason: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('admin_erase_subscriber', { p_id: id, p_email_confirm: emailConfirm, p_reason: reason }))
}

/** D66: withdraws the related-products consent only (one by one); the newsletter does not change. 22023 = nothing to withdraw. */
export async function withdrawRelated(client: Client, id: string, reason: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('admin_withdraw_related', { p_id: id, p_reason: reason }))
}
