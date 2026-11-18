import type { Ref } from 'vue'

interface RopeElements {
  hero: Ref<HTMLElement | null>
  ring: Ref<HTMLElement | null>
  rope: Ref<HTMLElement | null>
  /** Changes whenever the ring has been measured again. */
  layoutKey: Ref<number>
}

/**
 * Hero rope: it comes out from under the centre card and, as the page scrolls, drops into the
 * next section. `--rest` (length at rest) follows the card; `--drop` follows the scroll.
 */
export function useHeroRope({ hero, ring, rope, layoutKey }: RopeElements) {
  let maxDrop = 92

  function layout() {
    if (!hero.value || !ring.value || !rope.value) return
    const heroBox = hero.value.getBoundingClientRect()
    const ringBox = ring.value.getBoundingClientRect()
    const cardH = parseFloat(ring.value.style.getPropertyValue('--h')) || 0
    const cardBottom = ringBox.top + ring.value.clientHeight / 2 + cardH / 2
    rope.value.style.setProperty('--rest', `${Math.round(heroBox.bottom - cardBottom + 28)}px`)
    maxDrop = ring.value.clientWidth < 900 ? 30 : 92
    drop()
  }

  function drop() {
    rope.value?.style.setProperty('--drop', `${Math.min(window.scrollY * 0.35, maxDrop).toFixed(1)}px`)
  }

  onMounted(() => window.addEventListener('scroll', drop, { passive: true }))
  onBeforeUnmount(() => window.removeEventListener('scroll', drop))
  watch(layoutKey, layout, { flush: 'post' })
}
