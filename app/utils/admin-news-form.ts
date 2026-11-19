import { videoIncomplete, type AdminNewsVideo } from './admin-news-videos'
import type { Database } from '~/types/database.types'
import { NEWS_LIMITS, type AdminNews, type NewsScope } from '~/utils/admin-news'

type NewsInsert = Database['guide']['Tables']['news']['Insert']

export type RelatedKind = 'item' | 'article' | 'event'
export interface RelatedLink {
  kind: RelatedKind
  id: string
  label: string
}

/** Editor state of a news item. `sourceUrl` keeps the full `https://…` address; the field shows it without the scheme. */
export interface NewsForm {
  titleEs: string
  titleEn: string
  summaryEs: string
  summaryEn: string
  insightEs: string
  insightEn: string
  seoKeywordEs: string
  seoKeywordEn: string
  metaDescriptionEs: string
  metaDescriptionEn: string
  sourceName: string
  sourceUrl: string
  /** `YYYY-MM-DD`. */
  publishedOn: string
  categoryId: string
  scope: NewsScope
  tags: string[]
  withImage: boolean
  mediaId: string
  /** File name of the chosen media, to show it. */
  mediaName: string
  imageLicense: string
  imageCredit: string
  links: RelatedLink[]
  /** Up to 2 YouTube videos (saved with `admin_set_news_videos`, after the item). */
  videos: AdminNewsVideo[]
}

export type NewsField = 'titleEs' | 'titleEn' | 'summaryEs' | 'summaryEn' | 'insightEs' | 'insightEn' | 'seoKeywordEs' | 'seoKeywordEn' | 'metaDescriptionEs' | 'metaDescriptionEn' | 'sourceName' | 'sourceUrl' | 'publishedOn' | 'categoryId' | 'image' | 'imageLicense' | 'imageCredit' | 'tags' | 'links' | 'videos'
export type NewsErrors = Partial<Record<NewsField, string>>

export const MAX_LINKS = 3

export function emptyNewsForm(categoryId = ''): NewsForm {
  return { titleEs: '', titleEn: '', summaryEs: '', summaryEn: '', insightEs: '', insightEn: '', seoKeywordEs: '', seoKeywordEn: '', metaDescriptionEs: '', metaDescriptionEn: '', sourceName: '', sourceUrl: '', publishedOn: '', categoryId, scope: 'es', tags: [], withImage: false, mediaId: '', mediaName: '', imageLicense: '', imageCredit: '', links: [], videos: [] }
}

export function newsToForm(n: AdminNews, links: RelatedLink[] = [], mediaName = ''): NewsForm {
  return {
    titleEs: n.titleEs,
    titleEn: n.titleEn ?? '',
    summaryEs: n.summaryEs,
    summaryEn: n.summaryEn ?? '',
    insightEs: n.insightEs ?? '',
    insightEn: n.insightEn ?? '',
    seoKeywordEs: n.seoKeywordEs ?? '',
    seoKeywordEn: n.seoKeywordEn ?? '',
    metaDescriptionEs: n.metaDescriptionEs ?? '',
    metaDescriptionEn: n.metaDescriptionEn ?? '',
    sourceName: n.sourceName,
    sourceUrl: n.sourceUrl,
    publishedOn: n.sourcePublishedOn ?? '',
    categoryId: n.categoryId,
    scope: n.scope,
    tags: [...n.tags],
    withImage: !!n.mediaId,
    mediaId: n.mediaId ?? '',
    mediaName,
    imageLicense: n.imageLicense ?? '',
    imageCredit: n.imageCredit ?? '',
    links,
    videos: n.videos.map((v) => ({ ...v })),
  }
}

