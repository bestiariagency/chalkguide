import type { NewsVideo } from '~/types/news'
import { YOUTUBE_ID } from './article-embeds'

export const MAX_NEWS_VIDEOS = 2

interface VideoInput {
  position?: number
  youtube_id: string
  title?: string | null
  channel?: string | null
  lang?: string | null
}

/** Watch page of a video; only call it with a validated ID (FV3). */
export const youtubeWatchUrl = (id: string) => `https://www.youtube.com/watch?v=${id}`

const text = (value: string | null | undefined) => value?.trim() || null

/** Rows of `news_videos` to what the page paints: ordered, each ID revalidated (FV3), no repeats, at most 2. */
export function toNewsVideos(rows: readonly VideoInput[] | null | undefined): NewsVideo[] {
  const seen = new Set<string>()
  return [...(rows ?? [])]
    .sort((a, b) => (a.position ?? 0) - (b.position ?? 0))
    .flatMap((row): NewsVideo[] => {
      if (!YOUTUBE_ID.test(row.youtube_id) || seen.has(row.youtube_id)) return []
      seen.add(row.youtube_id)
      return [{ youtubeId: row.youtube_id, title: text(row.title), channel: text(row.channel), lang: /^[a-z]{2}$/.test(row.lang ?? '') ? row.lang! : null }]
    })
    .slice(0, MAX_NEWS_VIDEOS)
}

/** Name of a language code in the page language («catalán» / «Catalan»); `null` if empty or unknown. */
export function languageName(code: string | null | undefined, pageLocale: string): string | null {
  if (!code) return null
  try {
    return new Intl.DisplayNames([pageLocale], { type: 'language' }).of(code) ?? null
  } catch {
    return null
  }
}

/** Language of a video, only when it differs from the page language; `null` otherwise. */
export const videoLanguageName = (lang: string | null, pageLocale: string): string | null =>
  lang === pageLocale ? null : languageName(lang, pageLocale)

/** Revalidates videos already in page shape (FV3): same rules as `toNewsVideos`. */
export const cleanNewsVideos = (videos: readonly NewsVideo[]): NewsVideo[] =>
  toNewsVideos(videos.map((v) => ({ youtube_id: v.youtubeId, title: v.title, channel: v.channel, lang: v.lang })))
