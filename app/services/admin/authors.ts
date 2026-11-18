import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { authorPayload, type AdminAuthor, type AuthorCounts, type AuthorForm, type AuthorImpact, type SiteAuthor } from '~/utils/admin-authors'
import { ServiceError, guideSchema, one, unwrap, unwrapMaybe } from '../client'

type Client = SupabaseClient<Database>

const MEDIA = 'id, storage_path, original_filename, alt_es, alt_en, width, height, dominant_color'
const NO_COUNTS: AuthorCounts = { total: 0, live: 0 }

export interface AdminAuthorsData {
  authors: AdminAuthor[]
  /** Counts by author id. */
  counts: Record<string, AuthorCounts>
  site: SiteAuthor
  /** Articles without author (signed by the site author). */
  siteCounts: AuthorCounts
}

/** Authors in site order, their article counts (view `admin_author_article_counts`) and the site author. */
export async function fetchAdminAuthors(client: Client): Promise<AdminAuthorsData> {
  const schema = guideSchema(client)
  const [authors, counts, site] = await Promise.all([
    schema
      .from('authors')
      .select(`id, slug, name, role_es, role_en, bio_es, bio_en, photo_media_id, sort_order, photo:media!authors_photo_media_id_fkey(${MEDIA})`)
      .order('sort_order')
      .order('name')
      .then(unwrap),
    schema.from('admin_author_article_counts').select('*').then(unwrap),
    schema
      .from('site_settings')
      .select(`author_name, author_role_es, author_role_en, author_bio_en, photo:media!site_settings_author_photo_media_id_fkey(${MEDIA})`)
      .eq('id', 1)
      .single()
      .then(unwrap),
  ])
  const byId: Record<string, AuthorCounts> = {}
  let siteCounts = NO_COUNTS
  for (const row of counts) {
    const value = { total: Number(row.articles_total ?? 0), live: Number(row.articles_live ?? 0) }
    if (row.author_id) byId[row.author_id] = value
    else siteCounts = value
  }
  return {
    authors: authors.map(({ photo, ...a }) => ({ ...a, photo: one(photo) })),
    counts: byId,
    site: { name: site.author_name, role_es: site.author_role_es, role_en: site.author_role_en, bio_en: site.author_bio_en, photo: one(site.photo) },
    siteCounts,
  }
}

/** Fresh counts and the first three titles of one author, asked when the delete dialog opens. */
export async function fetchAuthorImpact(client: Client, authorId: string): Promise<AuthorImpact> {
  const schema = guideSchema(client)
  const [counts, titles] = await Promise.all([
    schema.from('admin_author_article_counts').select('*').eq('author_id', authorId).maybeSingle().then(unwrapMaybe),
    schema
      .from('articles')
      .select('id, title_es, status, published_at')
      .eq('author_id', authorId)
      .order('updated_at', { ascending: false })
      .limit(3)
      .then(unwrap),
  ])
  return {
    counts: { total: Number(counts?.articles_total ?? 0), live: Number(counts?.articles_live ?? 0) },
    titles: titles.map((t) => ({ id: t.id, title: t.title_es, status: t.status as AuthorImpact['titles'][number]['status'], published_at: t.published_at })),
  }
}

/** Creates (at the end of the order) or updates an author. A taken slug surfaces as 23505 `authors_slug_key`. */
export async function saveAuthor(client: Client, id: string | undefined, form: AuthorForm, nextOrder: number): Promise<void> {
  const table = guideSchema(client).from('authors')
  const payload = authorPayload(form)
  if (id) unwrap(await table.update(payload).eq('id', id).select('id').single())
  else unwrap(await table.insert({ ...payload, sort_order: nextOrder }).select('id').single())
}

/** Their articles go to the site author in the database (`detach_author`, D57). */
export async function deleteAuthor(client: Client, id: string): Promise<void> {
  const rows = unwrap(await guideSchema(client).from('authors').delete().eq('id', id).select('id'))
  if (!rows.length) throw new ServiceError('author not found', 'P0002')
}

/** Whole list, in order. Errors 22023: `list must include every author` means the list is stale. */
export async function reorderAuthors(client: Client, ids: string[]): Promise<void> {
  unwrap(await guideSchema(client).rpc('admin_reorder_authors', { p_ids: ids }))
}
