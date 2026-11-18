import type { ItemCriterion } from '~/services/admin/item-editor'
import type { GymForm } from '~/utils/gym-fields'

/**
 * Whether every input of the family index formula is filled (kids area, minimum age, cafe and the
 * "Para familias" score). Mirrors `guide.gym_indices`, which uses all four inputs regardless of the kids area.
 */
export function familyComplete(form: GymForm, criteria: ItemCriterion[]): boolean {
  const familyCriterion = criteria.find((c) => c.key === 'family_friendly')
  if (!familyCriterion || form.scores[familyCriterion.id] === undefined) return false
  if (form.has_kids_area === null || form.has_cafe === null) return false
  return form.kids_min_age.trim() !== ''
}
