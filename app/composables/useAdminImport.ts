import type { Database } from '~/types/database.types'
import { fetchLastImport, importItems, undoImportBatch } from '~/services/admin/import'
import { saveTextFile } from '~/utils/admin-download'
import type { ParsedRow } from '~/utils/admin-import-parse'
import { resultTotals, reviewCounts, type ImportReport, type ImportRowReport, type ReviewRow } from '~/utils/admin-import-report'
import { errorsCsvRows, importErrorMessage } from '~/utils/admin-import-texts'
import { toCsv } from '~/utils/csv'
import type { ItemInfo } from '~/utils/item-spec'

const IMPORT_CHUNK = 100

export type ImportPhase = 'upload' | 'reading' | 'review' | 'applying' | 'result'
export type ImportOutcome = 'done' | 'partial' | 'stopped'

interface Chunk {
  rows: ParsedRow[]
  report: ImportReport
}

const chunked = (rows: ParsedRow[]) => Array.from({ length: Math.ceil(rows.length / IMPORT_CHUNK) }, (_, i) => rows.slice(i * IMPORT_CHUNK, (i + 1) * IMPORT_CHUNK))
const sameReport = (a: ImportRowReport | undefined, b: ImportRowReport | undefined) => JSON.stringify([a?.action, a?.issues, a?.changes, a?.blockers]) === JSON.stringify([b?.action, b?.issues, b?.changes, b?.blockers])
const str = (value: unknown) => (typeof value === 'string' ? value : '')

/**
 * Importer flow (README §13, D50): file -> `dry_run` in chunks of 100 -> review -> confirm -> `apply` per chunk with the
 * hash of its `dry_run`, sharing the `batch_id` of the first one. Nothing is written until `apply`.
 */
