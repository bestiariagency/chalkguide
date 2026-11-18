import type { Database } from '~/types/database.types'
import { createMedia, removeFromStorage, uploadToStorage } from '~/services/admin/media'
import { mediaErrorMessage, mediaStoragePath, newMediaId, MEDIA_MAX_BYTES, validateImageFile, type AdminMediaItem } from '~/utils/admin-media-library'
import { prepareImage } from '~/utils/media-image'

export interface UploadEntry {
  key: number
  name: string
  status: 'queued' | 'preparing' | 'uploading' | 'done' | 'error'
  /** 0..1 */
  progress: number
  error?: string
  size?: number
  color?: string
  preview?: string
  media?: AdminMediaItem
  controller: AbortController
}

const CONCURRENCY = 2

/**
 * Upload queue: validates (type, <= 10 MB), prepares in the browser (EXIF/GPS stripped, <= 2400 px,
 * colour), uploads with real progress and creates the `media` row. Per-file errors never stop the
 * rest. `onUploaded` receives every created row; `onBatchDone` the summary of a finished batch.
 */
export function useAdminMediaUpload(handlers: {
  onUploaded: (item: AdminMediaItem) => void
  onBatchDone: (done: AdminMediaItem[], failed: number) => void
}) {
  const client = useSupabaseClient<Database>()
  const publicConfig = useRuntimeConfig().public.supabase
  const storage = { baseUrl: String(publicConfig?.url ?? ''), apiKey: String(publicConfig?.key ?? '') }
  const entries = ref<UploadEntry[]>([])
  const files = new Map<number, File>()
  let nextKey = 1
  let running = 0
  let batch: { done: AdminMediaItem[]; failed: number } = { done: [], failed: 0 }

  const active = computed(() => entries.value.some((e) => ['queued', 'preparing', 'uploading'].includes(e.status)))
  const patch = (key: number, changes: Partial<UploadEntry>) => {
    entries.value = entries.value.map((e) => (e.key === key ? { ...e, ...changes } : e))
  }
  const dropPreview = (e: UploadEntry) => e.preview && URL.revokeObjectURL(e.preview)

  function add(list: FileList | File[]) {
    const incoming = [...list]
    if (!incoming.length) return
    if (!active.value) {
      entries.value.forEach(dropPreview)
      entries.value = []
      batch = { done: [], failed: 0 }
    }
    for (const file of incoming) {
      const key = nextKey++
      const error = validateImageFile(file)
      const entry: UploadEntry = { key, name: file.name, status: error ? 'error' : 'queued', progress: 0, error, size: file.size, controller: new AbortController() }
      if (error) batch.failed++
      else {
        entry.preview = URL.createObjectURL(file)
        files.set(key, file)
      }
      entries.value = [...entries.value, entry]
    }
    pump()
  }

  function pump() {
    while (running < CONCURRENCY) {
      const next = entries.value.find((e) => e.status === 'queued')
      if (!next) break
      running++
      void process(next).finally(() => {
        running--
        pump()
        if (!active.value && running === 0 && (batch.done.length || batch.failed)) {
          const summary = batch
          batch = { done: [], failed: 0 }
          handlers.onBatchDone(summary.done, summary.failed)
        }
      })
    }
  }

  async function process(entry: UploadEntry) {
    const file = files.get(entry.key)!
    let path: string | undefined
    let uploaded = false
    try {
      patch(entry.key, { status: 'preparing' })
      const image = await prepareImage(file)
      if (image.blob.size > MEDIA_MAX_BYTES) throw new Error(`Pesa más de 10 MB incluso tras optimizarla.`)
      if (entry.controller.signal.aborted) throw new DOMException('Cancelada', 'AbortError')
      const id = newMediaId()
      path = mediaStoragePath(id, 1, file.name, image.mime)
      patch(entry.key, { status: 'uploading', color: image.color })
      await uploadToStorage(client, storage, {
        path,
        blob: image.blob,
        mime: image.mime,
        signal: entry.controller.signal,
        onProgress: (progress) => patch(entry.key, { progress }),
      })
      uploaded = true
      const media = await createMedia(client, {
        id,
        storage_path: path,
        original_filename: file.name.slice(0, 255),
        width: image.width,
        height: image.height,
        dominant_color: image.color,
      })
      patch(entry.key, { status: 'done', progress: 1, media, size: image.blob.size })
      batch.done.push(media)
      handlers.onUploaded(media)
    } catch (e) {
      // Only an object that failed to register is removed (23505 = it was already registered).
      if (path && uploaded && (e as { code?: string })?.code !== '23505') void removeFromStorage(client, [path]).catch(() => undefined)
      const cancelled = (e as Error)?.name === 'AbortError'
      if (cancelled) entries.value = entries.value.filter((x) => x.key !== entry.key)
      else {
        patch(entry.key, { status: 'error', error: (e as Error)?.message && !(e as { code?: string }).code ? (e as Error).message : mediaErrorMessage(e) })
        batch.failed++
      }
    } finally {
      files.delete(entry.key)
    }
  }

  function cancel(key: number) {
    const entry = entries.value.find((e) => e.key === key)
    if (!entry) return
    if (entry.status === 'queued') {
      files.delete(key)
      entries.value = entries.value.filter((e) => e.key !== key)
    } else entry.controller.abort()
  }
  function dismiss(key: number) {
    const entry = entries.value.find((e) => e.key === key)
    if (entry) dropPreview(entry)
    entries.value = entries.value.filter((e) => e.key !== key)
  }
  const clear = () => {
    entries.value.filter((e) => !['queued', 'preparing', 'uploading'].includes(e.status)).forEach(dropPreview)
    entries.value = entries.value.filter((e) => ['queued', 'preparing', 'uploading'].includes(e.status))
  }
  onBeforeUnmount(() => entries.value.forEach((e) => (dropPreview(e), e.controller.abort())))

  return { entries, active, add, cancel, dismiss, clear }
}
