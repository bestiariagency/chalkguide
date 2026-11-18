import type { Database } from '~/types/database.types'
import { fetchRecentExport, countExport, runExport } from '~/services/admin/exports'
import { buildFilters, exportFileName, EXPORT_CONFIGS, type ExportCount, type ExportResult, type ExportFormat, type ExportInitial, type ExportTarget, type RecentExport } from '~/utils/admin-export'
import { toCsv } from '~/utils/csv'

const COUNT_DEBOUNCE_MS = 250
/** Aborting the fetch does not stop the transaction (PostgREST): after cancelling we look for a new entry at these delays (ms). */
const LATE_CHECKS_MS = [1500, 4000]
// Texts of the cancel toast (loro-lola).
const CANCELLED_REGISTERED = 'Exportación cancelada · quedó registrada en Actividad'
const CANCELLED_UNSURE = 'Exportación cancelada · puede que quede registrada en Actividad'
const CANCELLED_NOTHING = 'Exportación cancelada · no se ha descargado ni registrado nada'
const FAIL_NOTHING = 'No se ha podido preparar el archivo. No se ha descargado ni registrado nada.'
const FAIL_UNSURE = 'No se ha podido preparar el archivo. No se ha descargado; puede que quede registrada en Actividad.'
const FAIL_REGISTERED = 'No se ha podido guardar el archivo. No se ha descargado, pero la exportación quedó registrada en Actividad.'
const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))
const serverCode = (e: unknown) => (e as { code?: string } | undefined)?.code
const isAbort = (e: unknown) => (e as { name?: string } | undefined)?.name === 'AbortError' || /abort/i.test((e as Error | undefined)?.message ?? '')

function saveFile(name: string, content: string, mime: string) {
  const url = URL.createObjectURL(new Blob([content], { type: `${mime};charset=utf-8` }))
  const link = Object.assign(document.createElement('a'), { href: url, download: name })
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 10_000)
}

/**
 * State of the export modal (F6.15, README §12.5): the draft inherited from the listing, the live count (debounced,
 * never logs), and the single `admin_export` call that exports and registers. The file is built only when it answers.
 */