export function useAdminImport(info: ItemInfo) {
  const client = useSupabaseClient<Database>()
  const toast = useAdminToast()
  const file = useAdminImportFile(info.category)

  const phase = ref<ImportPhase>('upload')
  const progress = reactive({ done: 0, total: 0, chunk: 0, chunks: 0 })
  const failure = ref<string>()
  const chunks = shallowRef<Chunk[]>([])
  /** After a `stale`: the rows whose report changed since the review. */
  const changedRows = ref<number[]>([])
  const stopRequested = ref(false)
  const outcome = ref<ImportOutcome>('done')
  const applied = shallowRef<ImportReport[]>([])
  const batchId = ref<string>()
  const undone = ref(false)
  const undoing = ref(false)
  const lastImport = useAsyncData(`admin-import-last-${info.category}`, () => fetchLastImport(client, info.category), { server: false })
  let run = 0

  const parsed = file.parsed
  const reviewRows = computed<ReviewRow[]>(() => {
    if (!parsed.value) return []
    const server = new Map(chunks.value.flatMap((c) => c.report.rows.map((r) => [r.row, r] as const)))
    return parsed.value.rows.map((p) => {
      const s = server.get(p.row)
      const blocked = p.issues.some((i) => i.level === 'error')
      const report: ImportRowReport = s && !blocked ? { ...s, issues: [...p.issues, ...s.issues] } : { row: p.row, action: 'error', issues: p.issues }
      return { row: p.row, name: str(p.payload.name), slug: str(p.payload.slug), cover: str(p.payload.cover), report }
    })
  })
  const counts = computed(() => reviewCounts(reviewRows.value))
  const sendable = computed(() => (parsed.value?.rows ?? []).filter((p) => !p.issues.some((i) => i.level === 'error')))
  const multiChunk = computed(() => chunks.value.length > 1)

  async function dryRun(rows: ParsedRow[], mine: number): Promise<Chunk[] | null> {
    const parts = chunked(rows)
    const out: Chunk[] = []
    Object.assign(progress, { done: 0, total: rows.length, chunk: 0, chunks: parts.length })
    for (const part of parts) {
      const report = await importItems(client, info.category, part.map((r) => r.payload), 'dry_run')
      if (mine !== run) return null
      out.push({ rows: part, report })
      progress.done += part.length
      progress.chunk++
    }
    return out
  }

  /** Compares the (already read) file with the server: also behind "Comprobar fotos". */
  async function check() {
    const mine = ++run
    failure.value = undefined
    changedRows.value = []
    phase.value = 'reading'
    try {
      const result = await dryRun(sendable.value, mine)
      if (!result) return
      chunks.value = result
      phase.value = 'review'
    } catch (e) {
      if (mine !== run) return
      failure.value = importErrorMessage(e)
      phase.value = 'upload'
    }
  }

  async function open(selected: File) {
    undone.value = false
    chunks.value = []
    phase.value = 'reading'
    await file.load(selected)
    if (!file.parsed.value) phase.value = 'upload'
    else if (file.ready.value) await check()
    else phase.value = 'upload'
  }
  async function acceptUnknown() {
    file.acceptUnknown()
    await check()
  }
  async function chooseSheet(name: string) {
    file.chooseSheet(name)
    if (file.parsed.value && file.ready.value) await check()
  }
  async function setSeparator(separator: ';' | ',') {
    file.setSeparator(separator)
    if (file.parsed.value && file.ready.value) await check()
  }

  function reset() {
    run++
    file.reset()
    chunks.value = []
    changedRows.value = []
    failure.value = undefined
    phase.value = 'upload'
  }

  /** Clean rows only: the errors do not go (all-or-nothing per call stays clean). */
  async function startApply(withoutErrors: boolean) {
    const mine = ++run
    failure.value = undefined
    stopRequested.value = false
    const previous = chunks.value
    phase.value = 'applying'
    try {
      let plan = previous
      if (withoutErrors) {
        const clean = new Set(reviewRows.value.filter((r) => r.report.action !== 'error').map((r) => r.row))
        const again = await dryRun(sendable.value.filter((p) => clean.has(p.row)), mine)
        if (!again) return
        plan = again
        if (again.some((c) => c.report.summary.errors > 0)) {
          chunks.value = await dryRun(sendable.value, mine) ?? previous
          changedRows.value = [...clean]
          phase.value = 'review'
          return
        }
      }
      const done: ImportReport[] = []
      let batch: string | undefined
      let result: ImportOutcome = 'done'
      Object.assign(progress, { done: 0, total: plan.reduce((n, c) => n + c.rows.length, 0), chunk: 0, chunks: plan.length })
      for (const [i, chunk] of plan.entries()) {
        if (i > 0 && stopRequested.value) {
          result = 'stopped'
          break
        }
        progress.chunk = i + 1
        let report: ImportReport
        try {
          report = await importItems(client, info.category, chunk.rows.map((r) => r.payload), 'apply', { hash: chunk.report.hash, batchId: batch })
        } catch (e) {
          failure.value = importErrorMessage(e)
          result = 'partial'
          break
        }
        if (report.stale) {
          const old = new Map(chunk.report.rows.map((r) => [r.row, r]))
          changedRows.value = report.rows.filter((r) => !sameReport(old.get(r.row), r)).map((r) => r.row)
          chunks.value = withoutErrors ? ((await dryRun(sendable.value, mine)) ?? previous) : plan.map((c) => (c === chunk ? { ...c, report: { ...report, mode: 'dry_run' } } : c))
          if (!done.length) {
            phase.value = 'review'
            return
          }
          result = 'partial'
          break
        }
        batch ??= report.batch_id ?? undefined
        done.push(report)
        progress.done += chunk.rows.length
      }
      applied.value = done
      batchId.value = batch
      outcome.value = result
      phase.value = 'result'
      void lastImport.refresh()
    } catch (e) {
      failure.value = importErrorMessage(e)
      phase.value = 'review'
    }
  }

  async function undo() {
    if (!batchId.value) return
    undoing.value = true
    try {
      const result = await undoImportBatch(client, batchId.value)
      const gone = result.results.filter((r) => r.result === 'deleted' || r.result === 'discarded').length
      const kept = totals.value.updated
      undone.value = true
      toast.success(`Importación deshecha · ${gone} ${gone === 1 ? 'ficha' : 'fichas'}${kept ? `. Las ${kept} actualizadas no cambian` : ''}`)
      void lastImport.refresh()
    } catch (e) {
      toast.error({ message: importErrorMessage(e), action: { label: 'Cerrar', run: () => {} } })
    } finally {
      undoing.value = false
    }
  }

  const totals = computed(() => resultTotals(applied.value))
  const excluded = computed(() => (parsed.value?.rows.length ?? 0) - applied.value.reduce((n, r) => n + r.summary.rows, 0))

  function downloadErrors() {
    const rows = errorsCsvRows(reviewRows.value.map((r) => ({ row: r.row, issues: r.report.issues })), parsed.value?.letters ?? {}, (row) => parsed.value?.rows.find((p) => p.row === row)?.payload)
    saveTextFile(`errores-importacion-${info.route}.csv`, toCsv(['fila', 'columna', 'campo', 'valor', 'problema'], rows))
  }

  // Leaving while writing can leave the import half done (README §13.1).
  const warn = (event: BeforeUnloadEvent) => {
    if (phase.value === 'applying') event.preventDefault()
  }
  onMounted(() => window.addEventListener('beforeunload', warn))
  onBeforeUnmount(() => window.removeEventListener('beforeunload', warn))
  onBeforeRouteLeave(() => phase.value !== 'applying' || window.confirm('Se está importando. Si sales ahora, puede quedar a medias.'))

  return {
    file, phase, progress, failure, chunks, multiChunk, changedRows, stopRequested, outcome, batchId, undone, undoing, lastImport,
    reviewRows, counts, totals, excluded,
    open, acceptUnknown, chooseSheet, setSeparator, check, reset, startApply, undo, downloadErrors,
  }
}
