import type { ShoeSummary } from '~/types/domain'

const COMPARE_TOAST_ID = 1
const FLASH_MS = 900

/**
 * Add / remove / replace models in the comparison, from the cards, the adder or the table.
 * With 3 models, choosing another does not fail silently: it opens "which one do I replace?".
 * Announces every change through the toast region (aria-live) and flashes the new column.
 */
export function useCompareActions(
  cmp: ReturnType<typeof useShoeComparator>,
  options: { /** The floating tray already announces the count: skip the "added" toast. */ trayShown?: Ref<boolean> } = {},
) {
  const { t } = useI18n()
  const toast = useToast()
  const dialogOpen = ref(false)
  const pending = ref<ShoeSummary | null>(null)
  const flashSlug = ref<string | null>(null)
  let flashTimer: ReturnType<typeof setTimeout> | undefined

  watch(dialogOpen, (open) => {
    if (!open) pending.value = null
  })
  onScopeDispose(() => clearTimeout(flashTimer))

  /** `silent`: the caller (e.g. the drawer button) already shows the new state. */
  function remove(shoe: ShoeSummary, opts: { silent?: boolean } = {}) {
    cmp.remove(shoe.slug)
    if (opts.silent) return
    toast.info(t('shoes.compare.removed', { name: shoe.model }), undefined, COMPARE_TOAST_ID)
  }

  /** "+ Comparar" on a card or an option of the adder. */
  function request(shoe: ShoeSummary, opts: { silent?: boolean } = {}) {
    if (cmp.isSelected(shoe.slug)) return remove(shoe, opts)
    if (cmp.isFull.value) {
      pending.value = shoe
      dialogOpen.value = true
      return
    }
    const count = cmp.selectedSlugs.value.length + 1
    cmp.add(shoe.slug)
    if (opts.silent || options.trayShown?.value) return
    toast.info(
      t('common.compareAdded', { count }),
      undefined,
      COMPARE_TOAST_ID,
    )
  }

  function confirmReplace(old: ShoeSummary) {
    const incoming = pending.value
    if (!incoming) return
    cmp.replace(old.slug, incoming.slug)
    toast.info(
      t('shoes.compare.replaced', { incoming: incoming.model, old: old.model }),
      undefined,
      COMPARE_TOAST_ID,
    )
    flashSlug.value = incoming.slug
    clearTimeout(flashTimer)
    flashTimer = setTimeout(() => (flashSlug.value = null), FLASH_MS)
    dialogOpen.value = false
  }

  return { dialogOpen, pending, flashSlug, request, remove, confirmReplace }
}
