import type { Database } from '~/types/database.types'
import { assignCover, findCoverCandidates } from '~/services/admin/item-covers'
import { classifyCover, type CoverState } from '~/utils/admin-import-covers'
import { itemErrorMessage, type AdminItemRow } from '~/utils/admin-items'
import type { AdminMedia } from '~/utils/admin-media'
import type { AdminMediaItem } from '~/utils/admin-media-library'
import type { ItemInfo } from '~/utils/item-spec'

export interface CoverRow {
  item: AdminItemRow
  state: CoverState
  options: AdminMediaItem[]
  choice?: AdminMediaItem
  /** Alt (ES) to write in Medios when the chosen photo has none. */
  altEs: string
  checked: boolean
}

const ORDER: Record<CoverState, number> = { none: 0, several: 1, similar: 2, match: 3 }
const needsAlt = (row: CoverRow) => !!row.choice && !row.choice.alt_es && !row.altEs.trim()

/** "Asignar portadas" (README §13.6): suggests a photo of Medios by slug for each item without cover and assigns the ticked ones. */
export function useAdminCovers(info: ItemInfo, onDone: () => void | Promise<void>) {
  const client = useSupabaseClient<Database>()
  const toast = useAdminToast()
  const rows = ref<CoverRow[]>([])
  const loading = ref(false)
  const busy = ref(false)

  async function load(items: readonly AdminItemRow[]) {
    loading.value = true
    try {
      const built: CoverRow[] = []
      for (let i = 0; i < items.length; i += 6) {
        built.push(...(await Promise.all(items.slice(i, i + 6).map(async (item) => {
          const found = await findCoverCandidates(client, item.slug).catch(() => [])
          const { state, options, choice } = classifyCover(item.slug, found)
          return { item, state, options, choice, altEs: '', checked: state === 'match' && !!choice?.alt_es } satisfies CoverRow
        }))))
      }
      rows.value = built.sort((a, b) => ORDER[a.state] - ORDER[b.state])
    } finally {
      loading.value = false
    }
  }

  function choose(row: CoverRow, media: AdminMediaItem) {
    row.choice = media
    row.checked = !!media.alt_es
    row.altEs = ''
  }
  /** The picker gives the short media; the full row (captions, credit) is needed to write the alt without losing them. */
  async function pick(row: CoverRow, media: AdminMedia) {
    const full = (await findCoverCandidates(client, media.original_filename).catch(() => [])).find((m) => m.id === media.id)
    if (full) choose(row, full)
    else toast.error({ message: 'No se ha podido leer la foto de Medios. Inténtalo de nuevo.', action: { label: 'Cerrar', run: () => {} } })
  }
  const ready = (row: CoverRow) => !!row.choice && !needsAlt(row)
  const selected = computed(() => rows.value.filter((r) => r.checked && ready(r)))

  async function assign(): Promise<boolean> {
    busy.value = true
    let done = 0
    const failed: string[] = []
    for (const row of selected.value) {
      try {
        await assignCover(client, info.category, { itemId: row.item.id, published: row.item.published, version: row.item.updated_at, media: row.choice!, altEs: row.altEs.trim() || undefined })
        done++
      } catch (e) {
        failed.push(`«${row.item.name}»: ${itemErrorMessage(e, undefined, info.noun)}`)
      }
    }
    busy.value = false
    if (done) toast.success(`${done} ${done === 1 ? 'portada asignada' : 'portadas asignadas'}. Las publicadas la reciben en su borrador de cambios.`)
    if (failed.length) toast.error({ message: `No se pudo asignar: ${failed[0]}${failed.length > 1 ? ` (y ${failed.length - 1} más)` : ''}`, action: { label: 'Cerrar', run: () => {} } })
    await onDone()
    return failed.length === 0
  }

  return { rows, loading, busy, selected, load, choose, pick, ready, assign }
}
