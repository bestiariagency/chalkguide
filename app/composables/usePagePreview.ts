import type { Database } from '~/types/database.types'
import { fetchPageDraft } from '~/services/admin/page-drafts'
import { fetchPageForEdit, refreshPageBodies } from '~/services/admin/pages'
import { PAGE_DEFS, todayIso, type PageKey } from '~/utils/admin-pages'
import { applyDraftPage, draftPageOf } from '~/utils/page-changes'
import { pageFormFromRow, textChanged } from '~/utils/page-form'
import { previewPage } from '~/utils/page-preview'

/** Data of the panel preview: the page as the editor has it now (stored draft over the published version, or the draft page). */
export function usePagePreview(key: PageKey, locale: Ref<'es' | 'en'>) {
  const client = useSupabaseClient<Database>()
  const load = useAsyncData(
    `admin-page-preview-${key}`,
    async () => {
      const loaded = await fetchPageForEdit(client, key)
      if (!loaded) return null
      const draft = await fetchPageDraft(client, loaded.id)
      const [row, shown] = await refreshPageBodies(client, [loaded, applyDraftPage(loaded, draftPageOf(draft?.payload))])
      return row && shown ? { row, shown, hasDraft: !!draft } : null
    },
    { server: false },
  )
  const supabaseUrl = String(useRuntimeConfig().public.supabase?.url ?? '')
  // Sanitizing loads the sanitizer on demand (panel only, D64): the preview is built asynchronously.
  const page = shallowRef<Awaited<ReturnType<typeof previewPage>>>(null)
  const building = ref(true)
  watch(
    [() => load.data.value, locale],
    async ([data, lang]) => {
      building.value = true
      const built = data ? await previewPage(pageFormFromRow(data.shown), lang, supabaseUrl) : null
      if (data !== load.data.value || lang !== locale.value) return // superseded by a newer run
      page.value = built
      building.value = false
    },
    { immediate: true },
  )
  /** "Última actualización" of a legal page: the stored date, or today if never published or the text changed. */
  const revisedOn = computed<string | null>(() => {
    const data = load.data.value
    if (!data || !PAGE_DEFS[key].legal) return null
    const moved = !data.row.published || !data.row.revised_on || textChanged(pageFormFromRow(data.row), pageFormFromRow(data.shown))
    return moved ? todayIso() : data.row.revised_on
  })
  return { load, page, building, revisedOn, live: computed(() => !!load.data.value?.row.published), hasDraft: computed(() => load.data.value?.hasDraft ?? false), notFound: computed(() => load.data.value === null) }
}
