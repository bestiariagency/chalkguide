/**
 * True once the top of `#newsletter` has entered the screen and for everything below it, footer
 * included (on pages without the block, while the footer itself is on screen). The observer root
 * is extended upwards, so it only looks at intersection, never at `top`: a target above the
 * viewport (scrolled past) still intersects and one below it does not, jumps included.
 * Re-attached after each navigation, disconnected on unmount. Client only: SSR is false.
 */
export function useNewsletterReached() {
  const route = useRoute()
  const reached = ref(false)
  let observer: IntersectionObserver | null = null
  const state = new Map<Element, boolean>()

  function attach() {
    observer?.disconnect()
    state.clear()
    reached.value = false
    if (typeof IntersectionObserver === 'undefined') return
    const targets = ['newsletter', 'site-footer']
      .map((id) => document.getElementById(id))
      .filter((el): el is HTMLElement => !!el)
    if (!targets.length) return
    observer = new IntersectionObserver((entries) => {
      for (const entry of entries) {
        state.set(entry.target, entry.isIntersecting)
      }
      reached.value = [...state.values()].some(Boolean)
    }, { rootMargin: '100000px 0px 0px 0px' })
    targets.forEach((el) => observer?.observe(el))
  }

  onMounted(attach)
  watch(() => route.fullPath, () => nextTick(attach), { flush: 'post' })
  onBeforeUnmount(() => observer?.disconnect())

  return reached
}
