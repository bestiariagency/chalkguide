import type { Ref } from 'vue'

/** Shared with <LayoutScrollDock>: true while the dock steps aside for reading (D51). */
export const useDockHiddenForReading = () => useState<boolean>('dock-hidden-for-reading', () => false)

const MIN_DELTA = 6

/**
 * D51 (adjusts D45), below lg only: inside the article body the dock hides while scrolling down
 * (it covers the start of the line) and returns on scrolling up or outside the body.
 */
export function useDockReadingHide(body: Ref<HTMLElement | null>) {
  const hidden = useDockHiddenForReading()
  let lastY = 0

  function onScroll() {
    const root = body.value
    const y = window.scrollY
    const inside = (() => {
      if (!root || window.innerWidth >= 1024) return false
      const rect = root.getBoundingClientRect()
      return rect.top < window.innerHeight * 0.5 && rect.bottom > 0
    })()
    if (!inside) hidden.value = false
    else if (y > lastY + MIN_DELTA) hidden.value = true
    else if (y < lastY - MIN_DELTA) hidden.value = false
    lastY = y
  }

  onMounted(() => {
    lastY = window.scrollY
    window.addEventListener('scroll', onScroll, { passive: true })
  })
  onBeforeUnmount(() => {
    window.removeEventListener('scroll', onScroll)
    hidden.value = false
  })
}
