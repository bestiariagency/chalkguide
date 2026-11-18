import type { FieldCheck } from '~/utils/check-violation'

/**
 * Field errors that came back from the database (a refused CHECK on autosave). Each one holds the
 * involved fields back from the autosave and disappears as soon as one of them changes, so a
 * refusal is reported once, on its field, and never retried with the same values.
 */
export function useServerFieldErrors(read: (key: string) => unknown) {
  const entries = ref<{ fields: string[]; message: string; snap: string }[]>([])
  const snapOf = (fields: string[]) => JSON.stringify(fields.map(read))

  /** Records a refusal; `false` when the same one is already shown (do not retry). */
  function add(check: FieldCheck): boolean {
    const snap = snapOf(check.fields)
    entries.value = entries.value.filter((e) => e.snap === snapOf(e.fields))
    if (entries.value.some((e) => e.snap === snap && e.message === check.message && e.fields.join() === check.fields.join())) return false
    entries.value.push({ ...check, snap })
    return true
  }

  const errors = computed(() => {
    const out: Record<string, string> = {}
    for (const e of entries.value) if (e.snap === snapOf(e.fields)) for (const key of e.fields) out[key] = e.message
    return out
  })
  return { add, errors }
}
