import type { Ref } from 'vue'

/**
 * True once the element enters the viewport (then stops observing). Used for one-shot
 * motion: chalk strokes, index bars, reveals. Initial hidden states only exist under
 * `.js` + prefers-reduced-motion: no-preference, so content is complete without it.
 */
export function useInView(target: Readonly<Ref<Element | null>>, rootMargin = '0px 0px -6% 0px') {
  const inView = ref(false)

  onMounted(() => {
    if (!target.value || !('IntersectionObserver' in window)) {
      inView.value = true
      return
    }
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) {
          inView.value = true
          observer.disconnect()
        }
      },
      { rootMargin, threshold: 0.05 },
    )
    observer.observe(target.value)
    onBeforeUnmount(() => observer.disconnect())
  })

  return inView
}