export function useAdminExport(target: ExportTarget, initial: ExportInitial, onDone: () => void = () => {}) {
  const client = useSupabaseClient<Database>()
  const toast = useAdminToast()
  const config = EXPORT_CONFIGS[target]
  const personal = config.module === 'subscribers'

  const draft = reactive({ status: initial.status ?? config.defaultStatus, values: { ...initial.values } as Record<string, string> })
  const format = ref<ExportFormat>('csv')
  const withBody = ref(false)
  const preset = ref<'min' | 'proof'>('min')
  const purpose = ref('')
  const confirmed = ref(false)
  watch(() => [draft.status, preset.value], () => (confirmed.value = false))

  const options = computed(() => ({ format: format.value, withBody: withBody.value, preset: preset.value, purpose: purpose.value || undefined }))
  const filters = computed(() => buildFilters(config, draft, options.value))

  // Live count
  const count = ref<ExportCount>()
  const counting = ref(true)
  const countError = ref<string>()
  const stamp = ref(new Date())
  let timer: ReturnType<typeof setTimeout> | undefined
  let countCall: AbortController | undefined
  function recount() {
    countCall?.abort()
    const call = (countCall = new AbortController())
    counting.value = true
    countError.value = undefined
    stamp.value = new Date()
    clearTimeout(timer)
    timer = setTimeout(async () => {
      try {
        const result = await countExport(client, config.module, filters.value, call.signal)
        if (call.signal.aborted) return
        count.value = result
      } catch (e) {
        if (call.signal.aborted || isAbort(e)) return
        count.value = undefined
        countError.value = serverCode(e) || 'sin código'
      }
      if (!call.signal.aborted) counting.value = false
    }, COUNT_DEBOUNCE_MS)
  }
  // `purpose` is not needed to count: changing it must not recount.
  watch(() => JSON.stringify({ ...filters.value, purpose: undefined }), recount, { immediate: true })

  // Last export of this module
  const recent = ref<RecentExport | null>()
  onMounted(async () => {
    try {
      recent.value = await fetchRecentExport(client, config.module)
    } catch {
      recent.value = undefined
    }
  })

  /** After Cancelar: reading the log to tell whether the server registered the export (§12.5.6). */
  const checking = ref(false)
  const fileName = computed(() => exportFileName(config, draft.status, format.value, stamp.value))
  const rowCount = computed(() => count.value?.rowCount ?? 0)
  const disabledReason = computed(() => {
    if (countError.value) return 'Sin recuento: no se puede descargar.'
    if (counting.value || !count.value) return undefined
    if (!rowCount.value) return 'Sin filas no se genera archivo.'
    if (personal && (!purpose.value || !confirmed.value)) return 'Elige para qué lo exportas y marca la casilla.'
    return undefined
  })
  const canDownload = computed(() => !checking.value && !counting.value && !!count.value && rowCount.value > 0 && !disabledReason.value)

  // Download
  const preparing = ref(false)
  let exportCall: AbortController | undefined
  /** `admin_export` was actually sent (cancelling before that is the only case where nothing can have been registered). */
  let sent = false
  /** Last logged export right before calling `admin_export` (`undefined` = not read yet or could not be read). */
  let beforeId: number | null | undefined
  let alive = true
  let errorToast: number | undefined
  function dismissError() {
    if (errorToast !== undefined) toast.dismiss(errorToast)
    errorToast = undefined
  }
  function fail(message: string) {
    errorToast = toast.error({ message, action: { label: 'Reintentar', run: () => alive && void download() } })
  }
  /** Downloads the file and calls `onDone` (closes the modal) when it is saved. */
  async function download() {
    if (!canDownload.value || preparing.value || checking.value) return
    dismissError()
    preparing.value = true
    sent = false
    beforeId = undefined
    const call = (exportCall = new AbortController())
    try {
      beforeId = await fetchRecentExport(client, config.module).then((r) => r?.id ?? null, () => undefined)
      if (call.signal.aborted) return
      sent = true
      let result: ExportResult
      try {
        result = await runExport(client, config.module, format.value, filters.value, call.signal)
      } catch (e) {
        if (call.signal.aborted || isAbort(e)) return
        // The RPC is one transaction: an answer from the server with a code means nothing was registered. Without it (network) we cannot know.
        fail(serverCode(e) ? FAIL_NOTHING : FAIL_UNSURE)
        return
      }
      if (call.signal.aborted) return
      try {
        const name = exportFileName(config, draft.status, format.value)
        if (format.value === 'csv') saveFile(name, toCsv(result.export.columns, result.rows), 'text/csv')
        else saveFile(name, JSON.stringify(result, null, 2), 'application/json')
      } catch {
        // The server already answered: the export is registered for sure, only the browser failed.
        fail(FAIL_REGISTERED)
        return
      }
      toast.success(`Descargado · ${countOf(result.export.row_count, 'fila', 'filas')} · registrado en Actividad`)
      onDone()
    } finally {
      preparing.value = false
    }
  }
  /** Aborts the request. The server may still have registered it: the toast says so when a new entry shows up (§12.5.6). */
  async function cancel() {
    if (!preparing.value) return
    const before = beforeId
    const wasSent = sent
    exportCall?.abort()
    preparing.value = false
    if (!wasSent) return void toast.info(CANCELLED_NOTHING)
    checking.value = true
    try {
      let previous = 0
      for (const at of LATE_CHECKS_MS) {
        await wait(at - previous)
        previous = at
        const latest = await fetchRecentExport(client, config.module).then((r) => r, () => undefined)
        if (before !== undefined && latest && latest.id !== before) {
          recent.value = latest
          return void toast.info(CANCELLED_REGISTERED)
        }
      }
      toast.info(CANCELLED_UNSURE)
    } finally {
      checking.value = false
    }
  }

  onBeforeUnmount(() => {
    alive = false
    dismissError()
    clearTimeout(timer)
    countCall?.abort()
    exportCall?.abort()
  })

  return { config, personal, draft, format, withBody, preset, purpose, confirmed, count, counting, countError, rowCount, recent, fileName, disabledReason, canDownload, preparing, checking, download, cancel, recount }
}
