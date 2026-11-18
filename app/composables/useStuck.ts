import type { Ref } from 'vue'

/**
 * True once `sentinel` (placed just above a sticky element) has scrolled under the sticky
 * offset, i.e. the sticky element is "stuck" and can compact itself.
 */
export function useStuck(sentinel: Readonly<Ref<Element | null>>, offsetPx: number) {
  const stuck = ref(false)
  onMounted(() => {
    if (!sentinel.value || !('IntersectionObserver' in window)) return
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry) stuck.value = entry.boundingClientRect.top < offsetPx
      },
      { rootMargin: `-${offsetPx + 1}px 0px 0px 0px` },
    )
    observer.observe(sentinel.value)
    onBeforeUnmount(() => observer.disconnect())
  })
  return stuck
}
