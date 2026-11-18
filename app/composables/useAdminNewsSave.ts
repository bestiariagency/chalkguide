import type { Database } from '~/types/database.types'
import { createNews, saveNewsLinks, updateNews } from '~/services/admin/news'
import type { AdminNews } from '~/utils/admin-news'
import { newsError, type NewsError, type NewsForm } from '~/utils/admin-news-form'

export type NewsSaveAction = 'draft' | 'publish' | 'save' | 'save-publish'

/**
 * Saves the news drawer. Like events, a news item is small and is saved at once (no draft of changes): a new one as a draft
 * or published, an existing one in place; «Guardar y publicar» writes and publishes in the same update. The error (field or
 * banner) stays in `error` for the drawer. Related links are replaced after the item is written.
 */
export function useAdminNewsSave(reload: () => Promise<void>) {
  const client = useSupabaseClient<Database>()
  const { success } = useAdminToast()
  const busy = ref(false)
  const error = ref<NewsError>()

  async function save(news: AdminNews | undefined, form: NewsForm, action: NewsSaveAction): Promise<boolean> {
    if (busy.value) return false
    busy.value = true
    error.value = undefined
    try {
      const publishing = action === 'publish' || action === 'save-publish'
      let id = news?.id
      if (!news) id = await createNews(client, form, publishing ? 'published' : 'draft')
      else await updateNews(client, news.id, form, { agent: news.source === 'agent', status: action === 'save-publish' ? 'published' : undefined })
      if (id) await saveNewsLinks(client, id, form.links)
      success(
        publishing
          ? 'Publicada · sale en /noticias en unos minutos'
          : !news
            ? 'Guardada como borrador · está en Por revisar'
            : news.status === 'draft'
              ? 'Guardada · sigue por revisar'
              : 'Guardada · se actualiza en el sitio en unos minutos',
      )
      await reload()
      return true
    } catch (e) {
      error.value = newsError(e)
      if (error.value.reload) await reload()
      return false
    } finally {
      busy.value = false
    }
  }

  return { busy, error, save }
}
