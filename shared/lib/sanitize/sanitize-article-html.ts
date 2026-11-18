import sanitizeHtml from 'sanitize-html'
import {
  VIDEO_ALLOW,
  VIDEO_REFERRER_POLICY,
  VIDEO_SANDBOX,
  VIDEO_TITLE,
  YOUTUBE_EMBED_SRC,
  itemCardHref,
  parseItemCard,
  videoEmbedSrc,
} from '../../../app/utils/article-embeds'
import { UUID, inMediaBucket, mediaBucketPrefix } from './constants'
import type { SafeHtml } from './safe-html'
import { BLOCK_ALLOWED_ATTRIBUTES, BLOCK_ALLOWED_TAGS, blockTransforms, dropStrayBlocks } from './sanitize-article-blocks'

/**
 * Single allow-list for article/page HTML (D6). Server-only on the public site (D64: `server/api/content/*`
 * sanitize on every read; never imported statically by public client code) and used by the panel
 * (via dynamic `import()`) when it saves `body_html_xx` and for previews. Anything not listed is dropped: no `style`, no `on*`, no
 * `javascript:`/`data:` URLs, no scripts. Only embeds: the YouTube nocookie iframe and the item card
 * (`a[data-item-card]`), both rebuilt from validated values (docs/security/F6.4-2b-embeds-spec.md).
 * Editorial v2 blocks (table, figure, author note) live in `sanitize-article-blocks.ts`.
 */
export const ARTICLE_ALLOWED_TAGS = ['p', 'br', 'h2', 'h3', 'strong', 'em', 'a', 'ul', 'ol', 'li', 'blockquote', 'img', 'iframe', ...BLOCK_ALLOWED_TAGS] as const

export const ARTICLE_ALLOWED_ATTRIBUTES = {
  a: ['href', 'rel', 'data-item-card'],
  img: ['src', 'alt', 'width', 'height', 'loading', 'data-media-id'],
  iframe: ['src', 'title', 'allow', 'loading', 'allowfullscreen', 'referrerpolicy', 'sandbox'],
  ...BLOCK_ALLOWED_ATTRIBUTES,
} as const

/** Only these schemes survive in `href`/`src`; relative URLs are fine, protocol-relative ones are not. */
export const ARTICLE_ALLOWED_SCHEMES = ['http', 'https', 'mailto'] as const

export interface SanitizeArticleOptions {
  /** Supabase project URL. Images are kept only when they live in its public `media` bucket. */
  supabaseUrl?: string
}

const NUMERIC = /^\d{1,5}$/

/** Empty body: trivially safe, the only `SafeHtml` not produced by the sanitizer run. */
export const EMPTY_SAFE_HTML = '' as SafeHtml

export function sanitizeArticleHtml(html: string, options: SanitizeArticleOptions = {}): SafeHtml {
  const prefix = mediaBucketPrefix(options.supabaseUrl)
  const clean = sanitizeHtml(html, {
    allowedTags: [...ARTICLE_ALLOWED_TAGS],
    allowedAttributes: {
      a: [...ARTICLE_ALLOWED_ATTRIBUTES.a],
      img: [...ARTICLE_ALLOWED_ATTRIBUTES.img],
      iframe: [...ARTICLE_ALLOWED_ATTRIBUTES.iframe],
      th: [...BLOCK_ALLOWED_ATTRIBUTES.th],
      figure: [...BLOCK_ALLOWED_ATTRIBUTES.figure],
      aside: [...BLOCK_ALLOWED_ATTRIBUTES.aside],
    },
    allowedIframeHostnames: ['www.youtube-nocookie.com'],
    allowIframeRelativeUrls: false,
    allowedSchemes: [...ARTICLE_ALLOWED_SCHEMES],
    allowedSchemesAppliedToAttributes: ['href', 'src'],
    allowProtocolRelative: false,
    disallowedTagsMode: 'discard',
    transformTags: {
      ...blockTransforms,
      a: (tagName, attribs) => {
        const href = attribs.href ?? ''
        const out: Record<string, string> = {}
        const card = parseItemCard(attribs['data-item-card'], href)
        if (card) {
          const locale = href.startsWith('/en/') ? 'en' : 'es'
          return {
            tagName,
            attribs: { href: itemCardHref(card.kind, card.slug, locale), 'data-item-card': `${card.kind}:${card.slug}` },
          }
        }
        const external = /^https?:/i.test(href)
        if (href) out.href = href
        if (external) out.rel = 'noopener'
        return { tagName, attribs: out }
      },
      iframe: (tagName, attribs) => {
        // Rebuilt from scratch: only a canonical nocookie `src` survives; no src means removed below.
        const id = YOUTUBE_EMBED_SRC.exec(attribs.src ?? '')?.[1]
        if (!id) return { tagName, attribs: {} as Record<string, string>, text: '' }
        return {
          tagName,
          text: '',
          attribs: {
            src: videoEmbedSrc(id),
            title: attribs.title === VIDEO_TITLE.en ? VIDEO_TITLE.en : VIDEO_TITLE.es,
            allow: VIDEO_ALLOW,
            loading: 'lazy',
            allowfullscreen: '',
            referrerpolicy: VIDEO_REFERRER_POLICY,
            sandbox: VIDEO_SANDBOX,
          },
        }
      },
      img: (tagName, attribs) => {
        const attrs: Record<string, string> = { src: attribs.src ?? '', alt: attribs.alt ?? '', loading: 'lazy' }
        if (UUID.test(attribs['data-media-id'] ?? '')) attrs['data-media-id'] = attribs['data-media-id']!
        if (NUMERIC.test(attribs.width ?? '')) attrs.width = attribs.width!
        if (NUMERIC.test(attribs.height ?? '')) attrs.height = attribs.height!
        return { tagName, attribs: attrs }
      },
    },
    exclusiveFilter: (frame) => {
      // Images outside the `media` bucket are removed whole (they have no content to keep).
      if (frame.tag === 'iframe') return !YOUTUBE_EMBED_SRC.test(frame.attribs.src ?? '')
      return frame.tag === 'img' && !inMediaBucket(frame.attribs.src ?? '', prefix)
    },
  })
  // R3: a link wrapping a video is dropped whole (the output is canonical, so `</a>` closes the link).
  return dropStrayBlocks(clean.replace(/<a\b[^>]*>(?:(?!<\/?a\b)[\s\S])*?<iframe\b[\s\S]*?<\/a>/g, '')) as SafeHtml
}
