import type { Database } from '~/types/database.types'
import { removeFromStorage, replaceMedia, uploadToStorage } from '~/services/admin/media'
import { mediaErrorMessage, mediaStoragePath, MEDIA_MAX_BYTES, validateImageFile, type AdminMediaItem } from '~/utils/admin-media-library'
import { prepareImage, type PreparedImage } from '~/utils/media-image'

/**
 * Replace the file of one media item: choose (validated and prepared in the browser, with a preview
 * of the new one), then upload and switch the row to the new object. Texts and credit stay. The old
 * object is removed afterwards (best effort: a failure leaves an orphan, never a broken page).
 */
export function useAdminMediaReplace(onReplaced: (item: AdminMediaItem) => void) {
  const client = useSupabaseClient<Database>()
  const publicConfig = useRuntimeConfig().public.supabase
  const storage = { baseUrl: String(publicConfig?.url ?? ''), apiKey: String(publicConfig?.key ?? '') }
  const { success, error: toastError } = useAdminToast()

  const prepared = ref<PreparedImage>()
  const preview = ref<string>()
  const fileName = ref('')
  const error = ref<string>()
  const progress = ref(0)
  const busy = ref(false)

  function reset() {
    if (preview.value) URL.revokeObjectURL(preview.value)
    prepared.value = preview.value = error.value = undefined
    progress.value = 0
    fileName.value = ''
  }

  async function choose(file: File | undefined) {
    reset()
    if (!file) return
    fileName.value = file.name
    error.value = validateImageFile(file)
    if (error.value) return
    try {
      const image = await prepareImage(file)
      if (image.blob.size > MEDIA_MAX_BYTES) throw new Error('Pesa más de 10 MB incluso tras optimizarla.')
      prepared.value = image
      preview.value = URL.createObjectURL(image.blob)
    } catch (e) {
      error.value = (e as Error).message
    }
  }

  async function confirm(item: AdminMediaItem): Promise<boolean> {
    const image = prepared.value
    if (!image) return false
    busy.value = true
    const path = mediaStoragePath(item.id, item.version + 1, item.original_filename, image.mime)
    let uploaded = false
    try {
      await uploadToStorage(client, storage, { path, blob: image.blob, mime: image.mime, onProgress: (f) => (progress.value = f) })
      uploaded = true
      const replaced = await replaceMedia(client, item.id, item.version, {
        storage_path: path,
        original_filename: item.original_filename,
        width: image.width,
        height: image.height,
        dominant_color: image.color,
      })
      void removeFromStorage(client, [replaced.previous_storage_path]).catch(() => undefined)
      onReplaced({
        ...item,
        storage_path: replaced.storage_path,
        version: replaced.version,
        mime_type: replaced.mime_type,
        size_bytes: replaced.size_bytes,
        width: image.width,
        height: image.height,
        dominant_color: image.color,
        updated_at: replaced.updated_at,
      })
      const uses = item.usage_count
      success(uses ? `Imagen reemplazada (v${replaced.version}) en ${uses} ${uses === 1 ? 'sitio' : 'sitios'}` : `Imagen reemplazada (v${replaced.version})`)
      reset()
      return true
    } catch (e) {
      if (uploaded) void removeFromStorage(client, [path]).catch(() => undefined)
      toastError({ message: mediaErrorMessage(e) })
      return false
    } finally {
      busy.value = false
    }
  }

  onBeforeUnmount(reset)
  return { prepared, preview, fileName, error, progress, busy, choose, confirm, reset }
}
