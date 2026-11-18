import type { Locale, PageContent, RawBody } from '~/types/domain'
import { MEDIA_COLUMNS, refreshBodyHtml, toMediaRef } from './media'
import { type GuideClient, pick, unwrap, unwrapMaybe } from './client'

/** Pages whose own share image (`og_media_id`) is used; the legal ones always use the default. */
const OWN_SHARE_IMAGE = new Set(['about', 'transparency'])

/** Editorial page by its stable key (`about`, `transparency`, `privacy`, `cookies`, `legal_notice`). */
export async function getPageByKey(
  db: GuideClient,
  locale: Locale,
  key: string,
): Promise<RawBody<PageContent> | null> {
  const row = unwrapMaybe(
    await db
      .from('pages')
      .select(
        `key, slug_es, slug_en, title_es, title_en, body_html_es, body_html_en, has_en,
        seo_title_es, seo_title_en, seo_description_es, seo_description_en, noindex, og_media_id, revised_on`,
      )
      .eq('key', key)
      .eq('published', true)
      .maybeSingle(),
  )
  if (!row || (locale === 'en' && !row.has_en)) return null
  const ogImage =
    row.og_media_id && OWN_SHARE_IMAGE.has(row.key)
      ? toMediaRef(unwrapMaybe(await db.from('media').select(MEDIA_COLUMNS).eq('id', row.og_media_id).maybeSingle()), locale)
      : null
  return {
    key: row.key,
    slug: pick(locale, row.slug_es, row.slug_en) ?? row.slug_es,
    title: pick(locale, row.title_es, row.title_en) ?? row.title_es,
    bodyHtml: await refreshBodyHtml(db, pick(locale, row.body_html_es, row.body_html_en) ?? ''),
    hasEn: row.has_en === true,
    seoTitle: pick(locale, row.seo_title_es, row.seo_title_en),
    seoDescription: pick(locale, row.seo_description_es, row.seo_description_en),
    noindex: row.noindex,
    revisedOn: row.revised_on,
    ogImage,
  }
}

export type PageAvailability = Record<string, { en: boolean }>

/** Which editorial pages are published and whether they have English: one light query. */
export async function getPageAvailability(db: GuideClient): Promise<PageAvailability> {
  const rows = unwrap(await db.from('pages').select('key, has_en').eq('published', true))
  return Object.fromEntries(rows.map((row) => [row.key, { en: row.has_en === true }]))
}
