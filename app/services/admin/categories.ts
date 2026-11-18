import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { formToPayload, type AdminCategory, type AdminCategoryArticle, type CategoryForm } from '~/utils/admin-categories'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>

/** All categories (in site order) and a minimal row per article, to count and order them. */
export async function fetchAdminCategories(
  client: Client,
): Promise<{ categories: AdminCategory[]; articles: AdminCategoryArticle[] }> {
  const schema = guideSchema(client)
  const [categories, articles] = await Promise.all([
    schema
      .from('article_categories')
      .select('id, name_es, name_en, slug_es, slug_en, description_es, description_en, color, sort_order, has_en')
      .order('sort_order')
      .order('name_es')
      .then(unwrap),
    schema
      .from('articles')
      .select('id, title_es, status, published_at, category_id, sort_order, is_featured')
      .order('sort_order')
      .order('published_at', { ascending: false, nullsFirst: false })
      .then(unwrap),
  ])
  return { categories: categories.map((c) => ({ ...c, has_en: c.has_en === true })), articles }
}

/** Creates (at the end of the order) or updates a category; a slug change tracks its 301 in the DB (D24). */
export async function saveCategory(client: Client, id: string | undefined, form: CategoryForm, nextOrder: number): Promise<void> {
  const table = guideSchema(client).from('article_categories')
  const payload = formToPayload(form)
  if (id) unwrap(await table.update(payload).eq('id', id).select('id').single())
  else unwrap(await table.insert({ ...payload, sort_order: nextOrder }).select('id').single())
}

export async function reorderCategories(client: Client, ids: string[]): Promise<void> {
  unwrap(await guideSchema(client).rpc('reorder_article_categories', { p_ids: ids }))
}

export async function reorderCategoryArticles(client: Client, categoryId: string, ids: string[]): Promise<void> {
  unwrap(await guideSchema(client).rpc('reorder_articles', { p_category_id: categoryId, p_ids: ids }))
}

/** Always through the RPC (direct DELETE is denied); the target is omitted for an empty category. */
export async function deleteCategory(client: Client, id: string, reassignTo: string | undefined): Promise<void> {
  const args = reassignTo ? { p_id: id, p_reassign_to: reassignTo } : { p_id: id }
  unwrap(await guideSchema(client).rpc('delete_article_category', args))
}
