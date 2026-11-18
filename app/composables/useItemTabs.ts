import { tabFromHash, type ItemTab } from '~/utils/item-tabs'

/**
 * Active tab of the item editors: kept in the URL hash (`#precios`) so a reload or a shared link lands
 * on it, and the page scrolls back up to the panel when the tab changes. Other hashes (`#cambios`)
 * are left alone.
 */
export function useItemTabs(tabs: readonly ItemTab[]) {
  const tab = ref<string>('general')

  onMounted(() => {
    const fromHash = tabFromHash(tabs, window.location.hash)
    if (fromHash) tab.value = fromHash
    watch(tab, (key) => {
      const hash = tabs.find((t) => t.key === key)?.hash
      if (hash) window.history.replaceState(window.history.state, '', `#${hash}`)
      void nextTick(() => {
        const panel = document.getElementById(`item-panel-${key}`)
        if (!panel) return
        const top = panel.getBoundingClientRect().top + window.scrollY - 112
        if (window.scrollY > top) window.scrollTo({ top: Math.max(top, 0) })
      })
    })
  })
  return { tab }
}
