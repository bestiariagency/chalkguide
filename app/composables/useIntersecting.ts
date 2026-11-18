import type { Ref } from 'vue'

/**
 * Live "is this element intersecting the viewport" flag (e.g. masthead → compact bar).
 * `options` (rootMargin, threshold) tune the observer; the default is any pixel visible.
 */
export function useIntersecting(
  target: Readonly<Ref<Element | null>>,
  options?: Pick<IntersectionObserverInit, 'rootMargin' | 'threshold'>,
) {
  const intersecting = ref(true)
  onMounted(() => {
    if (!target.value || !('IntersectionObserver' in window)) return
    const observer = new IntersectionObserver(([entry]) => {
      if (entry) intersecting.value = entry.isIntersecting
    }, options)
    observer.observe(target.value)
    onBeforeUnmount(() => observer.disconnect())
  })
  return intersecting
}
