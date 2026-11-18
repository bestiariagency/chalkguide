import type { ItemErrors } from '~/utils/item-patch'

export interface ItemTab<K extends string = string> {
  key: K
  label: string
  /** URL hash that selects the tab (`#precios`). */
  hash: string
  /** Field ids (and `scores` / `gallery`) that live in the tab: for error and change markers. */
  ids: readonly string[]
}

/** Number of errors per tab (an error key is `fieldId` or `fieldId.part`). */
export function errorsByTab<K extends string>(tabs: readonly ItemTab<K>[], errors: ItemErrors): Record<K, number> {
  const out = Object.fromEntries(tabs.map((t) => [t.key, 0])) as Record<K, number>
  for (const key of Object.keys(errors)) {
    const id = key.split('.')[0]!
    const tab = tabs.find((t) => t.ids.includes(id))
    if (tab) out[tab.key]++
  }
  return out
}

export function changedTabs<K extends string>(tabs: readonly ItemTab<K>[], changed: readonly string[]): Set<K> {
  return new Set(tabs.filter((t) => t.ids.some((id) => changed.includes(id))).map((t) => t.key))
}

/** The tab a URL hash (`#precios`) points to. */
export const tabFromHash = <K extends string>(tabs: readonly ItemTab<K>[], hash: string): K | undefined => tabs.find((t) => `#${t.hash}` === hash)?.key
