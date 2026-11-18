import type { Database } from '~/types/database.types'
import { deleteReview, fetchReviews, fetchReviewItemOptions, fetchReviewsSummary, markReviewsSeen, moderateReview } from '~/services/admin/reviews'
import { ALL_OPTION, isNewReview, oldestPendingPhoto, reviewError, reviewViewOf, withItemStats, type AdminReview, type ReviewFilters, type ReviewItemStats, type ReviewView } from '~/utils/admin-reviews'

/**
 * Opiniones inbox (F6.11): filters in the URL, paged list, selected review, hide/show with "Deshacer"
 * and RGPD delete. Marks the visit on entering (D24) and keeps "Nueva" relative to the PREVIOUS visit.
 */
export function useAdminReviews() {
  const client = useSupabaseClient<Database>()
  const route = useRoute()
  const { success, error: toastError } = useAdminToast()
  const badge = useAdminReviewsBadge()

  const query = (key: string) => (typeof route.query[key] === 'string' ? (route.query[key] as string) : '')
  // A link to one item (`?item=`, from the item editor) lists all its reviews; otherwise the inbox opens on the recent ones.
  const view = computed<ReviewView>(() => reviewViewOf(route.query.vista, query('item') ? 'all' : 'recent'))
  const category = computed(() => query('tipo') || ALL_OPTION)
  const item = computed(() => query('item') || ALL_OPTION)
  const search = ref(query('q'))
  const debounced = useDebouncedValue(search, 300)
  const filters = computed<ReviewFilters>(() => ({ view: view.value, search: debounced.value, category: category.value, item: item.value }))

  function setQuery(patch: Record<string, string | undefined>) {
    const merged = { ...route.query, ...patch }
    const keep = Object.entries(merged).filter(([key, value]) => value && (key === 'vista' || value !== ALL_OPTION) && !(key === 'vista' && value === (merged.item && merged.item !== ALL_OPTION ? 'all' : 'recent')))
    return navigateTo({ query: Object.fromEntries(keep) }, { replace: true })
  }
  watch(debounced, (q) => void setQuery({ q: q.trim() || undefined }))

  // The summary is read BEFORE marking the visit, so `seen_at` is the previous visit ("Nueva" is relative to it).
  const seenAt = ref<string | null>(null)
  const summary = useAsyncData('admin-reviews-summary', () => fetchReviewsSummary(client), { server: false })
  onMounted(async () => {
    try {
      const first = await fetchReviewsSummary(client)
      seenAt.value = first.seenAt
      await markReviewsSeen(client)
      await badge.refresh() // photos still waiting keep counting
    } catch {
      // Without the mark the screen still works; "Nueva" falls back to the last 7 days.
    }
  })

  const rows = ref<AdminReview[]>([])
  // "Fotos por revisar" is a queue: the oldest pending photo first (the RPC returns newest activity first).
  const ordered = (list: AdminReview[]) => (view.value === 'photos' ? [...list].sort((a, b) => oldestPendingPhoto(a).localeCompare(oldestPendingPhoto(b))) : list)
  const total = ref(0)
  const loadingMore = ref(false)
  const list = useAsyncData(
    'admin-reviews',
    async () => {
      const page = await fetchReviews(client, filters.value, 0)
      rows.value = ordered(page.rows)
      total.value = page.total
      return page.total
    },
    { server: false, watch: [filters] },
  )
  const itemOptions = useAsyncData('admin-reviews-items', () => fetchReviewItemOptions(client), { server: false })

  async function loadMore() {
    loadingMore.value = true
    try {
      const page = await fetchReviews(client, filters.value, rows.value.length)
      rows.value = ordered([...rows.value, ...page.rows])
      total.value = page.total
    } catch {
      toastError({ message: 'No se han podido cargar más opiniones.' })
    } finally {
      loadingMore.value = false
    }
  }

  const photos = useAdminReviewPhotos(rows, () => {
    void summary.refresh()
    void badge.refresh()
  })
  /** Review being hidden that still has published photos: the page asks whether to retire them too. */
  const hidePrompt = ref<AdminReview>()

  // Selection and detail --------------------------------------------------------------------------
  const selectedId = ref<string>()
  const selected = computed(() => rows.value.find((r) => r.id === selectedId.value))
  watch(rows, (list) => {
    if (selectedId.value && !list.some((r) => r.id === selectedId.value)) selectedId.value = undefined
  })
  const move = (delta: 1 | -1) => {
    const i = rows.value.findIndex((r) => r.id === selectedId.value)
    const next = rows.value[Math.max(0, Math.min(rows.value.length - 1, (i < 0 ? (delta > 0 ? -1 : 0) : i) + delta))]
    if (next) selectedId.value = next.id
    return next
  }

  // Actions ---------------------------------------------------------------------------------------
  const busy = ref(false)
  const isNew = (r: AdminReview) => r.status !== 'hidden' && r.needsReview && isNewReview(r.lastActivityAt, seenAt.value)

  /** Applies a new status and the item's new averages to the loaded rows. */
  function patch(id: string, status: AdminReview['status'], stats: ReviewItemStats) {
    const itemId = rows.value.find((r) => r.id === id)?.itemId
    rows.value = rows.value.map((r) => {
      if (r.itemId !== itemId) return r
      const updated = r.id === id ? { ...r, status, needsReview: false } : r
      return withItemStats(updated, stats.itemAvgOverall, stats.itemVisibleCount)
    })
    void summary.refresh()
  }

  /** Hides or shows; the row stays in the list until reload so "Deshacer" lands where it was. */
  async function setStatus(review: AdminReview, status: 'visible' | 'hidden', undoable = true, skipPhotos = false): Promise<boolean> {
    if (busy.value) return false
    if (status === 'hidden' && !skipPhotos && review.photos.some((p) => p.status === 'approved')) {
      hidePrompt.value = review
      return false
    }
    busy.value = true
    const previous = review.status === 'hidden' ? 'hidden' : 'visible'
    try {
      patch(review.id, status, await moderateReview(client, review.id, status))
      success({
        message: status === 'hidden' ? 'Opinión oculta · ya no sale en la ficha' : 'Opinión visible de nuevo',
        action: undoable && previous !== status ? { label: 'Deshacer', run: () => void undo(review.id, previous) } : undefined,
      })
      return true
    } catch (e) {
      toastError({ message: reviewError(e), action: { label: 'Reintentar', run: () => void setStatus(review, status, undoable) } })
      return false
    } finally {
      busy.value = false
    }
  }
  /** Answer of the prompt: `reason` retires the published photos first; `undefined` hides only the review. */
  async function confirmHide(reason?: string) {
    const review = hidePrompt.value
    if (!review) return
    busy.value = true
    const retired = reason ? await photos.retirePublished(review, reason) : true
    busy.value = false
    if (!retired) return
    hidePrompt.value = undefined
    await setStatus({ ...review, photos: rows.value.find((r) => r.id === review.id)?.photos ?? review.photos }, 'hidden', true, true)
  }
  async function undo(id: string, status: 'visible' | 'hidden') {
    try {
      patch(id, status, await moderateReview(client, id, status))
    } catch (e) {
      toastError({ message: reviewError(e) })
    }
  }

  /** V: leaves it visible (a hidden one is shown), stores it as reviewed and moves to the next one. */
  async function approveAndNext(review: AdminReview) {
    if (busy.value) return
    busy.value = true
    try {
      patch(review.id, 'visible', await moderateReview(client, review.id, 'visible'))
      move(1)
    } catch (e) {
      toastError({ message: reviewError(e) })
    } finally {
      busy.value = false
    }
  }

  async function remove(review: AdminReview, reason: string): Promise<boolean> {
    busy.value = true
    try {
      const stats = await deleteReview(client, review.id, reason)
      rows.value = rows.value.filter((r) => r.id !== review.id).map((r) => (r.itemId === review.itemId ? withItemStats(r, stats.itemAvgOverall, stats.itemVisibleCount) : r))
      total.value -= 1
      void summary.refresh()
      success('Opinión borrada')
      return true
    } catch (e) {
      toastError({ message: reviewError(e) })
      return false
    } finally {
      busy.value = false
    }
  }

  return {
    view, category, item, search, setQuery, seenAt,
    rows, total, summary: computed(() => summary.data.value), list, itemOptions: computed(() => itemOptions.data.value ?? []),
    hasMore: computed(() => rows.value.length < total.value), loadingMore, loadMore,
    selectedId, selected, move, busy, isNew, setStatus, approveAndNext, remove,
    photos, hidePrompt, confirmHide,
  }
}
