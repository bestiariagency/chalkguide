/**
 * Prose extras from the design system (`.prose-cg`, §13.5): table in a `board` slab with mono
 * right-aligned figures, figures by width and the author note. Kept apart so <UiProse> stays readable.
 * The HTML these rules style is built by `prose-blocks.ts` (the sanitizer lets no class through).
 */
export const proseTable =
  '[&_.table-wrap]:max-w-full [&_.table-wrap]:overflow-x-auto [&_.table-wrap]:rounded-slab [&_.table-wrap]:border-[0.5px] [&_.table-wrap]:border-line-strong [&_.table-wrap]:bg-board ' +
  '[&_.table-wrap:focus-visible]:outline-2 [&_.table-wrap:focus-visible]:outline-offset-2 [&_.table-wrap:focus-visible]:outline-accent ' +
  '[&_table]:w-full [&_table]:min-w-[560px] [&_table]:border-collapse [&_table]:text-body-sm [&_table]:tabular-nums ' +
  '[&_th]:h-12 [&_th]:border-b-[0.5px] [&_th]:border-line-strong [&_th]:px-[.9rem] [&_th]:text-left [&_th]:font-mono [&_th]:text-label [&_th]:font-normal [&_th]:tracking-[.14em] [&_th]:text-meta [&_th]:uppercase ' +
  '[&_td]:h-12 [&_td]:py-2.5 [&_td]:leading-snug [&_td:first-child]:min-w-[9rem] [&_td]:border-b-[0.5px] [&_td]:border-line [&_td]:px-[.9rem] [&_td]:text-left [&_td]:text-prose ' +
  '[&_tbody_tr:last-child>*]:border-b-0 ' +
  '[&_.num]:text-right [&_.num]:font-mono [&_.num]:whitespace-nowrap ' +
  '[&_tr.best_td.num]:font-medium [&_tr.best_td.num]:text-accent ' +
  '[&_ol>li]:marker:font-mono [&_ol>li]:marker:text-[.85em] [&_ol>li]:marker:text-accent'

/**
 * Figures: column (640, radius 6), wide (page container 1152 from 1100, over the rail) and bleed
 * (100vw). Below 1100 the column is centred on the page, so both centre on it; from 1100 they hang
 * left of the column. Captions stay on the column axis (640).
 */
export const proseFigure =
  '[&>figure]:mt-10 [&>figure+*]:!mt-10 [&_figure]:relative [&_figure]:z-10 [&_img]:block [&_img]:h-auto [&_img]:w-full ' +
  '[&_figure[data-width=column]_img]:rounded-xs ' +
  '[&_figure[data-width=wide]]:left-1/2 [&_figure[data-width=wide]]:w-[min(72rem,100vw_-_3rem)] [&_figure[data-width=wide]]:-translate-x-1/2 max-md:[&_figure[data-width=wide]]:w-screen md:[&_figure[data-width=wide]_img]:rounded-xs ' +
  'min-[1100px]:[&_figure[data-width=wide]]:left-0 min-[1100px]:[&_figure[data-width=wide]]:translate-x-0 min-[1100px]:[&_figure[data-width=wide]]:-ml-72 ' +
  '[&_figure[data-width=wide]_img]:max-h-[min(760px,86svh)] [&_figure[data-width=wide]_img]:object-cover ' +
  '[&_figure[data-width=bleed]]:left-1/2 [&_figure[data-width=bleed]]:w-screen [&_figure[data-width=bleed]]:-translate-x-1/2 [&_figure[data-width=bleed]_img]:max-h-[min(820px,90svh)] [&_figure[data-width=bleed]_img]:object-cover ' +
  'min-[1100px]:[&_figure[data-width=bleed]]:left-0 min-[1100px]:[&_figure[data-width=bleed]]:translate-x-0 min-[1100px]:[&_figure[data-width=bleed]]:-ml-[calc(max(24px,50vw_-_576px)_+_288px)] ' +
  '[&_figcaption]:mt-3 [&_figcaption]:text-caption [&_figcaption]:text-meta ' +
  '[&_figure[data-width=wide]_figcaption]:mx-auto [&_figure[data-width=wide]_figcaption]:max-w-(--container-prose) [&_figure[data-width=bleed]_figcaption]:mx-auto [&_figure[data-width=bleed]_figcaption]:max-w-(--container-prose) ' +
  'max-md:[&_figure[data-width=wide]_figcaption]:px-4 max-md:[&_figure[data-width=bleed]_figcaption]:px-4 ' +
  'min-[1100px]:[&_figure[data-width=wide]_figcaption]:ml-72 min-[1100px]:[&_figure[data-width=bleed]_figcaption]:ml-[calc(max(24px,50vw_-_576px)_+_288px)] ' +
  '[&_figcaption_small]:inline [&_figcaption_small]:text-note [&_figcaption_small]:text-meta [&_figcaption_small]:before:content-["·_"]'

