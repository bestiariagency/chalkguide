import type { Database } from '~/types/database.types'
import { publishItemDraft } from '~/services/admin/item-drafts'
import { fetchPublishBlockers, publishItems } from '~/services/admin/import'
import type { AdminItemRow } from '~/utils/admin-items'
import { draftFailureText, planPublish, publishFailureText } from '~/utils/admin-publish-batch'
import type { ItemInfo } from '~/utils/item-spec'

const MAX_IDS = 100
const NO_PERMISSION = '42501'
const errorCode = (e: unknown) => (e as { code?: string }).code

const fichas = (n: number) => `${n} ${n === 1 ? 'ficha' : 'fichas'}`
function successText(published: number, revised: number) {
  const parts: string[] = []
  if (published) parts.push(`${fichas(published)} ${published === 1 ? 'publicada' : 'publicadas'}`)
  const updated = revised === 1 ? 'actualizada' : 'actualizadas'
  if (revised) parts.push(published ? `${revised} ${updated}` : `${fichas(revised)} ${updated}`)
  return `${parts.join(' y ')} · ya se ${published + revised === 1 ? 've' : 'ven'} en el sitio`
}

/** "Publicar en lote" (README §13.7): blockers per item from the server, the plan of a selection and the `publish_items` calls. */
export function useAdminPublishBatch(info: ItemInfo, rows: Ref<AdminItemRow[]>, onDone: () => void | Promise<void>) {
  const client = useSupabaseClient<Database>()
  const toast = useAdminToast()
  const blockers = useAsyncData(`admin-blockers-${info.category}`, () => fetchPublishBlockers(client, info.category), { server: false })
  const map = computed(() => blockers.data.value ?? undefined)
  const busy = ref(false)

  const planOf = (selection: readonly AdminItemRow[]) => planPublish(selection, map.value)

  async function publish(selection: readonly AdminItemRow[]): Promise<boolean> {
    const plan = planOf(selection)
    const ids = plan.ready.map((row) => row.id)
    if (!ids.length && !plan.changes.length) return false
    busy.value = true
    const names = new Map(rows.value.map((row) => [row.id, row.name]))
    let published = 0
    let revised = 0
    const failures: { id: string; text: string }[] = []
    try {
      for (let i = 0; i < ids.length; i += MAX_IDS) {
        const result = await publishItems(client, ids.slice(i, i + MAX_IDS))
        published += result.published
        for (const r of result.results) if (!r.ok) failures.push({ id: r.id, text: publishFailureText(r.code, r.blockers) })
      }
      for (const row of plan.changes) {
        try {
          await publishItemDraft(client, row.id)
          revised++
        } catch (e) {
          const code = errorCode(e)
          if (code === NO_PERMISSION) throw e
          failures.push({ id: row.id, text: draftFailureText(code) })
        }
      }
    } catch (e) {
      toast.error({ message: errorCode(e) === NO_PERMISSION ? 'No tienes permiso para publicar. Vuelve a entrar en el panel.' : 'No se ha podido publicar. Inténtalo de nuevo.', action: { label: 'Cerrar', run: () => {} } })
      return false
    } finally {
      busy.value = false
    }
    if (published || revised) toast.success({ message: successText(published, revised), action: { label: 'Ver', run: () => void navigateTo(info.publicPath) } })
    if (failures.length) {
      const first = failures[0]!
      toast.error({ message: `No se publicó «${names.get(first.id) ?? 'una ficha'}»: ${first.text}${failures.length > 1 ? ` (y ${failures.length - 1} más)` : ''}.`, action: { label: 'Abrir', run: () => void navigateTo(adminPath(`${info.route}/${first.id}`)) } })
    }
    await Promise.all([blockers.refresh(), onDone()])
    return failures.length === 0
  }

  return { blockers: map, loading: computed(() => blockers.status.value === 'pending'), busy, planOf, publish, refresh: blockers.refresh }
}
