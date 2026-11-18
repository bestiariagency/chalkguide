import type { Database } from '~/types/database.types'
import type { Article } from '~/types/domain'
import { fetchArticleDraft } from '~/services/admin/article-drafts'
import { fetchArticleForEdit, fetchMediaByIds, refreshArticleBodies } from '~/services/admin/article-editor'
import { fetchArticleAuthors, fetchArticleCategories } from '~/services/admin/articles'
import { articleDisplay } from '~/utils/admin-articles'
import { applyDraftArticle, draftArticleOf } from '~/utils/article-changes'
import { formFromRow } from '~/utils/article-form'
import { previewArticle } from '~/utils/article-preview'
import type { FormLocale } from '~/utils/article-form'

/**
 * Data of the panel preview: the article as the editor has it now (stored draft laid over the
 * published version, or the unpublished article), turned into the public `Article` shape.
 */
export function useArticlePreview(id: string, locale: Ref<FormLocale>) {
  const client = useSupabaseClient<Database>()
  const load = useAsyncData(
    `admin-article-preview-${id}`,
    async () => {
      const loaded = await fetchArticleForEdit(client, id)
      if (!loaded) return null
      const draft = await fetchArticleDraft(client, id)
      const [row, shown] = await refreshArticleBodies(client, [loaded, applyDraftArticle(loaded, draftArticleOf(draft?.payload))])
      if (!row || !shown) return null
      const ids = [shown.cover_media_id].filter((v): v is string => !!v)
      const [categories, authors, media] = await Promise.all([fetchArticleCategories(client), fetchArticleAuthors(client), fetchMediaByIds(client, ids)])
      return { row, shown, hasDraft: !!draft, categories, authors, media }
    },
    { server: false },
  )
  const supabaseUrl = String(useRuntimeConfig().public.supabase?.url ?? '')
  // Sanitizing loads the sanitizer on demand (panel only, D64): the article is built asynchronously.
  const article = shallowRef<Article | null>(null)
  const building = ref(true)
  watch(
    [() => load.data.value, locale],
    async ([data, lang]) => {
      building.value = true
      const built = data ? await buildArticle(data, lang) : null
      if (data !== load.data.value || lang !== locale.value) return // superseded by a newer run
      article.value = built
      building.value = false
    },
    { immediate: true },
  )
  type Loaded = NonNullable<typeof load.data.value>
  function buildArticle(data: Loaded, lang: FormLocale) {
    const form = formFromRow(data.shown)
    const category = data.categories.find((c) => c.id === form.categoryId)
    return previewArticle(form, lang, { id, updatedAt: data.row.updated_at, publishedAt: data.row.published_at, categoryName: category?.name ?? null, authorName: data.authors.find((a) => a.id === form.authorId)?.name ?? null, cover: data.media[0] ?? null, supabaseUrl })
  }
  /** The article is live (published): the preview can show the published version or its draft of changes. */
  const live = computed(() => (load.data.value ? articleDisplay(load.data.value.row) === 'published' : false))
  return { load, article, building, live, hasDraft: computed(() => load.data.value?.hasDraft ?? false), notFound: computed(() => load.data.value === null) }
}
