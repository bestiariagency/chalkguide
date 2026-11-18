import type { Database } from '~/types/database.types'
import { fetchMediaByIds } from '~/services/admin/article-editor'
import { fetchContentAlt, type AltEntity } from '~/services/admin/content-alt'
import type { AltIssue } from '~/utils/content-alt'

/**
 * D27 check of the saved content: every image without alt text (ES, and EN where required), with its file name.
 * `id` may be a getter (pages know it only after loading). Call `refresh()` when a publish dialog opens. A failed check never blocks (the server still refuses).
 */
export function useContentAlt(entity: AltEntity, id: MaybeRefOrGetter<string>) {
  const client = useSupabaseClient<Database>()
  const issues = ref<AltIssue[]>([])
  /** English alt missing where the English text requires it (blocks) / elsewhere (warning only). */
  const issuesEn = ref<AltIssue[]>([])
  const adviceEn = ref<AltIssue[]>([])
  const loading = ref(false)

  async function refresh() {
    const target = toValue(id)
    if (!target) return
    loading.value = true
    try {
      const rows = await fetchContentAlt(client, entity, target)
      const es = rows.filter((r) => r.missing_alt_es)
      const en = rows.filter((r) => r.missing_alt_en)
      const media = await fetchMediaByIds(client, [...new Set([...es, ...en].map((r) => r.media_id))])
      const names = new Map(media.map((m) => [m.id, m.original_filename]))
      const issue = (r: { media_id: string }) => ({ id: r.media_id, name: names.get(r.media_id) ?? 'Imagen' })
      issues.value = es.map(issue)
      issuesEn.value = en.filter((r) => r.alt_en_required).map(issue)
      adviceEn.value = en.filter((r) => !r.alt_en_required).map(issue)
    } catch {
      issues.value = []
      issuesEn.value = []
      adviceEn.value = []
    } finally {
      loading.value = false
    }
  }
  return { issues, issuesEn, adviceEn, loading, refresh }
}
