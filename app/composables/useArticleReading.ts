import type { Ref } from 'vue'

/** Offset (px) under which a heading counts as "current": bar + `scroll-margin-top`. */
const ACTIVE_LINE = 120
/**
 * Reading state of an article (editorial v2, §13.5), browser only:
 * - tracks progress (0..1) through the body and the heading being read.
 * The H2 ids and `#` anchors are made on the server by <UiProse :anchors>, not here.
 * Progress feeds the 2 px bar, "Quedan N min" and the index highlight. Nothing animates.
 */
export function useArticleReading(options: {
  body: Ref<HTMLElement | null>
  headings: Ref<{ id: string; text: string }[]>
}) {
  const progress = ref(0)
  const activeId = ref<string | null>(null)
  let frame = 0

  function measure() {
    frame = 0
    const root = options.body.value
    if (!root) return
    const rect = root.getBoundingClientRect()
    const range = Math.max(1, rect.height - window.innerHeight)
    progress.value = Math.min(1, Math.max(0, -rect.top / range))
    let current: string | null = null
    for (const heading of options.headings.value) {
      const el = document.getElementById(heading.id)
      if (el && el.getBoundingClientRect().top <= ACTIVE_LINE) current = heading.id
    }
    activeId.value = current
  }

  const schedule = () => {
    if (!frame) frame = requestAnimationFrame(measure)
  }

  onMounted(() => {
    measure()
    window.addEventListener('scroll', schedule, { passive: true })
    window.addEventListener('resize', schedule, { passive: true })
  })
  onBeforeUnmount(() => {
    window.removeEventListener('scroll', schedule)
    window.removeEventListener('resize', schedule)
    cancelAnimationFrame(frame)
  })

  return { progress, activeId }
}
