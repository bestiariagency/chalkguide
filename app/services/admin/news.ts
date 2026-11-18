import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { AdminNews, NewsAgent, NewsCategory, NewsScope, NewsStatus, NewsSummary, NewsWarning } from '~/utils/admin-news'
import type { NewsForm, RelatedKind, RelatedLink } from '~/utils/admin-news-form'
import { newsInsert, newsWrite } from '~/utils/admin-news-form'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>
type Row = Database['guide']['Functions']['admin_list_news']['Returns'][number]

const PAGE = 200
const MAX_PAGES = 5

/** `agent_meta` arrives as free JSON: read only what the UI knows and ignore the rest. */
function toAgent(raw: unknown): NewsAgent | null {
  if (!raw || typeof raw !== 'object') return null
  const m = raw as Record<string, unknown>
  const text = (v: unknown) => (typeof v === 'string' && v.trim() ? v : null)
  return {
    confidence: typeof m.confidence === 'number' ? m.confidence : 0,
    note: text(m.note),
    excerpt: text(m.excerpt),
    foundAt: text(m.found_at),
    inferred: Array.isArray(m.inferred) ? m.inferred.filter((x): x is string => typeof x === 'string') : [],
    duplicateOf: text(m.duplicate_of),
  }
}

function toNews(r: Row): AdminNews {
  return {
    id: r.id,
    slug: r.slug,
    status: r.status,
    source: r.source,
    titleEs: r.title_es,
    titleEn: r.title_en,
    summaryEs: r.summary_es,
    summaryEn: r.summary_en,
    noteEs: r.author_note_es,
    noteEn: r.author_note_en,
    categoryId: r.category_id,
    categoryKey: r.category_key,
    scope: r.scope,
    tags: r.tags ?? [],
    sourceName: r.source_name,
    sourceUrl: r.source_url,
    sourceTitle: r.source_title,
    sourcePublishedOn: r.source_published_on,
    sourceLang: r.source_lang,
    sourceId: r.source_id,
    sourceTrusted: r.source_trusted,
    sourceApprovalRate: r.source_approval_rate == null ? null : Number(r.source_approval_rate),
    mediaId: r.media_id,
    imageLicense: r.image_license,
    imageCredit: r.image_credit,
    runId: r.run_id,
    agent: toAgent(r.agent_meta),
    similarity: r.similarity,
    warnings: (r.warnings ?? []).filter((w): w is NewsWarning => ['low_confidence', 'high_similarity', 'possible_duplicate'].includes(w)),
    rejectReason: r.reject_reason,
    indexable: r.indexable === true,
    indexableEn: r.indexable_en === true,
    hasEn: r.has_en === true,
    publishedAt: r.published_at,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  }
}

export interface NewsQuery {
  status?: NewsStatus
  scope?: NewsScope
  runId?: string
  search?: string
}

/** Every item of a query (a handful of 200-row pages at most). The category and source filters are applied in the panel. */
export async function fetchNews(client: Client, q: NewsQuery): Promise<AdminNews[]> {
  const rows: AdminNews[] = []
  for (let page = 0; page < MAX_PAGES; page++) {
    const batch = unwrap(
      await guideSchema(client).rpc('admin_list_news', {
        p_status: q.status,
        p_scope: q.scope,
        p_run_id: q.runId || undefined,
        p_query: q.search?.trim() || undefined,
        p_limit: PAGE,
        p_offset: page * PAGE,
      }),
    )
    rows.push(...batch.map(toNews))
    if (!batch.length || rows.length >= Number(batch[0]?.total_count ?? 0)) break
  }
  return rows
}

export async function fetchNewsById(client: Client, id: string): Promise<AdminNews | null> {
  const rows = unwrap(await guideSchema(client).rpc('admin_list_news', { p_id: id, p_limit: 1 }))
  return rows[0] ? toNews(rows[0]) : null
}

