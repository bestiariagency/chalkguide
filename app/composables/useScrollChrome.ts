import type { Ref } from 'vue'

/** Scroll distance (px) below which a movement is noise, as in the approved mock. */
const THRESHOLD_PX = 3

/**
 * Visibility of the compact bar: hidden at the top and while scrolling down, back on scrolling
 * up. It never hides while hovered or with focus inside (the dock and spy live elsewhere).
 * One passive scroll listener, rAF-throttled; the flag only changes on a real transition.
 */
export function useScrollChrome(
  pastMasthead: Readonly<Ref<boolean>>,
  bar: Readonly<Ref<HTMLElement | null>>,
) {
  const barVisible = ref(false)

  onMounted(() => {
    let lastY = window.scrollY
    let lastH = document.documentElement.scrollHeight
    let frame = 0

    function update() {
      frame = 0
      const y = window.scrollY
      const height = document.documentElement.scrollHeight
      // A page-height change (the header compacting, a collapsing block) moves scrollY by itself:
      // that is layout, not the reader, so do not treat it as direction.
      const delta = height === lastH ? y - lastY : 0
      lastH = height
      lastY = y
      if (!pastMasthead.value) barVisible.value = false
      else if (delta < -THRESHOLD_PX) barVisible.value = true
      else if (delta > THRESHOLD_PX && !bar.value?.matches(':hover, :focus-within'))
        barVisible.value = false
    }
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(update)
    }
    const onFocusin = () => {
      if (pastMasthead.value) barVisible.value = true
    }

    window.addEventListener('scroll', onScroll, { passive: true })
    bar.value?.addEventListener('focusin', onFocusin)
    onBeforeUnmount(() => {
      window.removeEventListener('scroll', onScroll)
      bar.value?.removeEventListener('focusin', onFocusin)
      cancelAnimationFrame(frame)
    })
  })

  // Back at the top the bar leaves at once (the scroll may have ended without a last event).
  watch(pastMasthead, (past) => {
    if (!past) barVisible.value = false
  })

  return { barVisible }
}
