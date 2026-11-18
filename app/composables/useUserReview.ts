import type { Database } from '~/types/database.types'
import { listMyReviewPhotos, type MyReviewPhoto } from '~/services/review-photos'
import {
  deleteMyReview,
  getMyReview,
  isRateLimited,
  listCriteria,
  submitReview,
  type MyReview,
  type ReviewCriterion,
} from '~/services/reviews'

export type ReviewStep = 'form' | 'sent'

/**
 * Own-review flow of an item page (F3.10): global score (required) + optional criteria, the user's current review,
 * submit (create/edit via RPC) and delete. Everything is loaded in the browser once the session
 * is known, never in SSR, so the ISR-cached page carries no user data.
 * Post-moderation (D9): a submitted review is published immediately.
 */
export function useUserReview(itemId: MaybeRefOrGetter<string>, category: string) {
  const db = useGuideClient()
  const client = useSupabaseClient<Database>()
  const supabaseUrl = String(useRuntimeConfig().public.supabase?.url ?? '')
  const locale = useGuideLocale()
  const route = useRoute()
  const router = useRouter()
  const toast = useToast()
  const { t } = useI18n()
  const { isSignedIn, userId, signInTarget } = useAuth()

  const criteria = ref<ReviewCriterion[]>([])
  const mine = ref<MyReview | null>(null)
  const loaded = ref(false)
  const open = ref(false)
  const step = ref<ReviewStep>('form')
  const submitting = ref(false)
  const deleting = ref(false)
  const failed = ref(false)
  const rateLimited = ref(false)
  const photos = reactive(useReviewPhotos())
  const myPhotos = ref<MyReviewPhoto[]>([])
  const photoFailed = ref(false)

  async function load() {
    if (!userId.value) return
    try {
      const [list, review] = await Promise.all([
        criteria.value.length ? criteria.value : listCriteria(db, locale.value, category),
        getMyReview(db, toValue(itemId), userId.value),
      ])
      criteria.value = list
      mine.value = review
      myPhotos.value = review ? await listMyReviewPhotos(client, supabaseUrl, review.id).catch(() => []) : []
    } catch {
      mine.value = null
      myPhotos.value = []
    } finally {
      loaded.value = true
    }
  }

  /** Refreshes the page's public data (count, average, list) after a change. */
  const refreshPublic = () => refreshNuxtData(`item-reviews:${toValue(itemId)}:${locale.value}`)

  function openForm() {
    failed.value = false
    rateLimited.value = false
    photoFailed.value = false
    photos.reset(myPhotos.value)
    step.value = 'form'
    open.value = true
  }

  /** "Opinar" link: with a session it opens the form; without one it follows the link to sign in. */
  function onWrite(event: Event) {
    if (!isSignedIn.value) return
    event.preventDefault()
    openForm()
  }

  async function submit(
    overall: number,
    scores: Record<string, number>,
    body: string,
  ): Promise<boolean> {
    if (submitting.value) return false
    submitting.value = true
    failed.value = false
    rateLimited.value = false
    photoFailed.value = false
    try {
      await photos.settle()
      const id = await submitReview(db, { itemId: toValue(itemId), overall, scores, body, locale: locale.value })
      toast.success(t('reviews.sent'))
      return await finishPhotos(id)
    } catch (error) {
      rateLimited.value = isRateLimited(error)
      failed.value = true
      toast.error(
        t('reviews.errorTitle'),
        t(rateLimited.value ? 'reviews.rateLimited' : 'reviews.error'),
      )
      return false
    } finally {
      submitting.value = false
    }
  }

  /** The text is already saved; uploads photos and shows "sent" only when none is left failing. */
  async function finishPhotos(id: string): Promise<boolean> {
    const ok = await photos.sync(id)
    await Promise.all([load(), refreshPublic()])
    photoFailed.value = !ok
    if (ok) step.value = 'sent'
    return ok
  }

  /** Retry of the failed uploads (or "send without"), once the text is saved. */
  async function retryPhotos(skip = false) {
    const id = mine.value?.id
    if (!id || submitting.value) return
    submitting.value = true
    try {
      if (skip) photos.dropFailed()
      await finishPhotos(id)
    } finally {
      submitting.value = false
    }
  }

  async function remove() {
    if (!mine.value || deleting.value) return false
    deleting.value = true
    try {
      await deleteMyReview(db, mine.value.id)
      mine.value = null
      await refreshPublic()
      toast.success(t('reviews.deleted'))
      return true
    } catch {
      toast.error(t('reviews.deleteErrorTitle'), t('reviews.deleteError'))
      return false
    } finally {
      deleting.value = false
    }
  }

  // Load once the session is known; also reload if the user changes (login/logout).
  watch(
    userId,
    (id) => {
      loaded.value = false
      mine.value = null
      if (id) load()
    },
    { immediate: true },
  )

  // Back from Google (`?opinar=1`): open the form and clean the URL.
  watch(
    [loaded, () => route.query.opinar],
    async ([isLoaded, flag]) => {
      if (!isLoaded || !flag || !isSignedIn.value) return
      const { opinar: _drop, ...rest } = route.query
      await router.replace({ query: rest })
      openForm()
    },
    { immediate: true },
  )

  const signInLink = computed(() => signInTarget(route.path))

  return {
    criteria,
    mine,
    loaded,
    open,
    step,
    submitting,
    deleting,
    failed,
    rateLimited,
    photos,
    myPhotos,
    photoFailed,
    isSignedIn,
    signInLink,
    openForm,
    onWrite,
    submit,
    retryPhotos,
    remove,
  }
}
