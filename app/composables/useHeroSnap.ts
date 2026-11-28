import type { Ref } from 'vue'
import { HERO_RING_MIN_WIDTH } from '~/utils/hero-ring'

/** Silence (ms) after the last scroll before the live region announces the new card. */
const ANNOUNCE_DELAY_MS = 400

/**
 * Flat hero carousel (below 900px): the scroll is the browser's (scroll-snap); this only reads it.
 * One passive scroll listener with one rAF gives the centred card for the dots, the buttons and
 * the live region. No physics, no pointer listeners, no per-card writes.
 * @param track the scrolling list (ul.hero-scene); its `.hero-card` descendants are the cards.
 */
export function useHeroSnap(track: Ref<HTMLElement | null>, total: Ref<number>) {
  const { t } = useI18n()
  const active = ref(0)
  const live = ref('')
  const atStart = computed(() => active.value <= 0)
  const atEnd = computed(() => active.value >= total.value - 1)

  let slides: HTMLElement[] = []
  let frame = 0
  let liveTimer = 0
  let mq: MediaQueryList | null = null
  const cleanups: (() => void)[] = []

  const flat = () => !mq?.matches
  const step = () => (slides.length > 1 ? slides[1]!.offsetLeft - slides[0]!.offsetLeft : 0)

  function sync() {
    frame = 0
    const size = step()
    if (!track.value || !size || !flat()) return
    const i = Math.max(0, Math.min(slides.length - 1, Math.round(track.value.scrollLeft / size)))
    if (i === active.value) return
    active.value = i
    clearTimeout(liveTimer)
    liveTimer = window.setTimeout(() => {
      const label = slides[i]?.querySelector<HTMLElement>('[data-label]')?.dataset.label ?? ''
      live.value = t('home.hero.status', { n: i + 1, total: slides.length, label })
    }, ANNOUNCE_DELAY_MS)
  }

  function goTo(i: number) {
    const size = step()
    if (!track.value || !size) return
    const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches
    track.value.scrollTo({
      left: Math.max(0, Math.min(slides.length - 1, i)) * size,
      behavior: reduced ? 'auto' : 'smooth',
    })
  }
  const prev = () => !atStart.value && goTo(active.value - 1)
  const next = () => !atEnd.value && goTo(active.value + 1)

  /** A side card centres first; the centre one navigates. */
  function onClick(e: MouseEvent) {
    if (!flat()) return
    const i = slides.findIndex((slide) => slide.contains(e.target as Node))
    if (i < 0 || i === active.value) return
    e.preventDefault()
    goTo(i)
  }

  onMounted(() => {
    const el = track.value
    if (!el) return
    mq = matchMedia(`(min-width: ${HERO_RING_MIN_WIDTH}px)`)
    slides = [...el.children] as HTMLElement[]
    const onScroll = () => {
      if (!frame) frame = requestAnimationFrame(sync)
    }
    el.addEventListener('scroll', onScroll, { passive: true })
    // Capture: it must run before the router's own click handler on the link.
    el.addEventListener('click', onClick, { capture: true })
    cleanups.push(
      () => el.removeEventListener('scroll', onScroll),
      () => el.removeEventListener('click', onClick, { capture: true }),
    )
    sync()
  })

  onBeforeUnmount(() => {
    cleanups.forEach((off) => off())
    cancelAnimationFrame(frame)
    clearTimeout(liveTimer)
  })

  return { active, live, atStart, atEnd, prev, next }
}
