import { Node, mergeAttributes, type NodeViewRenderer } from '@tiptap/core'
import { VueNodeViewRenderer } from '@tiptap/vue-3'
import EditorItemCardView from '~/components/admin/editor/nodes/ItemCardView.vue'
import EditorVideoView from '~/components/admin/editor/nodes/VideoView.vue'
import {
  ITEM_KINDS,
  VIDEO_ALLOW,
  VIDEO_REFERRER_POLICY,
  VIDEO_SANDBOX,
  YOUTUBE_ID,
  VIDEO_TITLE,
  YOUTUBE_EMBED_SRC,
  isItemSlug,
  itemCardHref,
  parseItemCard,
  videoEmbedSrc,
  type EmbedLocale,
  type ItemKind,
} from './article-embeds'

/**
 * Embeds of the article body (F6.4 · 2b). Their HTML is exactly the shape `article-embeds.ts`
 * describes (nocookie YouTube iframe; `<a data-item-card="kind:slug" href="item page">`), which the
 * article sanitizer rebuilds canonically (see `shared/lib/sanitize/sanitize-article-html.ts`).
 */
export const VideoEmbed: Node<{ locale: EmbedLocale }> = Node.create<{ locale: EmbedLocale }>({
  name: 'videoEmbed',
  group: 'block',
  atom: true,
  draggable: true,
  selectable: true,
  addOptions: () => ({ locale: 'es' }),
  // No `id` in the HTML (DOM clobbering): the video ID lives only in `src`.
  addAttributes: () => ({ id: { default: null, renderHTML: () => ({}) } }),
  parseHTML: () => [
    {
      tag: 'iframe[src]',
      getAttrs: (element) => {
        const match = YOUTUBE_EMBED_SRC.exec((element as HTMLElement).getAttribute('src') ?? '')
        return match ? { id: match[1] } : false
      },
    },
  ],
  renderHTML({ node, HTMLAttributes }) {
    if (!YOUTUBE_ID.test(String(node.attrs.id))) return ['p']
    return [
      'iframe',
      mergeAttributes(HTMLAttributes, {
        src: videoEmbedSrc(String(node.attrs.id)),
        title: VIDEO_TITLE[this.options.locale],
        allow: VIDEO_ALLOW,
        loading: 'lazy',
        allowfullscreen: 'true',
        referrerpolicy: VIDEO_REFERRER_POLICY,
        sandbox: VIDEO_SANDBOX,
      }),
    ]
  },
  addNodeView: (): NodeViewRenderer => VueNodeViewRenderer(EditorVideoView),
})

export const ItemCard: Node<{ locale: EmbedLocale }> = Node.create<{ locale: EmbedLocale }>({
  name: 'itemCard',
  group: 'block',
  atom: true,
  draggable: true,
  selectable: true,
  addOptions: () => ({ locale: 'es' }),
  addAttributes: () => ({ kind: { default: null }, slug: { default: null }, name: { default: '' } }),
  parseHTML: () => [
    {
      tag: 'a[data-item-card]',
      priority: 1100,
      getAttrs: (element) => {
        const el = element as HTMLElement
        const card = parseItemCard(el.getAttribute('data-item-card') ?? undefined, el.getAttribute('href') ?? undefined)
        return card ? { kind: card.kind, slug: card.slug, name: el.textContent ?? '' } : false
      },
    },
  ],
  renderHTML({ node }) {
    const kind = node.attrs.kind as ItemKind
    const slug = String(node.attrs.slug)
    if (!ITEM_KINDS.includes(kind) || !isItemSlug(slug)) return ['p']
    return ['a', { href: itemCardHref(kind, slug, this.options.locale), 'data-item-card': `${kind}:${slug}` }, String(node.attrs.name || slug)]
  },
  addNodeView: (): NodeViewRenderer => VueNodeViewRenderer(EditorItemCardView),
})
