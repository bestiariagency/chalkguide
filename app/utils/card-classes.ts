/** Card title underline that draws on hover (design system `.t-link`); parent needs `group/card`. */
export const cardTitleUnderline =
  'bg-[linear-gradient(var(--color-accent),var(--color-accent))] bg-size-[0%_1.5px] bg-position-[0_95%] ' +
  'bg-no-repeat transition-[background-size] duration-300 ease-out group-hover/card:bg-size-[100%_1.5px]'

/** Card surface: board → elevated on hover, no shadows; focus ring on the whole card. */
export const cardSurface =
  'relative rounded-lg border-[0.5px] border-line-strong bg-board transition-colors duration-200 ease-standard ' +
  'hover:border-control hover:bg-elevated has-[a:focus-visible]:ring-focus'

/** Title link of a clickable listing row: an `::after` overlay covers the row and carries the focus ring. */
export const rowOverlayLink =
  'text-lg font-medium after:absolute after:inset-0 after:z-[1] after:rounded-md focus-visible:shadow-none focus-visible:after:ring-focus'

/** Title underline that follows the text colour (for titles on paper-tone plaques inside dark sections). */
export const plaqueTitleUnderline =
  'bg-[linear-gradient(currentColor,currentColor)] bg-size-[0%_1.5px] bg-position-[0_100%] bg-no-repeat ' +
  'pb-0.5 transition-[background-size] duration-300 ease-out group-hover/card:bg-size-[100%_1.5px]'
