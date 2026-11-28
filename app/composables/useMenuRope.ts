import type { Ref } from 'vue'

/** The carabiner needs this long to reach the tapped link before we navigate (D42). */
const TRAVEL_MS = 280
/** Rope growth between links (ms), the same as the carabiner's travel (CSS: duration-[280ms]). */
const FLIP_MS = 280
/** Distance from a link's centre to the rope end so the carabiner sits on it (mock). */
const CARABINER_OFFSET = 22
/** The braid stops this far above the rope end (CSS: h-[calc(var(--y)-18px)]). */
const CORD_INSET = 18

/**
 * Rope in the mobile menu's left margin. The carabiner clips to the current section (or the
 * first item when there is none), follows hover/focus, and on tap travels to the link before
 * navigating. `nav` is the scrolling, positioned container; links carry `data-menu-link` and the
 * braid `data-menu-cord`. The cord's height jumps to the new length and, so that only a transform
 * animates, it starts scaled to the old one and eases back to 1 (FLIP).
 */
export function useMenuRope(options: {
  isOpen: Ref<boolean>
  nav: Ref<HTMLElement | null>
  restIndex: Ref<number>
  close: () => void
}) {
  const { isOpen, nav, restIndex, close } = options
  const { locale } = useI18n()

  const y = ref(0)
  const clipped = ref(0)
  let travelling = false

  const links = () => [...(nav.value?.querySelectorAll<HTMLElement>('[data-menu-link]') ?? [])]

  /**
   * offsetTop ignores the reveal transform and the list's scroll position. The transformed `li`
   * is the link's offsetParent, so its own offsetTop (relative to `nav`) is added.
   */
  function measure(flip = false) {
    const link = links()[clipped.value]
    const item = link?.parentElement
    if (!link || !item) return
    const next = Math.round(item.offsetTop + link.offsetTop + link.offsetHeight / 2 + CARABINER_OFFSET)
    const from = y.value
    if (next === from) return
    y.value = next
    if (flip && from > CARABINER_OFFSET && isOpen.value) flipCord(from, next)
  }

  let flipTimer = 0
  async function flipCord(from: number, to: number) {
    const cord = nav.value?.querySelector<HTMLElement>('[data-menu-cord]')
    if (!cord || matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const base = to - CORD_INSET
    if (base <= 0) return
    cord.style.transition = 'none'
    cord.style.transform = `scaleY(${(from - CORD_INSET) / base})`
    await nextTick() // the new height is in the DOM; the cord is still drawn at the old length
    void cord.offsetHeight
    cord.style.transition = `transform ${FLIP_MS}ms var(--ease-out)`
    cord.style.transform = ''
    clearTimeout(flipTimer)
    flipTimer = window.setTimeout(() => (cord.style.transition = ''), FLIP_MS + 40)
  }

  let scrollFrame = 0
  /** Scroll of the list: one measure per frame, not per event. */
  function measureOnFrame() {
    if (scrollFrame) return
    scrollFrame = requestAnimationFrame(() => {
      scrollFrame = 0
      measure()
    })
  }

  function clipTo(index: number) {
    clipped.value = index
    measure(true)
  }
  const rest = () => !travelling && clipTo(restIndex.value)

  async function onLinkClick(event: MouseEvent, index: number) {
    const anchor = event.currentTarget as HTMLAnchorElement
    // Let the browser handle new-tab/window gestures.
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return
    event.preventDefault()
    if (travelling) return
    travelling = true
    clipTo(index)
    try {
      if (!matchMedia('(prefers-reduced-motion: reduce)').matches) {
        await new Promise((resolve) => setTimeout(resolve, TRAVEL_MS))
      }
      await navigateTo(anchor.getAttribute('href') ?? '/')
    } finally {
      travelling = false
      close()
    }
  }

  // Opening dirties the whole page (inert, scroll lock): measuring in the same tick would force a
  // full layout before the first frame. Two frames later it is clean and the pills are already moving.
  let openFrame = 0
  watch(isOpen, (open) => {
    if (!open) return
    cancelAnimationFrame(openFrame)
    openFrame = requestAnimationFrame(() => {
      openFrame = requestAnimationFrame(() => isOpen.value && clipTo(restIndex.value))
    })
  })
  watch([restIndex, locale], () => nextTick(rest))

  const onResize = () => isOpen.value && measure()
  onMounted(() => window.addEventListener('resize', onResize))
  onBeforeUnmount(() => {
    window.removeEventListener('resize', onResize)
    cancelAnimationFrame(openFrame)
    cancelAnimationFrame(scrollFrame)
    clearTimeout(flipTimer)
  })

  return { y, clipped, clipTo, rest, measure: measureOnFrame, onLinkClick }
}
