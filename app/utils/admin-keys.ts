const BLOCKING = 'input, textarea, select, [contenteditable], [role="dialog"], [role="alertdialog"], [role="combobox"]'

/** True when a single-key shortcut must not fire: modifier held, typing, or focus inside a dialog (plus `extra` selectors). */
export function isShortcutBlocked(event: KeyboardEvent, extra?: string): boolean {
  const target = event.target as HTMLElement | null
  return event.metaKey || event.ctrlKey || event.altKey || !!target?.closest(extra ? `${BLOCKING}, ${extra}` : BLOCKING)
}

/** Focus the list row `[data-<name>="<id>"]` after the next render (keyboard navigation in inbox lists). */
export function focusListRow(name: string, id?: string) {
  if (id) void nextTick(() => document.querySelector<HTMLElement>(`[data-${name}="${id}"]`)?.focus())
}
