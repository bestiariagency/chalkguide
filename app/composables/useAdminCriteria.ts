import type { Database } from '~/types/database.types'
import { deleteCriterion, fetchCriteriaScreen, reorderCriteria, saveCriterion, setCriterionActive } from '~/services/admin/criteria'
import {
  criterionCategoryLabel,
  criterionError,
  noteCount,
  NO_USAGE,
  pluralItems,
  type AdminCriterion,
  type CriterionCategory,
  type CriterionError,
  type CriterionForm,
} from '~/utils/admin-criteria'

/**
 * Criteria screen (F6.10): data of the selected category, local order of the active ones and the
 * actions. Orders are saved on each committed change (serialised); on failure the screen reloads so
 * it always shows what the database has. Every change that can be undone offers "Deshacer".
 */
export function useAdminCriteria(category: Ref<CriterionCategory>) {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const list = useAsyncData('admin-criteria', () => fetchCriteriaScreen(client, category.value), { server: false, watch: [category] })

  const all = computed(() => list.data.value?.criteria ?? [])
  const mine = computed(() => all.value.filter((c) => c.category === category.value))
  const inactive = computed(() => mine.value.filter((c) => !c.is_active))
  const active = ref<AdminCriterion[]>([])
  const usage = computed(() => list.data.value?.usage ?? {})
  const samples = computed(() => list.data.value?.samples ?? [])
  const usageOf = (id: string) => usage.value[id] ?? NO_USAGE
  const label = computed(() => criterionCategoryLabel(category.value))
  const activeCounts = computed(() => {
    const counts: Record<string, number> = {}
    for (const c of all.value) if (c.is_active) counts[c.category] = (counts[c.category] ?? 0) + 1
    return counts
  })

  // Order stored in the database (all ids), the target of "Deshacer" after a reorder.
  let savedOrder: string[] = []
  watch(() => list.data.value, (data) => {
    // Another category's data may still be on screen while the new one loads.
    active.value = data ? data.criteria.filter((c) => c.category === category.value && c.is_active) : []
    savedOrder = data ? data.criteria.filter((c) => c.category === category.value).map((c) => c.id) : []
  }, { immediate: true })

  const busy = ref(false)
  const formError = ref<CriterionError>()
  let queue: Promise<unknown> = Promise.resolve()

  async function fail(e: unknown) {
    const err = criterionError(e, label.value)
    toastError({ message: err.message })
    if (err.reload) await list.refresh()
    return err
  }

  const fullOrder = () => [...active.value.map((c) => c.id), ...inactive.value.map((c) => c.id)]

  /** Saves one order at a time; reloads on failure to drop the order the database refused. */
  function persistOrder(ids: string[], message: string, undo?: () => Promise<void>) {
    queue = queue.then(async () => {
      try {
        await reorderCriteria(client, category.value, ids)
        savedOrder = ids
        success({ message, action: undo && { label: 'Deshacer', run: () => void undo() } })
      } catch (e) {
        await fail(e)
        await list.refresh()
      }
    })
    return queue
  }

  async function restoreOrder(ids: string[]) {
    await persistOrder(ids, 'Orden restaurado')
    await list.refresh()
  }
  const reorder = () => {
    const previous = savedOrder
    return persistOrder(fullOrder(), 'Orden guardado', () => restoreOrder(previous))
  }

  /** Runs a mutation with the busy flag, then reloads. Errors become a toast (or the drawer banner). */
  async function run(action: () => Promise<void>, onError?: (e: CriterionError) => void): Promise<boolean> {
    busy.value = true
    try {
      await action()
      await list.refresh()
      return true
    } catch (e) {
      const err = await fail(e)
      onError?.(err)
      return false
    } finally {
      busy.value = false
    }
  }

  async function save(criterion: AdminCriterion | undefined, form: CriterionForm): Promise<boolean> {
    formError.value = undefined
    const ok = await run(() => saveCriterion(client, category.value, criterion?.id, form), (e) => (formError.value = e))
    if (ok) success(criterion ? 'Criterio guardado' : `Criterio creado al final de ${label.value}`)
    return ok
  }

  /** Active ids in order with `id` moved to the end of them, then the inactive ones. */
  const withAtEndOfActive = (id: string) => [
    ...mine.value.filter((c) => c.is_active && c.id !== id).map((c) => c.id),
    id,
    ...mine.value.filter((c) => !c.is_active && c.id !== id).map((c) => c.id),
  ]

  async function deactivate(criterion: AdminCriterion): Promise<boolean> {
    const previous = savedOrder
    const fichas = usageOf(criterion.id).author_items
    const ok = await run(() => setCriterionActive(client, criterion.id, false))
    if (ok) {
      success({
        message: `«${criterion.name_es}» desactivado${fichas ? ` · deja de contar en ${pluralItems(fichas)}` : ''}`,
        action: { label: 'Deshacer', run: () => void undoDeactivate(criterion, previous) },
      })
    }
    return ok
  }
  async function undoDeactivate(criterion: AdminCriterion, previous: string[]) {
    if (await run(async () => { await setCriterionActive(client, criterion.id, true); await reorderCriteria(client, category.value, previous) })) {
      success(`«${criterion.name_es}» activo otra vez`)
    }
  }

  async function reactivate(criterion: AdminCriterion): Promise<boolean> {
    const previous = savedOrder
    const fichas = usageOf(criterion.id).author_items
    const ok = await run(async () => {
      await setCriterionActive(client, criterion.id, true)
      await reorderCriteria(client, category.value, withAtEndOfActive(criterion.id))
    })
    if (ok) {
      success({
        message: `«${criterion.name_es}» activo otra vez${fichas ? ` · vuelve a contar en ${pluralItems(fichas)}` : ''}`,
        action: { label: 'Deshacer', run: () => void undoReactivate(criterion, previous) },
      })
    }
    return ok
  }
  async function undoReactivate(criterion: AdminCriterion, previous: string[]) {
    if (await run(async () => { await setCriterionActive(client, criterion.id, false); await reorderCriteria(client, category.value, previous) })) {
      success(`«${criterion.name_es}» desactivado`)
    }
  }

  async function remove(criterion: AdminCriterion): Promise<boolean> {
    const ok = await run(() => deleteCriterion(client, criterion.id))
    if (ok) success(`Criterio «${criterion.name_es}» eliminado`)
    return ok
  }

  /** Needs a confirmation dialog (it has notes that stop counting). */
  const hasNotes = (criterion: AdminCriterion) => noteCount(usageOf(criterion.id)) > 0

  return { list, active, inactive, mine, usage, usageOf, samples, label, activeCounts, busy, formError, hasNotes, reorder, save, deactivate, reactivate, remove }
}