/** Author note: `accent-muted` plate with the Caveat label (decorative) built by `prose-blocks.ts`. */
export const proseNote =
  '[&_aside[data-note=author]]:rounded-xs [&_aside[data-note=author]]:bg-accent-muted [&_aside[data-note=author]]:px-5 [&_aside[data-note=author]]:pt-5 [&_aside[data-note=author]]:pb-[22px] md:[&_aside[data-note=author]]:px-7 md:[&_aside[data-note=author]]:pt-6 md:[&_aside[data-note=author]]:pb-[26px] [&_aside[data-note=author]]:text-[17px] [&_aside[data-note=author]]:leading-[1.55] [&_aside[data-note=author]]:text-foreground [&_aside[data-note=author]_p]:text-foreground ' +
  '[&_aside[data-note=author]>[data-note-label]]:block [&_aside[data-note=author]>[data-note-label]]:origin-left [&_aside[data-note=author]>[data-note-label]]:-rotate-[1.5deg] [&_aside[data-note=author]>[data-note-label]]:font-hand [&_aside[data-note=author]>[data-note-label]]:text-[28px] [&_aside[data-note=author]>[data-note-label]]:leading-none [&_aside[data-note=author]>[data-note-label]]:font-bold [&_aside[data-note=author]>[data-note-label]]:text-accent ' +
  '[&_aside[data-note=author]>*+*]:mt-3 [&_aside[data-note=author]>[data-note-label]+*]:!mt-2.5 [&_aside[data-note=author]>*:last-child]:mb-0 ' +
  '[&>*+aside[data-note=author]]:!mt-10 [&>aside[data-note=author]+*]:!mt-10'

/** Quote (§13.5): no side bar, chalk «» (opening hangs in the margin from 1100), weight 500, 48/56 spacing. */
export const proseQuote =
  '[&_blockquote]:relative [&_blockquote]:pt-1 [&_blockquote]:text-quote [&_blockquote]:font-medium [&_blockquote]:tracking-[-.015em] [&_blockquote]:text-balance [&_blockquote]:text-foreground [&_blockquote_p]:text-foreground ' +
  '[&>*+blockquote]:!mt-12 [&>blockquote+*]:!mt-12 md:[&>*+blockquote]:!mt-14 md:[&>blockquote+*]:!mt-14 ' +
  '[&_blockquote_p:first-child]:before:mr-[.08em] [&_blockquote_p:first-child]:before:text-chalk [&_blockquote_p:first-child]:before:content-["«"] ' +
  'min-[1100px]:[&_blockquote_p:first-child]:before:absolute min-[1100px]:[&_blockquote_p:first-child]:before:-left-[.62em] ' +
  '[&_blockquote_p:last-child]:after:ml-[.06em] [&_blockquote_p:last-child]:after:text-chalk [&_blockquote_p:last-child]:after:content-["»"]'
