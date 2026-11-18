import type { UnwrapNestedRefs } from 'vue'
import type { Database } from '~/types/database.types'
import { deleteReviewPhoto, getRightsVersion, uploadReviewPhoto, type MyReviewPhoto } from '~/services/review-photos'
import { processReviewPhoto, type ProcessedPhoto } from '~/utils/review-photo-image'
import {
  checkPhotoFile,
  looksLikeHeic,
  newPhotoId,
  photoErrorKind,
  REVIEW_PHOTO_INPUT_MAX_MB,
  REVIEW_PHOTO_MAX,
  REVIEW_PHOTO_RIGHTS_TEXT_VERSION,
  reviewPhotoUploadPath,
  type PhotoErrorKind,
  type RejectReason,
} from '~/utils/review-photos'

export interface PhotoItem {
  /** Photo uuid: the one registered in the database (saved) or the one it will get (new). */
  id: string
  name: string
  src: string
  state: 'preparing' | 'ready' | 'uploading' | 'error' | 'saved'
  /** 0..100 while uploading. */
  progress: number
  error?: PhotoErrorKind
  processed?: ProcessedPhoto
  /** Only saved photos. */
  storagePath?: string
}

export interface PhotoMessage {
  tone: 'error' | 'info'
  text: string
}

/**
 * Photos of the review being written or edited (F6.11b). The review must exist before a photo can
 * be registered, so new photos are prepared (re-encoded, EXIF/GPS dropped) when picked and uploaded
 * by `sync(reviewId)` right after the text is saved: the text is never lost if a photo fails.
 * Saved photos removed in the form are deleted on `sync`, so cancelling the form changes nothing.
 * Lives outside the form component so it survives the form being re-created after saving.
 */
