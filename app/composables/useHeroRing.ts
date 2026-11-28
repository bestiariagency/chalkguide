import type { Ref } from 'vue'
import {
  CHASE_MS,
  DRAG_CARD_SPAN,
  DRAG_THRESHOLD_PX,
  HERO_RING_MIN_WIDTH,
  THROW_MS,
  ringGeometry,
} from '~/utils/hero-ring'

interface RingElements {
  hero: Ref<HTMLElement | null>
  ring: Ref<HTMLElement | null>
  scene: Ref<HTMLElement | null>
}

/**
 * Home hero carousel: the inside of a cylinder. Cards are placed on a circle with translateZ /
 * rotateY, driven by `pos` (a fractional card index). It only moves when the user moves it
 * (drag, swipe, horizontal trackpad, arrows, focus, click on a side card): no autoplay, ever.
 * Cards are written straight to the DOM (custom properties) on every frame: going through
 * Vue reactivity here would re-render the tree 60 times a second. Only values that changed are written.
 * It only runs from 900px up (the CSS cut); below that the hero is a native scroll-snap carousel
 * (useHeroSnap) and this one tears down, leaving no inline style behind.
 */
export function useHeroRing({ hero, ring, scene }: RingElements) {
  const live = ref('')
  const ready = ref(false)
  const dragging = ref(false)
  const moving = ref(false)
  /**
   * Rope metrics, measured here with every layout read BEFORE the style writes (the ring box does
   * not depend on --w/--h: the cards are absolute), so the rope never forces a second layout.
   */
  const ropeRest = ref<number | null>(null)
  const ropeMaxDrop = ref(92)

  let cards: HTMLElement[] = []
  let written: Record<string, string>[] = []
  let active = false
  let lastFrame = 0
  let n = 0
  let reduced = false
  let pos = 0
  let target = 0
  let step = 0.3
  let radius = 1000
  let persp = 1000
  let cardW = 280
  let raf = 0
  let vel = 0
  let tiltCard: HTMLElement | null = null
  let tiltXY: [number, number] = [0, 0]
  let moved = false
  let down = false
  let startX = 0
  let startPos = 0
  let lastX = 0
  let lastT = 0
  let wheelTimer = 0
  let clickTimer = 0
  const cleanups: (() => void)[] = []
  let modeCleanups: (() => void)[] = []
  let mq: MediaQueryList | null = null

  const wrap = (v: number) => ((v % n) + n) % n
  function offset(i: number) {
    let d = wrap(i - pos)
    if (d > n / 2) d -= n
    return d
  }

  function measure() {
    const el = ring.value
    if (!el || !n) return
    const ringW = el.clientWidth
    const ringH = el.clientHeight
    const g = ringGeometry(ringW, ringH)
    const heroBottom = hero.value?.getBoundingClientRect().bottom ?? 0
    const ringTop = el.getBoundingClientRect().top
    cardW = g.cardW
    radius = g.radius
    persp = g.perspective
    step = g.step
    el.style.setProperty('--w', `${g.cardW}px`)
    el.style.setProperty('--h', `${g.cardH}px`)
    render()
    ropeMaxDrop.value = 92
    ropeRest.value = Math.round(heroBottom - (ringTop + ringH / 2 + g.cardH / 2) + 28)
  }

  /** Write a style only when it changed (a hidden or settled card costs nothing). */
  function put(i: number, card: HTMLElement, name: string, value: string) {
    const memo = (written[i] ??= {})
    if (memo[name] === value) return
    memo[name] = value
    if (name === 'transform' || name === 'zIndex' || name === 'visibility') {
      card.style[name] = value
    } else card.style.setProperty(name, value)
  }

  function render() {
    cards.forEach((card, i) => {
      const d = offset(i)
      const a = d * step
      if (Math.abs(a) > 1.05) {
        put(i, card, 'visibility', 'hidden')
        return
      }
      put(i, card, 'visibility', 'visible')
      // Flat ring: perspective per card (same projection as one on the ring, same centre), and the paint
      // order by depth in z-index. No shared 3D context, so no plane can intersect another (split cards).
      put(i, card, 'transform', `perspective(${persp}px) translateZ(${radius}px) rotateY(${-a}rad) translateZ(${-radius}px)`)
      put(i, card, 'zIndex', String(Math.round((1 - Math.cos(a)) * 1000)))
      put(i, card, '--cap', Math.max(0, Math.min(1, 2.2 - Math.abs(d))).toFixed(2))
      if (reduced) return
      const kick = Math.max(-8, Math.min(8, vel * 5))
      const tilt = card === tiltCard ? tiltXY : [0, 0]
      const ry = 9 - d * 7 + kick + tilt[0]! * 8
      put(i, card, '--ry', `${ry.toFixed(2)}deg`)
      put(i, card, '--rx', `${(-4 - tilt[1]! * 6).toFixed(2)}deg`)
      put(i, card, '--par', `${(-d * 6).toFixed(2)}%`)
      put(i, card, '--sheen', `${(ry * 2.6 - 16).toFixed(1)}%`)
    })
  }

  /** Chase by time, not by frame: it settles in the same ~350 ms at 30, 60 or 120 Hz. */
  function tick(now: number) {
    const dt = Math.min(64, Math.max(1, now - lastFrame))
    lastFrame = now
    const diff = target - pos
    if (Math.abs(diff) < 0.001) {
      pos = target
      render()
      raf = 0
      moving.value = false
      return
    }
    pos += diff * (reduced ? 1 : 1 - Math.exp(-dt / CHASE_MS))
    render()
    raf = requestAnimationFrame(tick)
  }

  function startLoop() {
    if (raf) return
    lastFrame = performance.now()
    raf = requestAnimationFrame(tick)
  }

  function moveTo(value: number, announce = true) {
    target = value
    moving.value = true
    startLoop()
    if (announce) live.value = cards[wrap(Math.round(value))]?.dataset.label ?? ''
  }

  /** Go to card `i` by the short way round. */
  function goTo(i: number) {
    let d = wrap(i - target)
    if (d > n / 2) d -= n
    moveTo(Math.round(target) + d)
  }

  /** Intro: the wall is already turning when the pills lift (starts 1.7 cards away, settles on 0). */
  function spinIn() {
    if (!active) return
    pos = -1.7
    target = 0
    moving.value = true
    startLoop()
  }

  function onCardClick(e: Event, i: number) {
    if (moved) {
      e.preventDefault()
      return
    }
    // A side card centres first; the centre one navigates.
    if (Math.abs(offset(i)) > 0.5) {
      e.preventDefault()
      goTo(i)
    }
  }

  function onPointerDown(e: PointerEvent) {
    if (e.button) return
    down = true
    moved = false
    startX = lastX = e.clientX
    startPos = pos
    lastT = e.timeStamp
    vel = 0
    if (raf) {
      cancelAnimationFrame(raf)
      raf = 0
    }
  }

  function onPointerMove(e: PointerEvent) {
    if (!down) return
    const dx = e.clientX - startX
    if (!moved && Math.abs(dx) > DRAG_THRESHOLD_PX) {
      moved = true
      dragging.value = true
      moving.value = true
    }
    if (!moved) return
    const dt = Math.max(1, e.timeStamp - lastT)
    vel = (e.clientX - lastX) / dt
    lastX = e.clientX
    lastT = e.timeStamp
    pos = startPos - dx / (cardW * DRAG_CARD_SPAN)
    target = pos
    render()
  }

  function endDrag() {
    if (!down) return
    down = false
    dragging.value = false
    const throwBy = (vel * THROW_MS) / (cardW * DRAG_CARD_SPAN)
    vel = 0
    if (moved) moveTo(Math.round(pos - throwBy))
    else moveTo(Math.round(pos), false)
    // The click that follows a drag arrives right after pointerup: keep blocking it a moment.
    clickTimer = window.setTimeout(() => (moved = false), 60)
  }

  // Horizontal trackpad only; vertical scroll belongs to the page.
  function onWheel(e: WheelEvent) {
    if (Math.abs(e.deltaX) <= Math.abs(e.deltaY)) return
    e.preventDefault()
    pos += e.deltaX / (cardW * DRAG_CARD_SPAN)
    target = pos
    render()
    clearTimeout(wheelTimer)
    wheelTimer = window.setTimeout(() => moveTo(Math.round(pos)), 120)
  }

  function onKeydown(e: KeyboardEvent) {
    if (e.key === 'ArrowRight') moveTo(Math.round(target) + 1)
    if (e.key === 'ArrowLeft') moveTo(Math.round(target) - 1)
  }

  function listen(
    el: HTMLElement | Window,
    type: string,
    handler: (e: never) => void,
    options?: AddEventListenerOptions,
  ) {
    el.addEventListener(type, handler as EventListener, options)
    modeCleanups.push(() => el.removeEventListener(type, handler as EventListener, options))
  }

  function enable() {
    const ringEl = ring.value
    const heroEl = hero.value
    if (active || !ringEl || !heroEl || !scene.value) return
    active = true
    reduced = matchMedia('(prefers-reduced-motion: reduce)').matches
    cards = [...scene.value.querySelectorAll<HTMLElement>('.hero-card')]
    written = []
    n = cards.length
    cards.forEach((card, i) => {
      listen(card, 'focus', () => {
        if (card.matches(':focus-visible')) goTo(i)
      })
      // Capture: it must run before the router's own click handler on the link.
      listen(card, 'click', (e: Event) => onCardClick(e, i), { capture: true })
      if (reduced) return
      listen(card, 'pointermove', (e: PointerEvent) => {
        if (e.pointerType !== 'mouse' || down) return
        const box = card.getBoundingClientRect()
        tiltCard = card
        tiltXY = [((e.clientX - box.left) / box.width) * 2 - 1, ((e.clientY - box.top) / box.height) * 2 - 1]
        render()
      })
      listen(card, 'pointerleave', () => {
        tiltCard = null
        render()
      })
    })
    listen(ringEl, 'pointerdown', onPointerDown)
    listen(ringEl, 'wheel', onWheel, { passive: false })
    listen(heroEl, 'keydown', onKeydown)
    listen(window, 'pointermove', onPointerMove)
    listen(window, 'pointerup', endDrag)
    listen(window, 'pointercancel', endDrag)
    listen(window, 'resize', measure)
    measure()
    ready.value = true
    // Fonts change the title height and with it the scene's.
    document.fonts?.ready.then(() => active && measure())
  }

  /** Below 900px: stop, and leave the cards as plain CSS blocks (no inline style, no ring state). */
  function disable() {
    if (!active) return
    active = false
    modeCleanups.forEach((off) => off())
    modeCleanups = []
    cancelAnimationFrame(raf)
    raf = 0
    clearTimeout(wheelTimer)
    pos = target = vel = 0
    down = moved = false
    tiltCard = null
    ready.value = false
    dragging.value = false
    moving.value = false
    ring.value?.style.removeProperty('--w')
    ring.value?.style.removeProperty('--h')
    cards.forEach((card) => {
      card.style.transform = ''
      card.style.zIndex = ''
      card.style.visibility = ''
      for (const name of ['--cap', '--ry', '--rx', '--par', '--sheen']) card.style.removeProperty(name)
    })
    written = []
  }

  onMounted(() => {
    mq = matchMedia(`(min-width: ${HERO_RING_MIN_WIDTH}px)`)
    const apply = () => (mq?.matches ? enable() : disable())
    mq.addEventListener('change', apply)
    cleanups.push(() => mq?.removeEventListener('change', apply))
    apply()
  })

  onBeforeUnmount(() => {
    cleanups.forEach((off) => off())
    modeCleanups.forEach((off) => off())
    cancelAnimationFrame(raf)
    clearTimeout(wheelTimer)
    clearTimeout(clickTimer)
  })

  return { live, ready, dragging, moving, ropeRest, ropeMaxDrop, goTo, spinIn }
}
