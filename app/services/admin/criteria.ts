import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { criterionPayload, type AdminCriterion, type CriterionCategory, type CriterionForm, type CriterionSample, type CriterionUsage } from '~/utils/admin-criteria'
import { guideSchema, one, unwrap } from '../client'

type Client = SupabaseClient<Database>

const COLUMNS = 'id, category, key, name_es, name_en, description_es, description_en, sort_order, is_active, used_in_formula'

export interface CriteriaScreen {
  /** Criteria of every category, in order (the selector counts the active ones). */
  criteria: AdminCriterion[]
  usage: Record<string, CriterionUsage>
  samples: CriterionSample[]
}

/** Criteria of all categories + usage and published items with their author scores for the selected one. */
export async function fetchCriteriaScreen(client: Client, category: CriterionCategory): Promise<CriteriaScreen> {
  const schema = guideSchema(client)
  const [criteria, usage, items] = await Promise.all([
    schema.from('criteria').select(COLUMNS).order('sort_order').order('name_es').then(unwrap),
    schema.rpc('criteria_usage', { p_category: category }).then(unwrap),
    schema
      .from('items')
      .select('id, name, author_reviews(author_review_scores(criterion_id, score))')
      .eq('category', category)
      .eq('published', true)
      .order('name')
      .limit(200)
      .then(unwrap),
  ])
  return {
    criteria: criteria.map((c) => ({ ...c, category: c.category as CriterionCategory, used_in_formula: c.used_in_formula === true })),
    usage: Object.fromEntries(
      usage.map((u) => [u.criterion_id, { author_items: u.author_items, user_reviews: u.user_reviews, draft_items: u.draft_items, used_by_index: u.used_by_index, can_delete: u.can_delete }]),
    ),
    samples: items.map((item) => ({
      id: item.id,
      name: item.name,
      scores: Object.fromEntries((one(item.author_reviews)?.author_review_scores ?? []).map((s) => [s.criterion_id, s.score])),
    })),
  }
}

/** Create (the database puts it last) or update (only the editable columns; the key never changes). */
export async function saveCriterion(client: Client, category: CriterionCategory, id: string | undefined, form: CriterionForm): Promise<void> {
  const table = guideSchema(client).from('criteria')
  const payload = criterionPayload(form)
  if (id) unwrap(await table.update(payload).eq('id', id).select('id').single())
  else unwrap(await table.insert({ ...payload, category, key: form.key, is_active: true }).select('id').single())
}

export async function setCriterionActive(client: Client, id: string, active: boolean): Promise<void> {
  unwrap(await guideSchema(client).from('criteria').update({ is_active: active }).eq('id', id).select('id').single())
}

export async function deleteCriterion(client: Client, id: string): Promise<void> {
  unwrap(await guideSchema(client).from('criteria').delete().eq('id', id).select('id').single())
}

/** `ids` = every criterion of the category (active and inactive) in the new order. */
export async function reorderCriteria(client: Client, category: CriterionCategory, ids: string[]): Promise<void> {
  unwrap(await guideSchema(client).rpc('reorder_criteria', { p_category: category, p_ids: ids }))
}
