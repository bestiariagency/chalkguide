import type { Database } from '~/types/database.types'
import { deleteMedia, fetchMediaById, fetchMediaCounts, fetchMediaPage, fetchMediaUsage, saveMedia } from '~/services/admin/media'
import {
  formToMediaPatch,
  mediaErrorMessage,
  type AdminMediaItem,
  type MediaCounts,
  type MediaFilter,
  type MediaForm,
  type MediaUsageRow,
} from '~/utils/admin-media-library'

/**
 * Media library screen (F6.6): filtered/searched list with incremental loading, header counters and
 * the actions of one item (save texts, usage, delete). Uploading is `useAdminMediaUpload` and
 * replacing the file `useAdminMediaReplace`; both hand the resulting row to `upsert`.
 */
export function useAdminMedia() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()

  const search = ref('')
  const filter = ref<MediaFilter>('all')
  const items = ref<AdminMediaItem[]>([])
  const total = ref(0)
  const counts = ref<MediaCounts>()
  const status = ref<'idle' | 'pending' | 'error'>('pending')
  const loadingMore = ref(false)
  const busy = ref(false)
  let token = 0

  async function load(append = false) {
    const mine = ++token
    if (append) loadingMore.value = true
    else status.value = 'pending'
    try {
      const page = await fetchMediaPage(client, { search: search.value, filter: filter.value }, append ? items.value.length : 0)
      if (mine !== token) return
      items.value = append ? [...items.value, ...page.items.filter((p) => !items.value.some((i) => i.id === p.id))] : page.items
      total.value = page.total
      status.value = 'idle'
    } catch (e) {
      if (mine !== token) return
      if (append) toastError({ message: mediaErrorMessage(e) })
      else status.value = 'error'
    } finally {
      if (mine === token) loadingMore.value = false
    }
  }
  const refreshCounts = async () => {
    try {
      counts.value = await fetchMediaCounts(client)
    } catch {
      /* the header simply keeps the previous numbers */
    }
  }
  const reload = () => Promise.all([load(), refreshCounts()])

  const debouncedSearch = useDebouncedValue(search, 300)
  watch([debouncedSearch, filter], () => void load())
  onMounted(() => void reload())

  const hasMore = computed(() => items.value.length < total.value)
  const loadMore = () => (hasMore.value && !loadingMore.value ? load(true) : undefined)
  const filtered = computed(() => !!search.value.trim() || filter.value !== 'all')

  /** A row came back from upload/replace/save: show it first if new, or update it in place. */
  function upsert(item: AdminMediaItem) {
    const at = items.value.findIndex((i) => i.id === item.id)
    if (at >= 0) items.value = items.value.map((i) => (i.id === item.id ? item : i))
    else if (filter.value === 'all' && !search.value.trim()) {
      items.value = [item, ...items.value]
      total.value++
    }
    void refreshCounts()
  }

  const selectedId = ref<string>()
  const selected = computed(() => items.value.find((i) => i.id === selectedId.value))
  const usage = ref<MediaUsageRow[]>([])
  const usageStatus = ref<'idle' | 'pending' | 'error'>('idle')
  watch(selectedId, async (id) => {
    usage.value = []
    if (!id) return (usageStatus.value = 'idle')
    usageStatus.value = 'pending'
    try {
      const rows = await fetchMediaUsage(client, id)
      if (selectedId.value === id) [usage.value, usageStatus.value] = [rows, 'idle']
    } catch {
      if (selectedId.value === id) usageStatus.value = 'error'
    }
  })

  /** Deep link `?medio=<id>`: opens the detail even when the row is not in the loaded page. */
  async function openById(id: string): Promise<boolean> {
    if (items.value.some((i) => i.id === id)) return (selectedId.value = id) !== undefined
    try {
      const item = await fetchMediaById(client, id)
      if (!item) return false
      items.value = [item, ...items.value]
      selectedId.value = id
      return true
    } catch {
      return false
    }
  }

  async function save(item: AdminMediaItem, form: MediaForm): Promise<boolean> {
    busy.value = true
    try {
      const { dominant_color: color, ...texts } = formToMediaPatch(form)
      const colorChanged = color !== (item.dominant_color ?? null)
      await saveMedia(client, item.id, colorChanged ? { ...texts, dominant_color: color } : texts)
      upsert({ ...item, ...texts, dominant_color: colorChanged ? color : item.dominant_color, updated_at: new Date().toISOString() })
      success('Imagen guardada')
      return true
    } catch (e) {
      toastError({ message: mediaErrorMessage(e) })
      return false
    } finally {
      busy.value = false
    }
  }

  async function remove(item: AdminMediaItem): Promise<boolean> {
    busy.value = true
    try {
      await deleteMedia(client, item.id, item.version)
      items.value = items.value.filter((i) => i.id !== item.id)
      total.value = Math.max(0, total.value - 1)
      void refreshCounts()
      success(`«${item.original_filename}» eliminada`)
      return true
    } catch (e) {
      toastError({ message: mediaErrorMessage(e) })
      if (['23503', 'P0002', 'PT409'].includes((e as { code?: string })?.code ?? '')) void reload()
      return false
    } finally {
      busy.value = false
    }
  }

  return { search, filter, items, total, counts, status, loadingMore, hasMore, filtered, busy, selectedId, selected, usage, usageStatus, load, reload, loadMore, upsert, openById, save, remove }
}