/** Counters of the tabs, the menu badge and Inicio, plus the last collection and the health of the agent. */
export async function fetchNewsSummary(client: Client): Promise<NewsSummary> {
  const s = unwrap(await guideSchema(client).rpc('admin_news_summary')) as Record<string, unknown>
  const num = (key: string) => Number(s[key] ?? 0)
  const run = s.last_run as Record<string, unknown> | null
  const health = s.health as Record<string, unknown> | null
  return {
    pending: num('pending'),
    pendingAgent: num('pending_agent'),
    pendingWarnings: num('pending_warnings'),
    published: num('published'),
    publishedIndexable: num('published_indexable'),
    publishedNoindex: num('published_noindex'),
    rejected: num('rejected'),
    total: num('total'),
    lastRun: run
      ? {
          id: String(run.id),
          startedAt: String(run.started_at),
          finishedAt: run.finished_at ? String(run.finished_at) : null,
          status: String(run.status),
          dryRun: run.dry_run === true,
          insertedNews: Number(run.inserted_news ?? 0),
          insertedEvents: Number(run.inserted_events ?? 0),
          duplicates: Number(run.duplicates ?? 0),
        }
      : null,
    health: health ? { ok: health.ok === true, checkedAt: health.checked_at ? String(health.checked_at) : null } : null,
  }
}

// Decisions ------------------------------------------------------------------------------------------
export interface NewsBatchResult {
  ok: string[]
  failed: { id: string; code: string; message: string }[]
}

function toBatch(raw: unknown): NewsBatchResult {
  const r = raw as { ok?: { id?: string }[]; failed?: NewsBatchResult['failed'] }
  return { ok: (r.ok ?? []).map((x) => String(x.id ?? '')).filter(Boolean), failed: r.failed ?? [] }
}

/** Publishes the drafts (max 100 per call): every id goes in its own transaction, a failure does not undo the rest. */
export async function approveNews(client: Client, ids: string[]): Promise<NewsBatchResult> {
  return toBatch(unwrap(await guideSchema(client).rpc('approve_news', { p_ids: ids })))
}

/** `reason` null = sin motivo. */
export async function rejectNews(client: Client, ids: string[], reason: string | null): Promise<NewsBatchResult> {
  return toBatch(unwrap(await guideSchema(client).rpc('reject_news', { p_ids: ids, p_reason: reason ?? undefined })))
}

/** Back to a draft: Retirar, Recuperar and the «Deshacer» of approve / reject. */
export async function reopenNews(client: Client, ids: string[]): Promise<NewsBatchResult> {
  return toBatch(unwrap(await guideSchema(client).rpc('reopen_news', { p_ids: ids })))
}

/** Rejected by `wrong_data` only: the agent may propose that item again. */
export async function releaseNewsDedupe(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('admin_release_news_dedupe', { p_id: id }))
}

// Writes ---------------------------------------------------------------------------------------------
/** New manual item, as a draft or already published. Returns its id. */
export async function createNews(client: Client, form: NewsForm, status: 'draft' | 'published'): Promise<string> {
  const row = unwrap(await guideSchema(client).from('news').insert(newsInsert(form, status)).select('id').single())
  return row.id
}

/** `status` undefined keeps it; `published` publishes in the same update (draft → published). */
export async function updateNews(client: Client, id: string, form: NewsForm, opts: { agent: boolean; status?: 'published' }): Promise<void> {
  const write = { ...newsWrite(form, { agent: opts.agent }), ...(opts.status ? { status: opts.status } : {}) }
  unwrap(await guideSchema(client).from('news').update(write).eq('id', id).select('id').single())
}

/** Drafts and rejected manual items only (PT423 otherwise). */
export async function deleteNews(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).from('news').delete().eq('id', id).select('id').single())
}

// Related links (up to 3 per item) ------------------------------------------------------------------
export async function fetchNewsLinks(client: Client, newsId: string): Promise<RelatedLink[]> {
  const g = guideSchema(client)
  const rows = unwrap(await g.from('news_links').select('position, item_id, article_id, event_id').eq('news_id', newsId).order('position'))
  const ids = (key: 'item_id' | 'article_id' | 'event_id') => rows.map((r) => r[key]).filter((v): v is string => !!v)
  const [items, articles, events] = await Promise.all([
    ids('item_id').length ? g.from('items').select('id, name').in('id', ids('item_id')).then(unwrap) : [],
    ids('article_id').length ? g.from('articles').select('id, title_es').in('id', ids('article_id')).then(unwrap) : [],
    ids('event_id').length ? g.from('events').select('id, title_es').in('id', ids('event_id')).then(unwrap) : [],
  ])
  const links: RelatedLink[] = []
  for (const r of rows) {
    if (r.item_id) links.push({ kind: 'item', id: r.item_id, label: items.find((i) => i.id === r.item_id)?.name ?? 'Ficha' })
    else if (r.article_id) links.push({ kind: 'article', id: r.article_id, label: articles.find((a) => a.id === r.article_id)?.title_es ?? 'Artículo' })
    else if (r.event_id) links.push({ kind: 'event', id: r.event_id, label: events.find((e) => e.id === r.event_id)?.title_es ?? 'Evento' })
  }
  return links
}

