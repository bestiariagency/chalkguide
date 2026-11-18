import { localizedRoutes } from '../../i18n/localized-routes'

/**
 * Embedded content of the article body (F6.4 · 2c): item cards and videos. Pure helpers shared by the
 * editor nodes, the item picker and the sanitizer (single source for the shapes it accepts).
 */
export type ItemKind = 'gym' | 'resoler' | 'shoe'
export type EmbedLocale = 'es' | 'en'

export const ITEM_KINDS: readonly ItemKind[] = ['gym', 'resoler', 'shoe']

export const ITEM_KIND_LABEL: Record<ItemKind, string> = { gym: 'Rocódromo', resoler: 'Resolador', shoe: 'Pie de gato' }

const ROUTE_OF: Record<ItemKind, 'climbing-gyms-slug' | 'climbing-shoe-resoling-slug' | 'climbing-shoes-slug'> = {
  gym: 'climbing-gyms-slug',
  resoler: 'climbing-shoe-resoling-slug',
  shoe: 'climbing-shoes-slug',
}

const SLUG = '[a-z0-9]+(?:-[a-z0-9]+)*'
/** Slugs are capped at 120 characters (lookahead keeps the capture groups unchanged). */
const SLUG_MAX = '(?=.{1,120}$)'
export const ITEM_CARD_ATTR = new RegExp(`^(gym|resoler|shoe):${SLUG_MAX}(${SLUG})$`)
const SLUG_ONLY = new RegExp(`^${SLUG_MAX}${SLUG}$`)

/** Relative path of an item page in the language of the body (`/rocodromos/x`, `/en/climbing-gyms/x`). */
export function itemCardHref(kind: ItemKind, slug: string, locale: EmbedLocale): string {
  const pattern = localizedRoutes[ROUTE_OF[kind]][locale].replace('/[slug]', '')
  return `${locale === 'en' ? '/en' : ''}${pattern}/${slug}`
}

export const isItemSlug = (slug: string) => SLUG_ONLY.test(slug)

/**
 * `data-item-card` value is trusted only when it is well formed AND the `href` is exactly the item
 * page (either language). Returns the parsed card or `null`.
 */
export function parseItemCard(card: string | undefined, href: string | undefined): { kind: ItemKind; slug: string } | null {
  const match = ITEM_CARD_ATTR.exec(card ?? '')
  if (!match || !href) return null
  const kind = match[1] as ItemKind
  const slug = match[2]!
  return href === itemCardHref(kind, slug, 'es') || href === itemCardHref(kind, slug, 'en') ? { kind, slug } : null
}

// --- Video -------------------------------------------------------------------------------------

export const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/
export const YOUTUBE_EMBED_SRC = /^https:\/\/www\.youtube-nocookie\.com\/embed\/([A-Za-z0-9_-]{11})$/

export const VIDEO_SANDBOX = 'allow-scripts allow-same-origin allow-presentation allow-popups allow-popups-to-escape-sandbox'
export const VIDEO_REFERRER_POLICY = 'strict-origin-when-cross-origin'

export const videoEmbedSrc = (id: string) => `https://www.youtube-nocookie.com/embed/${id}`

/** YouTube video ID from a watch / youtu.be / shorts / embed URL (or a bare 11-char ID); `null` otherwise. */
export function parseYoutubeId(raw: string): string | null {
  const value = raw.trim()
  if (YOUTUBE_ID.test(value)) return value
  let url: URL
  try {
    url = new URL(/^https?:\/\//i.test(value) ? value : `https://${value}`)
  } catch {
    return null
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return null
  const host = url.hostname.replace(/^(www\.|m\.)/, '')
  let id: string | null | undefined = null
  if (host === 'youtu.be') id = url.pathname.split('/')[1]
  else if (host === 'youtube.com' || host === 'youtube-nocookie.com') {
    const [, kind, second] = url.pathname.split('/')
    id = kind === 'watch' ? url.searchParams.get('v') : ['embed', 'shorts', 'live', 'v'].includes(kind ?? '') ? second : null
  }
  return id && YOUTUBE_ID.test(id) ? id : null
}

export const VIDEO_TITLE: Record<EmbedLocale, string> = { es: 'Vídeo incrustado', en: 'Embedded video' }
export const VIDEO_ALLOW = 'encrypted-media; picture-in-picture; fullscreen'

/**
 * Player created by the click-to-load facade (D26). Autoplay is an explicit exception to O1/O2 that
 * lives only in the client plugin: the stored/sanitized iframe (and `YOUTUBE_EMBED_SRC`) never has it.
 */
export const VIDEO_PLAYER_ALLOW = `${VIDEO_ALLOW}; autoplay`
export const videoPlayerSrc = (id: string) => `${videoEmbedSrc(id)}?autoplay=1`
