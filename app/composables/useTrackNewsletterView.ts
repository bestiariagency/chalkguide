import type { Ref } from 'vue'

/**
 * `newsletter_view` (D69): the orange block entered the screen, once per page. The layout keeps the
 * block across navigations, so the observer is re-armed on each route change.
 */
export function useTrackNewsletterView(target: Readonly<Ref<Element | null>>) {
  const { track } = useTrack()
  const route = useRoute()
  let observer: IntersectionObserver | null = null

  function arm() {
    observer?.disconnect()
    if (!target.value || !('IntersectionObserver' in window)) return
    observer = new IntersectionObserver((entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return
      observer?.disconnect()
      track('newsletter_view')
    })
    observer.observe(target.value)
  }

  onMounted(arm)
  watch(() => route.path, () => nextTick(arm))
  onBeforeUnmount(() => observer?.disconnect())
}