/** Replaces the links of an item (positions 1–3). */
export async function saveNewsLinks(client: Client, newsId: string, links: readonly RelatedLink[]): Promise<void> {
  const g = guideSchema(client)
  unwrap(await g.from('news_links').delete().eq('news_id', newsId).select('position'))
  if (!links.length) return
  const rows = links.slice(0, 3).map((l, i) => ({
    news_id: newsId,
    position: i + 1,
    item_id: l.kind === 'item' ? l.id : null,
    article_id: l.kind === 'article' ? l.id : null,
    event_id: l.kind === 'event' ? l.id : null,
  }))
  unwrap(await g.from('news_links').insert(rows).select('position'))
}

/** Published things a news item can point to: fichas, articles and approved events. */
export async function searchRelated(client: Client, kind: RelatedKind, term: string): Promise<RelatedLink[]> {
  const g = guideSchema(client)
  const like = `%${term.trim().replace(/[\\%_,()]/g, ' ')}%`
  if (kind === 'item') {
    const rows = unwrap(await g.from('items').select('id, name').eq('published', true).ilike('name', like).order('name').limit(8))
    return rows.map((r) => ({ kind, id: r.id, label: r.name }))
  }
  if (kind === 'article') {
    const rows = unwrap(await g.from('articles').select('id, title_es').eq('status', 'published').ilike('title_es', like).order('title_es').limit(8))
    return rows.map((r) => ({ kind, id: r.id, label: r.title_es }))
  }
  const rows = unwrap(await g.from('events').select('id, title_es').eq('status', 'approved').ilike('title_es', like).order('starts_at', { ascending: false }).limit(8))
  return rows.map((r) => ({ kind, id: r.id, label: r.title_es }))
}

// Categories -----------------------------------------------------------------------------------------
export async function fetchNewsCategories(client: Client): Promise<NewsCategory[]> {
  const rows = unwrap(await guideSchema(client).from('news_categories').select('id, key, label_es, label_en, sort_order, active').order('sort_order'))
  return rows.map((r) => ({ id: r.id, key: r.key, labelEs: r.label_es, labelEn: r.label_en, sortOrder: r.sort_order, active: r.active }))
}

/** News per category (all states), counted in the panel: the list of ids is small. */
export async function fetchNewsCategoryCounts(client: Client): Promise<Record<string, number>> {
  const rows = unwrap(await guideSchema(client).from('news').select('category_id').limit(5000))
  const counts: Record<string, number> = {}
  for (const r of rows) counts[r.category_id] = (counts[r.category_id] ?? 0) + 1
  return counts
}

export interface CategoryWrite {
  key: string
  label_es: string
  label_en: string
}

export async function createNewsCategory(client: Client, write: CategoryWrite, sortOrder: number): Promise<void> {
  unwrap(await guideSchema(client).from('news_categories').insert({ ...write, sort_order: sortOrder }).select('id').single())
}

export async function updateNewsCategory(client: Client, id: string, write: Partial<CategoryWrite>): Promise<void> {
  unwrap(await guideSchema(client).from('news_categories').update(write).eq('id', id).select('id').single())
}

export async function deleteNewsCategory(client: Client, id: string, reassignTo?: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('delete_news_category', { p_id: id, p_reassign_to: reassignTo }))
}

export async function reorderNewsCategories(client: Client, ids: string[]): Promise<void> {
  unwrap(await guideSchema(client).rpc('reorder_news_categories', { p_ids: ids }))
}
