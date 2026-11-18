import type { Ref } from 'vue'

/**
 * Positions the sliding indicator of a segmented control / tabs under the active item.
 * Re-measures on resize and once web fonts are ready (label widths change).
 */
export function useSlidingIndicator(
  container: Ref<HTMLElement | null>,
  getActive: () => HTMLElement | undefined,
) {
  const style = ref<Record<string, string>>({ width: '0px', transform: 'translateX(0px)' })

  /** False until the first placement settles: no transition then, so it never grows from width 0. */
  const animated = ref(false)

  function place() {
    const active = getActive()
    if (!active) return
    style.value = {
      width: `${active.offsetWidth}px`,
      transform: `translateX(${active.offsetLeft}px)`,
    }
  }

  onMounted(() => {
    place()
    const settle = () => {
      place()
      requestAnimationFrame(() => {
        animated.value = true
      })
    }
    if (document.fonts) document.fonts.ready.then(settle)
    else settle()
    if (container.value && 'ResizeObserver' in window) {
      const observer = new ResizeObserver(place)
      observer.observe(container.value)
      onBeforeUnmount(() => observer.disconnect())
    }
  })

  return { style, place, animated }
}
