import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { ArticleUpdate } from '~/utils/article-form'
import type { AdminMedia } from '~/utils/admin-media'
import { ServiceError, guideSchema, unwrap } from '../client'
import { NOT_LIVE } from './articles'
import { fetchMediaPaths } from '../media'
import { mediaIdsInDoc, mediaIdsInHtml, rewriteDocMedia, rewriteHtmlMedia } from '~/utils/media-body'

type Client = SupabaseClient<Database>
export type ArticleRow = Database['guide']['Tables']['articles']['Row']

const ARTICLE_COLUMNS =
  'id, category_id, author_id, status, published_at, title_es, title_en, slug_es, slug_en, excerpt_es, excerpt_en, body_json_es, body_html_es, body_json_en, body_html_en, cover_media_id, is_featured, sort_order, reading_minutes_es, reading_minutes_en, seo_title_es, seo_title_en, seo_description_es, seo_description_en, og_media_id, noindex, canonical_url, has_en, created_at, updated_at'

const MEDIA_COLUMNS = 'id, storage_path, original_filename, alt_es, alt_en, width, height, dominant_color'

/** The article with bodies (not the search vectors); `null` when it does not exist. */
export async function fetchArticleForEdit(client: Client, id: string): Promise<ArticleRow | null> {
  const { data, error } = await guideSchema(client).from('articles').select(ARTICLE_COLUMNS).eq('id', id).maybeSingle()
  if (error) throw new ServiceError(error.message, error.code)
  return data as ArticleRow | null
}

export async function fetchMediaByIds(client: Client, ids: string[]): Promise<AdminMedia[]> {
  if (!ids.length) return []
  return unwrap(await guideSchema(client).from('media').select(MEDIA_COLUMNS).in('id', ids))
}

/** Latest images, optionally filtered by file name, alt, caption or credit (rpc `search_media`). */
export async function searchMedia(client: Client, query: string, limit = 48): Promise<AdminMedia[]> {
  const rows = unwrap(await guideSchema(client).rpc('search_media', { p_query: query.trim().slice(0, 100), p_limit: limit }))
  return rows.map(({ id, storage_path, original_filename, alt_es, alt_en, width, height, dominant_color }) => ({
    id,
    storage_path,
    original_filename,
    alt_es,
    alt_en,
    width,
    height,
    dominant_color,
  }))
}

/**
 * Body images keep the path they had when inserted; a replaced file lives at a new one. Rewrites the
 * `src` of every body image (JSON and HTML, both languages) with the current `storage_path`.
 * Best effort: if the lookup fails the rows come back untouched.
 */
export async function refreshArticleBodies(client: Client, rows: ArticleRow[]): Promise<ArticleRow[]> {
  const ids = [
    ...new Set(rows.flatMap((r) => [...mediaIdsInDoc(r.body_json_es), ...mediaIdsInDoc(r.body_json_en), ...mediaIdsInHtml(r.body_html_es), ...mediaIdsInHtml(r.body_html_en)])),
  ]
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

/**
 * Writes the changes of an article that is NOT live. The filter makes the guard real: if the article
 * went live meanwhile (or from another tab) nothing is written and `LIVE` is thrown.
 */
export async function saveArticleChanges(client: Client, id: string, patch: ArticleUpdate): Promise<string> {
  const rows = unwrap(
    await guideSchema(client)
      .from('articles')
      .update(patch)
      .eq('id', id)
      .or(NOT_LIVE(new Date().toISOString()))
      .select('updated_at'),
  )
  if (!rows[0]) throw new ServiceError('El artículo ya está publicado: se edita con borrador de cambios.', 'LIVE')
  return rows[0].updated_at
}
