/** Shared Tailwind class strings of the panel (docs/design/admin/README.md §4.2). 44 px targets under 768. */
export const admBtn =
  'inline-flex h-8 items-center justify-center gap-1.5 rounded-md px-3 text-[13px] font-medium whitespace-nowrap ' +
  'transition-colors duration-150 select-none max-md:h-11 [&_svg]:size-4 [&_svg]:shrink-0 ' +
  'aria-disabled:cursor-not-allowed aria-disabled:opacity-45 disabled:cursor-not-allowed disabled:opacity-45'

export const admBtnPrimary = `${admBtn} bg-adm-primary text-adm-on-primary hover:bg-adm-primary-hover active:translate-y-px`

export const admBtnGhost = `${admBtn} border border-adm-line-strong bg-adm-elev text-adm-fg hover:border-adm-control hover:bg-adm-subtle`

export const admIconBtn =
  'inline-grid size-8 shrink-0 place-items-center rounded-md text-adm-meta transition-colors duration-150 ' +
  'hover:bg-adm-subtle hover:text-adm-fg disabled:cursor-not-allowed disabled:opacity-45 max-md:size-11 [&_svg]:size-4'

export const admInput =
  'h-8 w-full min-w-0 rounded-md border border-adm-control bg-adm-elev px-2.5 text-[13px] text-adm-fg ' +
  'placeholder:text-adm-muted hover:border-adm-meta max-md:h-11 max-md:text-base ' +
  'focus:border-adm-acc focus:outline-none focus:ring-[3px] focus:ring-adm-acc/20 ' +
  '[&:is(input,textarea):read-only]:border-adm-line-strong [&:is(input,textarea):read-only]:bg-adm-subtle [&:is(input,textarea):read-only]:text-adm-meta'

export const admLabel = 'mb-1.5 flex items-center gap-1.5 text-xs font-medium text-adm-fg'

export const admCard = 'rounded-lg border border-adm-line bg-adm-elev'

export const admGroupLabel = 'font-mono text-[11px] uppercase tracking-[0.14em] text-adm-muted'

export const admNavItem =
  'relative flex h-8 items-center gap-2.5 rounded-md px-2.5 text-[13px] text-adm-meta transition-colors duration-150 ' +
  'hover:bg-adm-subtle hover:text-adm-fg max-md:h-11 md:justify-center xl:justify-start ' +
  'aria-[current=page]:bg-adm-elev aria-[current=page]:font-medium aria-[current=page]:text-adm-fg ' +
  'aria-[current=page]:shadow-[inset_0_0_0_1px_var(--adm-line)] [&_svg]:size-4 [&_svg]:shrink-0 ' +
  'aria-[current=page]:[&_svg]:text-adm-acc'

export const admKbd =
  'rounded border border-adm-line-strong bg-adm-elev px-1 font-mono text-[11px] leading-4 text-adm-muted'

export const admInputInvalid = 'border-adm-danger! focus:ring-adm-danger/20'

export const admBtnDanger = `${admBtn} bg-adm-danger text-adm-on-danger hover:bg-adm-danger-hover active:translate-y-px`

export const admBtnDangerGhost = `${admBtn} border border-adm-line-strong bg-adm-elev text-adm-danger hover:border-adm-danger hover:bg-adm-danger-soft`

export const admBtnRev = `${admBtn} bg-adm-st-rev text-adm-on-rev hover:bg-adm-st-rev-hover active:translate-y-px`

export const admBtnQuiet = `${admBtn} text-adm-meta hover:bg-adm-subtle hover:text-adm-fg`

export const admChip =
  'inline-flex h-5 items-center gap-[5px] rounded px-[7px] text-xs leading-none font-medium whitespace-nowrap [&_svg]:size-3'

export const admMenuItem =
  'flex h-8 w-full items-center gap-2 rounded px-2 text-left text-[13px] text-adm-fg outline-none max-md:h-11 ' +
  'data-[highlighted]:bg-adm-subtle [&_svg]:size-4 [&_svg]:text-adm-meta'

export const admPopover =
  'z-[70] min-w-48 rounded-lg border border-adm-line bg-adm-elev p-1 text-[13px] shadow-adm-pop'

/** Toggle button (filters, scopes): ghost that tints with the accent when pressed, so only one primary stays per view. */
export const admBtnPressed = `${admBtnGhost} aria-pressed:border-adm-acc aria-pressed:bg-adm-acc-soft aria-pressed:text-adm-acc`
