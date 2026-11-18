import type { Ref } from 'vue'

/** Fraction of the viewport height where the "current section" line sits (mock: 40%). */
const LINE = 40

/**
 * Home only: which section carrying `data-nav-section="<nav route name>"` crosses the line at 40%
 * of the viewport height. An IntersectionObserver whose root margin shrinks the viewport to that
 * line replaces reading layout on every scroll. Sections without a nav link (paths, partner)
 * have no attribute and mark nothing. Returns the route name, or null.
 */
export function useSectionSpy(enabled: Readonly<Ref<boolean>>) {
  const current = ref<string | null>(null)
  let observer: IntersectionObserver | null = null

  function stop() {
    observer?.disconnect()
    observer = null
    current.value = null
  }

  function start() {
    stop()
    if (!enabled.value || !('IntersectionObserver' in window)) return
    const sections = [...document.querySelectorAll<HTMLElement>('[data-nav-section]')]
    if (!sections.length) return
    const crossing = new Set<Element>()
    observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) crossing.add(entry.target)
          else crossing.delete(entry.target)
        }
        current.value =
          sections.find((section) => crossing.has(section))?.dataset.navSection ?? null
      },
      { rootMargin: `-${LINE}% 0px -${100 - LINE}% 0px` },
    )
    sections.forEach((section) => observer!.observe(section))
  }

  onMounted(() => {
    // The page of a client-side navigation is in the DOM only after `page:finish`.
    const unhook = useNuxtApp().hook('page:finish', start)
    watch(enabled, () => nextTick(start), { immediate: true })
    onBeforeUnmount(() => {
      unhook()
      stop()
    })
  })

  return current
}
