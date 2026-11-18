import type { Database, Json } from '~/types/database.types'
import { previewGymIndices } from '~/services/admin/gym-editor'
import { sectionsOf, type GymForm } from '~/utils/gym-fields'
import { errorFieldIds, type ItemErrors } from '~/utils/item-patch'
import type { GymIndices } from '~/services/admin/gym-editor'

const DEBOUNCE_MS = 700

/**
 * Live indices of the gym editor: after a pause, asks the database to compute them (rpc
 * `gym_indices_preview`) from the current form values, so they also show for unpublished gyms.
 * Fields with errors are left out; when the server refuses the values the last good result stays.
 */
export function useGymIndices(id: string, form: Ref<GymForm | null>, errors: Ref<ItemErrors>, initial: () => GymIndices | null) {
  const client = useSupabaseClient<Database>()
  const preview = ref<GymIndices | null>(null)
  let timer: ReturnType<typeof setTimeout> | undefined
  let seq = 0

  async function refresh() {
    const current = form.value
    if (!current) return
    const skip = errorFieldIds(errors.value)
    const sections = sectionsOf(current, (html) => html, skip)
    const mine = ++seq
    try {
      const result = await previewGymIndices(client, id, sections.detail as Json, sections.scores as Json)
      if (mine === seq && result) preview.value = result
    } catch {
      // Invalid values (22023) or no connection: keep the last indices shown.
    }
  }

  watch(
    () => (form.value ? JSON.stringify([form.value.scores, sectionsOf(form.value, (h) => h).detail]) : ''),
    (key) => {
      clearTimeout(timer)
      if (key) timer = setTimeout(() => void refresh(), DEBOUNCE_MS)
    },
    { immediate: true },
  )
  onScopeDispose(() => clearTimeout(timer))

  return computed(() => preview.value ?? initial())
}
