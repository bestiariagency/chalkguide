import { parseYoutubeId, YOUTUBE_ID } from './article-embeds'
import { MAX_NEWS_VIDEOS } from './news-videos'

/** YouTube video of a news item as the panel edits it (`news_videos`). Title and channel are third-party or agent text: interpolate only. */
export interface AdminNewsVideo {
  youtubeId: string
  title: string
  channel: string
  /** Two-letter code or '' (unknown). */
  lang: string
}

export const VIDEO_TITLE_MAX = 200
export const VIDEO_CHANNEL_MAX = 120
export const VIDEO_LANGS: readonly { value: string; label: string }[] = [
  { value: '', label: 'Sin indicar' },
  { value: 'es', label: 'Español' },
  { value: 'ca', label: 'Catalán' },
  { value: 'en', label: 'Inglés' },
  { value: 'fr', label: 'Francés' },
  { value: 'it', label: 'Italiano' },
  { value: 'de', label: 'Alemán' },
]
export const videoLangLabel = (lang: string) => VIDEO_LANGS.find((l) => l.value === lang)?.label ?? lang

/** Only a validated ID builds these URLs (FV8): never a free value. */
export const youtubeThumbUrl = (id: string) => `https://i.ytimg.com/vi/${id}/mqdefault.jpg`
export const VIDEO_LINK_REL = 'nofollow noopener noreferrer ugc'

/** `admin_list_news.videos` (jsonb) to the panel shape; anything with an invalid ID is dropped. */
export function toAdminVideos(raw: unknown): AdminNewsVideo[] {
  if (!Array.isArray(raw)) return []
  const str = (v: unknown) => (typeof v === 'string' ? v : '')
  return raw
    .filter((r): r is Record<string, unknown> => !!r && typeof r === 'object')
    .sort((a, b) => Number(a.position ?? 0) - Number(b.position ?? 0))
    .flatMap((r) => (YOUTUBE_ID.test(str(r.youtube_id)) ? [{ youtubeId: str(r.youtube_id), title: str(r.title), channel: str(r.channel), lang: str(r.lang) }] : []))
}

/** `agent_meta.videos` (IDs the routine proposed). */
export const toProposedIds = (raw: unknown): string[] => (Array.isArray(raw) ? raw.filter((v): v is string => typeof v === 'string' && YOUTUBE_ID.test(v)) : [])

export type AddVideoResult = { videos: AdminNewsVideo[]; added: AdminNewsVideo } | { error: string }

/** Adds what was pasted (URL or ID, FV11): normalised with `parseYoutubeId`, max 2, no repeats. Title and channel start empty: Xavi fills them. */
export function addVideo(list: readonly AdminNewsVideo[], raw: string): AddVideoResult {
  if (list.length >= MAX_NEWS_VIDEOS) return { error: 'Máximo 2. Quita uno para añadir otro.' }
  const id = parseYoutubeId(raw)
  if (!id) return { error: 'No es un enlace de YouTube. Vale youtube.com/watch?v=…, youtu.be/…, /shorts/… o /embed/….' }
  if (list.some((v) => v.youtubeId === id)) return { error: 'Este vídeo ya está en la lista.' }
  const added = { youtubeId: id, title: '', channel: '', lang: '' }
  return { videos: [...list, added], added }
}

export const moveVideo = (list: readonly AdminNewsVideo[], index: number, delta: 1 | -1): AdminNewsVideo[] => {
  const to = index + delta
  if (to < 0 || to >= list.length) return [...list]
  const next = [...list]
  next.splice(to, 0, next.splice(index, 1)[0]!)
  return next
}

/** Credit missing (a published item needs title and channel in every video, `news_video_meta`). */
export const videoIncomplete = (v: Pick<AdminNewsVideo, 'title' | 'channel'>) => !v.title.trim() || !v.channel.trim()

/** `p_videos` of `admin_set_news_videos`: the ID and the credit, nothing else. */
export const videosPayload = (list: readonly AdminNewsVideo[]) =>
  list.slice(0, MAX_NEWS_VIDEOS).map((v) => ({ youtube_id: v.youtubeId, title: v.title.trim() || null, channel: v.channel.trim() || null, lang: v.lang || null }))

export interface VideoError {
  index: number | null
  field: 'youtube_id' | 'title' | 'channel' | 'lang' | null
  message: string
}

const FIELD_TEXT = { youtube_id: 'El enlace no es válido.', title: 'El título no es válido (hasta 200 caracteres, sin caracteres de control).', channel: 'El canal no es válido (hasta 120 caracteres, sin caracteres de control).', lang: 'El idioma no es válido.' } as const

/** `22023` (detail `videos[i].campo`) and `23514 news_video_meta` of `admin_set_news_videos` as a field error; `null` for anything else. */
export function videoError(error: unknown): VideoError | null {
  const e = error as { code?: string; message?: string; detail?: string; details?: string } | null
  const text = `${e?.message ?? ''} ${e?.detail ?? ''} ${e?.details ?? ''}`
  if (/news_video_meta/.test(text)) return { index: null, field: null, message: 'Un vídeo publicado necesita título y canal. Complétalos.' }
  if (e?.code === '22023' && /videos/.test(text)) {
    const match = /videos\[(\d+)\](?:\.(youtube_id|title|channel|lang))?/.exec(text)
    const field = (match?.[2] ?? null) as VideoError['field']
    return { index: match ? Number(match[1]) : null, field, message: field ? FIELD_TEXT[field] : 'Los vídeos no son válidos (máximo 2, sin repetir).' }
  }
  if (e?.code === '23514') return { index: null, field: null, message: 'Algún título o canal no cumple las reglas (longitud o caracteres no permitidos).' }
  return null
}
