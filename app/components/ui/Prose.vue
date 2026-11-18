<script setup lang="ts">
import type { SafeHtml } from '~~/shared/lib/sanitize/safe-html'

/**
 * Editorial prose (design system `.prose-cg`) for articles, pages and author reviews. `html` is
 * `SafeHtml`: output of the article sanitizer (server `/api/content/*` or panel preview, D64), so
 * typecheck rejects raw strings. This component does not sanitize, it only applies presentation
 * transforms that rely on that canonical output. Editorial blocks (table, figure, author note) are rendered here over the sanitized HTML.
 * `anchors` (article body): ids on H2/H3 made by the code from their text, plus a `#` link in each
 * H2, all in the server render. Without it the headings carry no id.
 */
const props = withDefaults(defineProps<{ html: SafeHtml; headingOffset?: number; anchors?: boolean }>(), {
  headingOffset: 0,
  anchors: false,
})

/**
 * Lowers heading levels (h2 → h3 with offset 1) so the page keeps one outline. The panel
 * editor (F6) should already limit the levels authors can use. Capped at h6.
 */
const { t } = useI18n()
const localePath = useLocalePath()
const { linkFor } = usePageLinks()
const idPrefix = useId()
const authorName = useNoteAuthorName()
const content = computed(() => {
  const clean = props.html
  const blocks = renderAuthorNotes(
    renderTables(props.anchors ? addHeadingAnchors(clean, (title) => t('blog.toc.anchor', { title })) : clean, t('blog.prose.table')),
    authorName.value ? t('blog.prose.noteBy', { name: authorName.value }) : t('blog.prose.note'),
  )
  const cards = renderItemCards(blocks, {
    kinds: { gym: t('blog.itemCard.gym'), resoler: t('blog.itemCard.resoler'), shoe: t('blog.itemCard.shoe') },
    view: t('blog.itemCard.view'),
  })
  // Video iframes become click-to-load facades (D26); the plugin builds the real player on click.
  const html = renderVideoFacades(cards, {
    kicker: t('blog.video.kicker'),
    play: t('blog.video.play'),
    watch: t('blog.video.watch'),
    external: t('blog.video.external'),
    notice: t('blog.video.notice'),
    cookies: t('blog.video.cookies'),
    loading: t('blog.video.loading'),
    cookiesPath: localePath('cookies', linkFor('cookies').locale),
    idPrefix,
  })
  return props.headingOffset
    ? html.replace(/<(\/?)h([1-6])(?=[\s>])/gi, (_, slash: string, level: string) => {
        return `<${slash}h${Math.min(6, Number(level) + props.headingOffset)}`
      })
    : html
})
// Visual style follows the original level: the shifted headings keep their look.
const headings = computed(() =>
  props.headingOffset
    ? '[&_h3]:mt-14 md:[&_h3]:mt-[72px] [&_h3]:text-read-h2 [&_h3]:font-medium [&_h3+*]:!mt-4 md:[&_h3+*]:!mt-5 [&_h4]:mt-8 md:[&_h4]:mt-10 [&_h4]:text-read-h3 [&_h4]:font-medium [&_h4+*]:!mt-2.5 md:[&_h4+*]:!mt-3'
    : '[&_h2]:mt-14 md:[&_h2]:mt-[72px] [&_h2]:text-read-h2 [&_h2]:font-medium [&_h2+*]:!mt-4 md:[&_h2+*]:!mt-5 [&_h3]:mt-8 md:[&_h3]:mt-10 [&_h3]:text-read-h3 [&_h3]:font-medium [&_h3+*]:!mt-2.5 md:[&_h3+*]:!mt-3',
)
/**
 * Embeds of the body (video facade, item card as `<a data-item-card>`). They only appear once the
 * sanitizer allows them (see `article-embed-nodes.ts`); until then these rules are inert.
 */
const embeds =
  '[&_iframe]:absolute [&_iframe]:inset-0 [&_iframe]:size-full [&_iframe]:border-0 [&_iframe]:bg-transparent [&_a[data-video-nojs]]:no-underline ' +
  '[&_a[data-item-card]]:flex [&_a[data-item-card]]:items-center [&_a[data-item-card]]:justify-between [&_a[data-item-card]]:gap-4 [&_a[data-item-card]]:rounded-lg [&_a[data-item-card]]:border-[0.5px] [&_a[data-item-card]]:border-line [&_a[data-item-card]]:bg-board [&_a[data-item-card]]:p-4 md:[&_a[data-item-card]]:px-5 [&_a[data-item-card]]:no-underline [&_a[data-item-card]]:transition-colors [&_a[data-item-card]]:duration-150 motion-reduce:[&_a[data-item-card]]:transition-none [&_a[data-item-card]:hover]:border-line-strong [&_a[data-item-card]:hover]:bg-elevated [&_a[data-item-card]:focus-visible]:outline-2 [&_a[data-item-card]:focus-visible]:outline-offset-2 [&_a[data-item-card]:focus-visible]:outline-accent'
</script>

<template>
  <!-- eslint-disable vue/no-v-html -- editorial HTML, sanitized by the server (SafeHtml) -->
  <div
    data-prose
    :class="[headings, proseTable, proseFigure, proseNote, proseQuote, embeds]"
    class="max-w-read text-read text-prose max-sm:leading-[1.6] [&_a]:underline [&_a]:decoration-accent [&_a[data-anchor]]:no-underline [&_a]:underline-offset-4 [&_li]:relative [&_li]:text-prose [&_li+li]:mt-[.4em] [&_ol]:list-decimal [&_ol]:pl-[1.4rem] [&_p]:text-prose [&_strong]:font-medium [&_strong]:text-foreground [&_ul]:list-none [&_ul]:pl-5 [&_ul>li]:before:absolute [&_ul>li]:before:top-[.75em] [&_ul>li]:before:-left-[1.1rem] [&_ul>li]:before:h-0.5 [&_ul>li]:before:w-[.45rem] [&_ul>li]:before:rounded-[2px] [&_ul>li]:before:bg-accent [&_ul>li]:before:content-[''] [&>*+*]:mt-[1.25em]"
    v-html="content"
  />
</template>
