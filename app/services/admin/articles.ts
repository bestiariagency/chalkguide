import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { slugify } from '~/utils/admin-form'
import {
  draftChangeCount,
  uniqueSlug,
  type AdminArticleRow,
  type AdminAuthorOption,
  type AdminCategoryOption,
} from '~/utils/admin-articles'
import { ServiceError, guideSchema, one, unwrap } from '../client'

type Client = SupabaseClient<Database>

/**
 * All articles for the panel list, WITHOUT bodies, plus the number of unpublished changes per
 * article. Client-side table: an author blog has dozens of rows, not thousands.
 */
export async function fetchAdminArticles(client: Client): Promise<AdminArticleRow[]> {
  const schema = guideSchema(client)
  const [articles, drafts] = await Promise.all([
    schema
      .from('articles')
      .select(
        'id, title_es, title_en, slug_es, slug_en, status, published_at, updated_at, is_featured, has_en, category_id, author_id, article_categories(name_es, color)',
      )
      .order('updated_at', { ascending: false })
      .then(unwrap),
    schema.from('content_drafts').select('article_id, payload').eq('entity', 'article').then(unwrap),
  ])
  const changes = new Map<string, number>()
  for (const draft of drafts) if (draft.article_id) changes.set(draft.article_id, draftChangeCount(draft.payload))
  return articles.map((row) => {
    const category = one(row.article_categories)
    return {
      id: row.id,
      title_es: row.title_es,
      title_en: row.title_en,
      slug_es: row.slug_es,
      slug_en: row.slug_en,
      status: row.status,
      published_at: row.published_at,
      updated_at: row.updated_at,
      is_featured: row.is_featured,
      has_en: row.has_en === true,
      category_id: row.category_id,
      author_id: row.author_id,
      category_name: category?.name_es ?? 'Sin categoría',
      category_color: category?.color ?? null,
      changes: changes.get(row.id) ?? 0,
    }
  })
}

export async function fetchArticleCategories(client: Client): Promise<AdminCategoryOption[]> {
  const rows = unwrap(
    await guideSchema(client).from('article_categories').select('id, name_es, color').order('sort_order').order('name_es'),
  )
  return rows.map((row) => ({ id: row.id, name: row.name_es, color: row.color }))
}

export async function fetchArticleAuthors(client: Client): Promise<AdminAuthorOption[]> {
  const rows = unwrap(await guideSchema(client).from('authors').select('id, name').order('sort_order').order('name'))
  return rows.map((row) => ({ id: row.id, name: row.name }))
}

/** Slugs in use by articles (optionally ignoring one: the article being edited). */
export async function takenSlugs(client: Client, excludeId?: string) {
  const rows = unwrap(await guideSchema(client).from('articles').select('id, slug_es, slug_en'))
  const es = new Set<string>()
  const en = new Set<string>()
  for (const row of rows) {
    if (row.id === excludeId) continue
    es.add(row.slug_es)
    if (row.slug_en) en.add(row.slug_en)
  }
  return { es, en }
}

/** Minimal draft ("Sin título") in the first category; returns its id so the editor can open it. */
export async function createDraftArticle(client: Client, title?: string): Promise<string> {
  const schema = guideSchema(client)
  const [first] = unwrap(await schema.from('article_categories').select('id').order('sort_order').limit(1))
  if (!first) throw new ServiceError('No hay categorías: crea una antes de escribir un artículo.', 'NO_CATEGORY')
  const taken = await takenSlugs(client)
  const name = title?.trim().slice(0, 200) || 'Sin título'
  const row = unwrap(
    await schema
      .from('articles')
      .insert({ category_id: first.id, title_es: name, slug_es: uniqueSlug(slugify(name).slice(0, 80) || 'sin-titulo', taken.es), status: 'draft' })
      .select('id')
      .single(),
  )
  return row.id
}

/** Copy as a draft: same content, "(copia)" in the titles and unique slugs. Never copies featured/canonical/date. */
export async function duplicateArticle(client: Client, id: string): Promise<{ id: string; title: string }> {
  const schema = guideSchema(client)
  const source = unwrap(
    await schema
      .from('articles')
      .select(
        'category_id, title_es, title_en, slug_es, slug_en, excerpt_es, excerpt_en, body_json_es, body_html_es, body_json_en, body_html_en, cover_media_id, og_media_id, seo_title_es, seo_title_en, seo_description_es, seo_description_en, noindex',
      )
      .eq('id', id)
      .single(),
  )
  const taken = await takenSlugs(client)
  const copyTitle = (title: string) => `${title.slice(0, 192)} (copia)`
  const title = copyTitle(source.title_es)
  const row = unwrap(
    await schema
      .from('articles')
      .insert({
        ...source,
        title_es: title,
        slug_es: uniqueSlug(`${slugify(source.slug_es)}-copia`, taken.es),
        title_en: source.title_en ? copyTitle(source.title_en) : null,
        slug_en: source.slug_en ? uniqueSlug(`${slugify(source.slug_en)}-copy`, taken.en) : null,
        status: 'draft',
        published_at: null,
        is_featured: false,
      })
      .select('id')
      .single(),
  )
  return { id: row.id, title }
}

/** Not live now: a draft, or scheduled for the future (what this screen may touch directly). */
export const NOT_LIVE = (nowIso: string) => `status.eq.draft,and(status.eq.scheduled,published_at.gt.${nowIso})`

/** Deletes the articles that never went live; throws `LIVE` afterwards if some were live (those stay). */
export async function deleteArticles(client: Client, ids: string[]): Promise<number> {
  const rows = unwrap(
    await guideSchema(client).from('articles').delete().in('id', ids).or(NOT_LIVE(new Date().toISOString())).select('id'),
  )
  if (rows.length !== ids.length) throw new ServiceError('Alguno de los artículos ya estaba publicado y no se ha eliminado.', 'LIVE')
  return rows.length
}

/** Moves the articles that never went live; throws `LIVE` afterwards if some were live (those stay). */
export async function moveArticles(client: Client, ids: string[], categoryId: string): Promise<number> {
  const rows = unwrap(
    await guideSchema(client)
      .from('articles')
      .update({ category_id: categoryId })
      .in('id', ids)
      .or(NOT_LIVE(new Date().toISOString()))
      .select('id'),
  )
  if (rows.length !== ids.length) throw new ServiceError('Alguno de los artículos ya estaba publicado y no se ha movido.', 'LIVE')
  return rows.length
}

/** Throws away the unpublished changes of a published article (what is live does not change). */
export async function discardArticleChanges(client: Client, id: string): Promise<void> {
  const discarded = unwrap(await guideSchema(client).rpc('discard_draft', { p_entity: 'article', p_entity_id: id }))
  if (!discarded) throw new ServiceError('No hay cambios que descartar.', '22023')
}

/** Takes a published or scheduled article off the site; it becomes a draft (unpublished changes are kept). */
export async function unpublishArticle(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).rpc('unpublish_article', { p_article_id: id }))
}
