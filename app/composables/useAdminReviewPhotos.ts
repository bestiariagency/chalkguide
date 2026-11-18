import type { Ref } from 'vue'
import type { Database } from '~/types/database.types'
import { approvePhoto, rejectPhoto, signOriginals } from '~/services/admin/review-photos'
import { photoError, withPhoto, type AdminReview, type AdminReviewPhoto } from '~/utils/admin-reviews'
import { reviewPhotoPublicUrl } from '~/utils/review-photos'

/**
 * Moderation of reader photos in the Opiniones inbox (F6.11b): approve (re-encoded copy), reject with
 * a reason, retire, approve all, and reject the published photos when a review is hidden. Works on
 * the inbox rows (`rows`) and tells the caller when counters should be reloaded.
 */
export function useAdminReviewPhotos(rows: Ref<AdminReview[]>, onChanged: () => void) {
  const client = useSupabaseClient<Database>()
  const config = useRuntimeConfig().public.supabase
  const storage = { baseUrl: String(config?.url ?? ''), apiKey: String(config?.key ?? '') }
  const { success, error: toastError } = useAdminToast()
  const signed = ref(new Map<string, string>())
  const busy = ref(false)

  // Originals live in a private bucket: sign the ones the loaded rows need, in one call.
  watch(
    rows,
    async (list) => {
      const missing = list.flatMap((r) => r.photos).filter((p) => p.status !== 'approved' && !signed.value.has(p.storagePath)).map((p) => p.storagePath)
      if (!missing.length) return
      try {
        const urls = await signOriginals(client, missing)
        signed.value = new Map([...signed.value, ...urls])
      } catch {
        // Without a preview the cards show a placeholder; the actions still work.
      }
    },
    { immediate: true },
  )

  /** Image to show for a photo (public copy if approved, signed original otherwise). */
  const srcOf = (photo: AdminReviewPhoto): string | undefined =>
    photo.status === 'approved' && photo.publicPath ? reviewPhotoPublicUrl(storage.baseUrl, photo.publicPath) : signed.value.get(photo.storagePath)

  function patch(reviewId: string, photoId: string, changes: Partial<AdminReviewPhoto>) {
    rows.value = rows.value.map((r) => {
      const photo = r.id === reviewId ? r.photos.find((p) => p.id === photoId) : undefined
      return photo ? withPhoto(r, { ...photo, ...changes }) : r
    })
  }

  async function approve(review: AdminReview, photo: AdminReviewPhoto): Promise<boolean> {
    try {
      const done = await approvePhoto(client, storage, photo)
      patch(review.id, photo.id, { status: 'approved', publicPath: done.publicPath, width: done.width, height: done.height, rejectReason: null })
      return true
    } catch (e) {
      toastError({ message: photoError(e), action: { label: 'Reintentar', run: () => void approveOne(review, photo) } })
      return false
    }
  }

  async function approveOne(review: AdminReview, photo: AdminReviewPhoto) {
    if (busy.value) return
    busy.value = true
    try {
      if (await approve(review, photo)) {
        success('Foto publicada en la ficha')
        onChanged()
      }
    } finally {
      busy.value = false
    }
  }

  /** Approves every pending photo of the review, one by one; stops at the first failure. */
  async function approveAll(review: AdminReview): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    try {
      const pending = review.photos.filter((p) => p.status === 'pending')
      let done = 0
      for (const photo of pending) {
        if (!(await approve(review, photo))) break
        done++
      }
      if (done) {
        success(done === 1 ? 'Foto publicada en la ficha' : `${done} fotos publicadas en la ficha`)
        onChanged()
      }
      return done === pending.length
    } finally {
      busy.value = false
    }
  }

  async function reject(review: AdminReview, photo: AdminReviewPhoto, reason: string) {
    if (busy.value) return
    busy.value = true
    const wasPending = photo.status === 'pending'
    try {
      await rejectPhoto(client, photo.id, reason)
      patch(review.id, photo.id, { status: 'rejected', publicPath: null, rejectReason: reason })
      onChanged()
      // A pending photo keeps its original, so the rejection can be undone; a retired one cannot (its original is gone).
      success({
        message: wasPending ? 'Foto rechazada · no sale en la ficha' : 'Foto retirada · ya no sale en la ficha',
        action: wasPending ? { label: 'Deshacer', run: () => void approveOne(review, { ...photo, status: 'rejected' }) } : undefined,
      })
    } catch (e) {
      toastError({ message: photoError(e) })
    } finally {
      busy.value = false
    }
  }

  /** Hiding a review does not close its photos' public URLs: retire the published ones as well. */
  async function retirePublished(review: AdminReview, reason: string): Promise<boolean> {
    try {
      for (const photo of review.photos.filter((p) => p.status === 'approved')) {
        await rejectPhoto(client, photo.id, reason)
        patch(review.id, photo.id, { status: 'rejected', publicPath: null, rejectReason: reason })
      }
      onChanged()
      return true
    } catch (e) {
      toastError({ message: photoError(e) })
      return false
    }
  }

  return { busy, srcOf, approveOne, approveAll, reject, retirePublished }
}
