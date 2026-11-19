import type { Database } from '~/types/database.types'
import { saveNewsVideos } from '~/services/admin/news'
import { videoError, type AdminNewsVideo } from '~/utils/admin-news-videos'
import { newsError } from '~/utils/admin-news-form'

/**
 * Videos of the inbox detail: every change (add, edit, move, remove) is saved at once with `admin_set_news_videos` and the
 * list is reloaded afterwards. If the write fails the list goes back to what it was and the message shows under the section.
 */
export function useAdminNewsVideos(newsId: () => string, initial: () => readonly AdminNewsVideo[], onSaved: () => void | Promise<void>) {
  const client = useSupabaseClient<Database>()
  const videos = ref<AdminNewsVideo[]>(initial().map((v) => ({ ...v })))
  const saving = ref(false)
  const error = ref('')
  watch(initial, (next) => !saving.value && (videos.value = next.map((v) => ({ ...v }))))

  async function set(next: AdminNewsVideo[]) {
    const before = videos.value
    videos.value = next
    saving.value = true
    error.value = ''
    try {
      await saveNewsVideos(client, newsId(), next)
      await onSaved()
    } catch (e) {
      videos.value = before
      error.value = (videoError(e) ?? newsError(e)).message
    } finally {
      saving.value = false
    }
  }
  return { videos, saving, error, set }
}
