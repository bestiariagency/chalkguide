import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { AdminPageRow, PageKey } from '~/utils/admin-pages'
import { mediaIdsInDoc, mediaIdsInHtml, rewriteDocMedia, rewriteHtmlMedia } from '~/utils/media-body'
import type { PageRow, PageUpdate } from '~/utils/page-form'
import { ServiceError, guideSchema, unwrap, unwrapMaybe } from '../client'
import { fetchMediaPaths } from '../media'

type Client = SupabaseClient<Database>

const PAGE_COLUMNS =
  'id, key, title_es, title_en, slug_es, slug_en, body_json_es, body_html_es, body_json_en, body_html_en, published, seo_title_es, seo_title_en, seo_description_es, seo_description_en, og_media_id, noindex, has_en, created_at, updated_at, revised_on'

/** PostgREST `or` filter of the pages whose Spanish body still carries placeholder marks (D34). */
export const PROVISIONAL_PAGES_FILTER = 'body_html_es.ilike.%[XAVI:%,body_html_es.ilike.%[PENDIENTE XAVI:%,body_html_es.ilike.%[LEONA:%,body_html_es.ilike.%Texto provisional%'

/** The five pages in their fixed order (rpc `admin_pages_list`) plus which ones have an empty Spanish body. */
export async function fetchAdminPages(client: Client): Promise<AdminPageRow[]> {
  const schema = guideSchema(client)
  const [rows, empties, marked] = await Promise.all([
    schema.rpc('admin_pages_list').then(unwrap),
    schema.from('pages').select('key').eq('body_html_es', '').then(unwrap),
    schema.from('pages').select('key').or(PROVISIONAL_PAGES_FILTER).then(unwrap),
  ])
  const empty = new Set(empties.map((row) => row.key))
  const provisional = new Set(marked.map((row) => row.key))
  return rows.map((row) => ({ ...row, empty: empty.has(row.key), provisional: provisional.has(row.key) }))
}

/** The page with bodies; `null` when the key does not exist (e.g. `transparency` before it was created). */
export async function fetchPageForEdit(client: Client, key: PageKey): Promise<PageRow | null> {
  const row = unwrapMaybe(await guideSchema(client).from('pages').select(PAGE_COLUMNS).eq('key', key).maybeSingle())
  return row as PageRow | null
}

/** Light read of what changes when publishing: state, date shown to readers and version. */
export async function fetchPageState(client: Client, id: string): Promise<{ published: boolean; revisedOn: string | null; updatedAt: string }> {
  const row = unwrap(await guideSchema(client).from('pages').select('published, revised_on, updated_at').eq('id', id).single())
  return { published: row.published, revisedOn: row.revised_on, updatedAt: row.updated_at }
}

/**
 * Body images keep the path they had when inserted; a replaced file lives at a new one. Rewrites the
 * `src` of every body image with the current `storage_path`. Best effort: on failure rows come back untouched.
 */
export async function refreshPageBodies(client: Client, rows: PageRow[]): Promise<PageRow[]> {
  const ids = [...new Set(rows.flatMap((r) => [...mediaIdsInDoc(r.body_json_es), ...mediaIdsInDoc(r.body_json_en), ...mediaIdsInHtml(r.body_html_es), ...mediaIdsInHtml(r.body_html_en ?? '')]))]
  if (!ids.length) return rows
  try {
    const paths = await fetchMediaPaths(guideSchema(client), ids)
    return rows.map((r) => ({
      ...r,
      body_json_es: rewriteDocMedia(r.body_json_es, paths),
      body_json_en: rewriteDocMedia(r.body_json_en, paths),
      body_html_es: r.body_html_es ? rewriteHtmlMedia(r.body_html_es, paths) : r.body_html_es,
      body_html_en: r.body_html_en ? rewriteHtmlMedia(r.body_html_en, paths) : r.body_html_en,
    }))
  } catch {
    return rows
  }
}

/** Writes the changes of a page that is NOT published. The filter makes the guard real (`LIVE` if it went live meanwhile). */
export async function savePageChanges(client: Client, id: string, patch: PageUpdate): Promise<string> {
  const rows = unwrap(await guideSchema(client).from('pages').update(patch).eq('id', id).eq('published', false).select('updated_at'))
  if (!rows[0]) throw new ServiceError('La página ya está publicada: se edita con borrador de cambios.', 'LIVE')
  return rows[0].updated_at
}

/** First publication (the database stamps `revised_on` and keeps a version on legal pages). */
export async function publishPage(client: Client, id: string): Promise<{ updatedAt: string; revisedOn: string | null }> {
  const rows = unwrap(await guideSchema(client).from('pages').update({ published: true }).eq('id', id).eq('published', false).select('updated_at, revised_on'))
  if (!rows[0]) throw new ServiceError('La página ya está publicada.', 'LIVE')
  return { updatedAt: rows[0].updated_at, revisedOn: rows[0].revised_on }
}

/** Takes an about/transparency page off the site (legal ones are refused with `PT423 legal_page_cannot_unpublish`). */
export async function unpublishPage(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('unpublish_page', { p_page_id: id }))
}

export interface PageVersion {
  id: string
  locale: 'es' | 'en'
  revisedOn: string
  publishedAt: string
}

/** Dated copies kept at each publication of a legal page (admin only), newest first. */
export async function fetchPageVersions(client: Client, key: PageKey): Promise<PageVersion[]> {
  const rows = unwrap(await guideSchema(client).from('page_versions').select('id, locale, revised_on, published_at').eq('key', key).order('published_at', { ascending: false }))
  return rows.map((r) => ({ id: r.id, locale: r.locale, revisedOn: r.revised_on, publishedAt: r.published_at }))
}
