import type { Ref } from 'vue'
import { HERO_RING_MIN_WIDTH } from '~/utils/hero-ring'

interface RopeElements {
  rope: Ref<HTMLElement | null>
  /** Length at rest (px), measured by the ring together with the card (null until measured). */
  rest: Ref<number | null>
  maxDrop: Ref<number>
}

/**
 * Hero rope: it comes out from under the centre card and, as the page scrolls, drops into the
 * next section. `--rest` (length at rest) follows the card; `--drop` follows the scroll.
 * It only writes styles: the layout reads live in useHeroRing (no forced reflow).
 * Ring layout only (900px up): on phones the rope hangs still from the pager, with no listener.
 */
export function useHeroRope({ rope, rest, maxDrop }: RopeElements) {
  function drop() {
    rope.value?.style.setProperty('--drop', `${Math.min(window.scrollY * 0.35, maxDrop.value).toFixed(1)}px`)
  }

  function layout() {
    if (!rope.value || rest.value === null) return
    rope.value.style.setProperty('--rest', `${rest.value}px`)
    drop()
  }

  let mq: MediaQueryList | null = null
  function sync() {
    if (mq?.matches) window.addEventListener('scroll', drop, { passive: true })
    else window.removeEventListener('scroll', drop)
  }
  onMounted(() => {
    mq = matchMedia(`(min-width: ${HERO_RING_MIN_WIDTH}px)`)
    mq.addEventListener('change', sync)
    sync()
  })
  onBeforeUnmount(() => {
    mq?.removeEventListener('change', sync)
    window.removeEventListener('scroll', drop)
  })
  watch([rest, maxDrop], layout, { flush: 'post' })
}
