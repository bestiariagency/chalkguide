import { itemCardHref, parseItemCard, type ItemKind } from './article-embeds'
import { escapeHtml, htmlAttr as ATTR } from './html-escape'

/**
 * Site-side item card: turns the sanitized `<a data-item-card="gym:slug" href="…">Name</a>` into a
 * fully linked block. Runs AFTER the sanitizer (like `wrapTables`). The markup is rebuilt only from
 * `kind`, `slug` (validated by `parseItemCard`) and the escaped link text: no attribute or HTML of
 * the original is carried over. Anchors that do not validate are left untouched.
 */
export interface ItemCardLabels {
  kinds: Record<ItemKind, string>
  view: string
}

const ANCHOR = /<a\b([^>]*)>([\s\S]*?)<\/a>/gi
const ENTITIES: Record<string, string> = { '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"', '&#39;': "'" }

const plainText = (inner: string) => inner.replace(/<[^>]*>/g, '').replace(/&(?:amp|lt|gt|quot|#39);/g, (e) => ENTITIES[e]!)

export function renderItemCards(html: string, labels: ItemCardLabels): string {
  return html.replace(ANCHOR, (match, attrs: string, inner: string) => {
    if (!/\sdata-item-card=/i.test(` ${attrs}`)) return match
    const card = ATTR('data-item-card').exec(` ${attrs}`)?.[1]
    const href = ATTR('href').exec(` ${attrs}`)?.[1]
    const parsed = parseItemCard(card, href)
    if (!parsed) return match
    const name = escapeHtml(plainText(inner).trim() || parsed.slug)
    const url = itemCardHref(parsed.kind, parsed.slug, href === itemCardHref(parsed.kind, parsed.slug, 'en') ? 'en' : 'es')
    return (
      `<a data-item-card="${parsed.kind}:${parsed.slug}" href="${url}">` +
      '<span class="min-w-0 flex-1">' +
      `<span class="block font-mono text-label text-meta uppercase">${escapeHtml(labels.kinds[parsed.kind])}</span>` +
      `<span class="mt-1 block text-title-4 text-foreground">${name}</span>` +
      '</span>' +
      `<span class="flex-none text-body-sm text-foreground">${escapeHtml(labels.view)} <span class="text-accent" aria-hidden="true">→</span></span>` +
      '</a>'
    )
  })
}