export function useReviewPhotos() {
  const client = useSupabaseClient<Database>()
  const config = useRuntimeConfig().public.supabase
  const storage = { baseUrl: String(config?.url ?? ''), apiKey: String(config?.key ?? '') }
  const { t } = useI18n()
  const toast = useToast()

  const items = ref<PhotoItem[]>([])
  const rejected = ref<{ id: string; reason: RejectReason | null }[]>([])
  const removedSaved = ref<PhotoItem[]>([])
  const messages = ref<PhotoMessage[]>([])
  const announcement = ref('')
  const rightsAccepted = ref(false)
  const rightsMissing = ref(false)
  /** Bumped on every failed submit so the form re-focuses the box each time. */
  const rightsAttempts = ref(0)
  const working = new Set<Promise<void>>()
  let reviewId: string | null = null

  const count = computed(() => items.value.length)
  const full = computed(() => count.value >= REVIEW_PHOTO_MAX)
  const hasNew = computed(() => items.value.some((i) => i.state !== 'saved'))
  const hasFailed = computed(() => items.value.some((i) => i.state === 'error'))
  const preparing = computed(() => items.value.filter((i) => i.state === 'preparing').length)
  const uploading = computed(() => items.value.filter((i) => i.state === 'uploading' || i.state === 'ready').length)

  const patch = (id: string, changes: Partial<PhotoItem>) => {
    items.value = items.value.map((i) => (i.id === id ? { ...i, ...changes } : i))
  }
  const note = (tone: PhotoMessage['tone'], text: string) => messages.value.push({ tone, text })
  const revoke = (item: PhotoItem) => item.state !== 'saved' && item.src.startsWith('blob:') && URL.revokeObjectURL(item.src)

  /** Starts a form session from the reader's saved photos (rejected ones only leave a line of text). */
  function reset(mine: readonly MyReviewPhoto[]) {
    items.value.forEach(revoke)
    items.value = mine
      .filter((p) => p.status !== 'rejected' && p.src)
      .map((p) => ({ id: p.id, name: '', src: p.src ?? '', state: 'saved', progress: 100, storagePath: p.storagePath }))
    rejected.value = mine.filter((p) => p.status === 'rejected').map((p) => ({ id: p.id, reason: p.rejectReason }))
    removedSaved.value = []
    messages.value = []
    announcement.value = ''
    rightsAccepted.value = false
    rightsMissing.value = false
    reviewId = null
  }

  async function prepare(id: string, file: File) {
    try {
      const processed = await processReviewPhoto(file)
      patch(id, { state: 'ready', processed })
    } catch {
      items.value = items.value.filter((i) => i.id !== id)
      note('error', t(looksLikeHeic(file) ? 'reviews.photos.errors.heic' : 'reviews.photos.errors.unreadable', { name: file.name }))
    }
  }

  function add(files: File[]) {
    messages.value = []
    const left: string[] = []
    let added = 0
    for (const file of files) {
      const problem = checkPhotoFile(file)
      if (problem === 'not_image') note('error', t('reviews.photos.errors.notImage', { name: file.name }))
      else if (problem === 'too_big') note('error', t('reviews.photos.errors.tooBig', { name: file.name, mb: Math.round(file.size / 1048576), max: REVIEW_PHOTO_INPUT_MAX_MB }))
      else if (count.value >= REVIEW_PHOTO_MAX) left.push(file.name)
      else {
        const id = newPhotoId()
        items.value = [...items.value, { id, name: file.name, src: URL.createObjectURL(file), state: 'preparing', progress: 0 }]
        const job = prepare(id, file).finally(() => working.delete(job))
        working.add(job)
        added++
      }
    }
    if (left.length) note('info', t(added || count.value ? 'reviews.photos.errors.overflow' : 'reviews.photos.errors.full', { max: REVIEW_PHOTO_MAX, names: left.join(', ') }))
    if (added) announcement.value = t('reviews.photos.announce.added', { count: added, n: count.value, max: REVIEW_PHOTO_MAX }, added)
  }

  function remove(id: string) {
    const item = items.value.find((i) => i.id === id)
    if (!item) return
    messages.value = messages.value.filter((m) => !item.name || !m.text.includes(item.name))
    items.value = items.value.filter((i) => i.id !== id)
    if (item.state === 'saved') removedSaved.value.push(item)
    else revoke(item)
    announcement.value = t('reviews.photos.announce.removed', { n: count.value, max: REVIEW_PHOTO_MAX })
  }

  /** Waits for the photos being prepared (the submit button waits on this). */
  async function settle() {
    while (working.size) await Promise.all([...working])
  }

  async function uploadOne(item: PhotoItem, rightsVersion: string, id: string) {
    const { processed } = item
    if (!processed) return
    patch(item.id, { state: 'uploading', progress: 0, error: undefined })
    const path = reviewPhotoUploadPath(id, item.id, processed.ext)
    try {
      await uploadReviewPhoto(client, storage, {
        reviewId: id,
        photoId: item.id,
        path,
        blob: processed.blob,
        mime: processed.mime,
        width: processed.width,
        height: processed.height,
        rightsVersion,
        onProgress: (fraction) => patch(item.id, { progress: Math.round(fraction * 100) }),
      })
      patch(item.id, { state: 'saved', progress: 100, storagePath: path })
    } catch (error) {
      const kind = photoErrorKind(error)
      patch(item.id, { state: 'error', error: kind })
      note('error', t(MESSAGE_KEYS[kind], { name: item.name }))
    }
  }

  /**
   * Applies the form to a review that already exists: deletes what was removed, then uploads the new
   * photos one by one. Resolves false when some photo failed (it stays in the list to retry or drop).
   */
  async function sync(id: string): Promise<boolean> {
    reviewId = id
    messages.value = []
    for (const item of removedSaved.value.splice(0)) {
      try {
        await deleteReviewPhoto(client, item.id)
      } catch {
        toast.error(t('reviews.photos.errors.removeTitle'), t('reviews.photos.errors.remove'))
      }
    }
    const queue = items.value.filter((i) => i.state === 'ready' || i.state === 'error')
    if (!queue.length) return true
    const version = await getRightsVersion(client).catch(() => '')
    for (const item of queue) {
      if (!version || version !== REVIEW_PHOTO_RIGHTS_TEXT_VERSION) {
        const kind: PhotoErrorKind = version ? 'rights_outdated' : 'generic'
        patch(item.id, { state: 'error', error: kind })
        note('error', t(MESSAGE_KEYS[kind], { name: item.name }))
      } else {
        await uploadOne(item, version, id)
      }
    }
    return !hasFailed.value
  }

  /** Retries the failed uploads of the last sync. */
  const retryFailed = () => (reviewId ? sync(reviewId) : Promise.resolve(false))

  /** "Enviar sin esa foto": forgets the photos that failed. */
  function dropFailed() {
    items.value.filter((i) => i.state === 'error').forEach(revoke)
    items.value = items.value.filter((i) => i.state !== 'error')
    messages.value = []
  }

  function setRights(accepted: boolean) {
    rightsAccepted.value = accepted
    if (accepted) rightsMissing.value = false
  }

  /** The rights box is mandatory only while there is something to upload. */
  function requireRights(): boolean {
    rightsMissing.value = hasNew.value && !rightsAccepted.value
    if (rightsMissing.value) rightsAttempts.value++
    return !rightsMissing.value
  }

  onBeforeUnmount(() => items.value.forEach(revoke))

  return {
    items, rejected, messages, announcement, rightsAccepted, rightsMissing, rightsAttempts,
    count, full, hasNew, hasFailed, preparing, uploading,
    reset, add, remove, settle, sync, retryFailed, dropFailed, setRights, requireRights,
  }
}

/** What components receive: the composable wrapped in `reactive()` (refs unwrapped). */
export type ReviewPhotosState = UnwrapNestedRefs<ReturnType<typeof useReviewPhotos>>

const MESSAGE_KEYS: Record<PhotoErrorKind, string> = {
  rights_outdated: 'reviews.photos.errors.rightsOutdated',
  rights_not_accepted: 'reviews.photos.errors.rightsOutdated',
  photo_limit: 'reviews.photos.errors.limit',
  rate_limited: 'reviews.photos.errors.rate',
  forbidden: 'reviews.photos.errors.upload',
  generic: 'reviews.photos.errors.upload',
}