/** Same rule as the CHECK of `news.source_url`: https, no credentials, port or spaces. */
const SOURCE_URL = /^https:\/\/[^\s/?#"<>\\@:]+([/?#][^\s"<>\\]*)?$/

/** Accepts what the field holds (with or without the scheme) and returns the full address. */
export const fullSourceUrl = (value: string) => {
  const v = value.trim()
  return /^https?:\/\//i.test(v) ? v : v ? `https://${v}` : ''
}

export function validateNews(form: NewsForm, opts: { agent: boolean; publishing?: boolean }): NewsErrors {
  const e: NewsErrors = {}
  if (opts.publishing && form.videos.some(videoIncomplete)) e.videos = 'Un vídeo publicado necesita título y canal. Complétalos en la sección Vídeos.'
  const title = form.titleEs.trim()
  if (!title) e.titleEs = 'Falta el título.'
  else if (title.length > NEWS_LIMITS.title) e.titleEs = `El título pasa de ${NEWS_LIMITS.title} caracteres.`
  const summary = form.summaryEs.trim()
  if (!summary) e.summaryEs = 'Falta el resumen. Con tus palabras, no copiado de la fuente.'
  else if (summary.length > NEWS_LIMITS.summary) e.summaryEs = `El resumen pasa de ${NEWS_LIMITS.summary} caracteres.`
  if (form.insightEs.trim().length > NEWS_LIMITS.insight) e.insightEs = `El aporte pasa de ${NEWS_LIMITS.insight} caracteres.`
  if (form.insightEn.trim().length > NEWS_LIMITS.insight) e.insightEn = `El aporte pasa de ${NEWS_LIMITS.insight} caracteres.`
  for (const lang of ['Es', 'En'] as const) {
    const keyword = form[`seoKeyword${lang}`].trim()
    if (keyword && (keyword.length < 2 || keyword.length > NEWS_LIMITS.keyword)) e[`seoKeyword${lang}`] = `La keyword lleva entre 2 y ${NEWS_LIMITS.keyword} caracteres.`
    if (form[`metaDescription${lang}`].trim().length > NEWS_LIMITS.metaDescription) e[`metaDescription${lang}`] = `La meta description pasa de ${NEWS_LIMITS.metaDescription} caracteres.`
  }
  if (form.titleEn.trim().length > NEWS_LIMITS.title) e.titleEn = `El título pasa de ${NEWS_LIMITS.title} caracteres.`
  if (form.summaryEn.trim().length > NEWS_LIMITS.summary) e.summaryEn = `El resumen pasa de ${NEWS_LIMITS.summary} caracteres.`
  // Title and summary in English go together: one without the other keeps it out of /en/news.
  if (form.titleEn.trim() && !form.summaryEn.trim() && !e.summaryEn) e.summaryEn = 'Con título en inglés hace falta el resumen. Sin los dos, no sale en /en/news.'
  if (form.summaryEn.trim() && !form.titleEn.trim() && !e.titleEn) e.titleEn = 'Con resumen en inglés hace falta el título. Sin los dos, no sale en /en/news.'
  if (!form.sourceName.trim()) e.sourceName = 'Falta el nombre del medio.'
  if (!opts.agent) {
    const url = fullSourceUrl(form.sourceUrl)
    if (!url) e.sourceUrl = 'Falta el enlace a la noticia original.'
    else if (url.length > 1000 || !SOURCE_URL.test(url)) e.sourceUrl = 'El enlace debe empezar por https:// y no llevar usuario, puerto ni espacios.'
  }
  if (!form.categoryId) e.categoryId = 'Elige una categoría.'
  if (form.tags.length > NEWS_LIMITS.tags) e.tags = `Máximo ${NEWS_LIMITS.tags} etiquetas.`
  if (form.withImage) {
    if (!form.mediaId) e.image = 'Elige la imagen de Medios.'
    if (!form.imageLicense) e.imageLicense = 'Falta la licencia.'
    if (!form.imageCredit.trim()) e.imageCredit = 'Falta el crédito.'
  }
  return e
}

const orNull = (v: string) => v.trim() || null

/** Columns an admin may write (`news` grants). The `source_url` of an agent item is immutable: it is never sent. */
export function newsWrite(form: NewsForm, opts: { agent: boolean }) {
  const image = form.withImage && form.mediaId
  return {
    title_es: form.titleEs.trim(),
    title_en: orNull(form.titleEn),
    summary_es: form.summaryEs.trim(),
    summary_en: orNull(form.summaryEn),
    insight_es: orNull(form.insightEs),
    insight_en: orNull(form.insightEn),
    seo_keyword_es: orNull(form.seoKeywordEs),
    seo_keyword_en: orNull(form.seoKeywordEn),
    meta_description_es: orNull(form.metaDescriptionEs),
    meta_description_en: orNull(form.metaDescriptionEn),
    source_name: form.sourceName.trim(),
    ...(opts.agent ? {} : { source_url: fullSourceUrl(form.sourceUrl) }),
    source_published_on: form.publishedOn || null,
    category_id: form.categoryId,
    scope: form.scope,
    tags: form.tags,
    media_id: image ? form.mediaId : null,
    image_license: image ? form.imageLicense : null,
    image_credit: image ? orNull(form.imageCredit) : null,
  }
}

/** Insert of a manual item: the slug is made here from the title (the trigger would only fill it when it is null). */
export function newsInsert(form: NewsForm, status: 'draft' | 'published'): NewsInsert {
  return { ...newsWrite(form, { agent: false }), source_url: fullSourceUrl(form.sourceUrl), slug: newsSlug(form.titleEs), status }
}

export function newsSlug(title: string): string {
  const base = slugify(title).slice(0, 80).replace(/-+$/, '') || 'noticia'
  const hex = Array.from(crypto.getRandomValues(new Uint8Array(3)), (b) => b.toString(16).padStart(2, '0')).join('')
  return `${base}-${hex}`
}

export interface NewsError {
  field?: NewsField
  message: string
  reload?: boolean
}

/** Database errors of the news writes in the words of the panel. */
export function newsError(error: unknown): NewsError {
  const e = error as { code?: string; message?: string } | null
  const code = e?.code
  const message = e?.message ?? ''
  if (/news_en_incomplete/.test(message)) return { field: 'summaryEn', message: 'Título y resumen en inglés van juntos: o los dos o ninguno.' }
  if (/news_media_alt/.test(message)) return { field: 'image', message: 'La imagen no tiene texto alternativo en español. Complétalo en Medios.' }
  if (/news_image_rights/.test(message)) return { field: 'imageLicense', message: 'Una imagen necesita licencia y crédito.' }
  if (/news_video_meta/.test(message)) return { field: 'videos', message: 'Un vídeo publicado necesita título y canal. Complétalos en la sección Vídeos.' }
  if (code === '23514') return { message: 'Algún dato no cumple las reglas (formato o longitud). Revisa los campos.' }
  if (code === '23505') return { message: 'Ya hay una noticia con esa dirección. Cambia un poco el título.' }
  if (code === '42501' && /provenance/.test(message)) return { message: 'El origen de una noticia del agente no se puede cambiar.' }
  if (code === 'PT423') return { message: 'Una noticia publicada no se elimina: retírala primero. Si vino del agente, recházala en su lugar.', reload: true }
  if (code === '55000') return { message: 'La noticia ya había cambiado de estado (quizá en otra pestaña). Se ha recargado la lista.', reload: true }
  if (code === '23503') return { message: 'La categoría tiene noticias: elige otra a la que moverlas.' }
  if (code === '42501') return { message: 'No tienes permiso para hacer esto. Vuelve a entrar en el panel.' }
  if (code === 'P0002') return { message: 'La noticia ya no existe. Se ha recargado la lista.', reload: true }
  if (/fetch|network|failed to load/i.test(message)) return { message: 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.' }
  return { message: 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.' }
}
