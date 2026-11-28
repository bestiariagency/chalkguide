import type { Ref } from 'vue'
import { CHASE_RATE, DRAG_CARD_SPAN, DRAG_THRESHOLD_PX, ringGeometry } from '~/utils/hero-ring'

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
 * Vue reactivity here would re-render the tree 60 times a second.
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
    ropeMaxDrop.value = ringW < 900 ? 30 : 92
    ropeRest.value = Math.round(heroBottom - (ringTop + ringH / 2 + g.cardH / 2) + 28)
  }

  function render() {
    cards.forEach((card, i) => {
      const d = offset(i)
      const a = d * step
      if (Math.abs(a) > 1.05) {
        card.style.visibility = 'hidden'
        return
      }
      card.style.visibility = 'visible'
      // Flat ring: perspective per card (same projection as one on the ring, same centre), and the paint
      // order by depth in z-index. No shared 3D context, so no plane can intersect another (split cards).
      card.style.transform = `perspective(${persp}px) translateZ(${radius}px) rotateY(${-a}rad) translateZ(${-radius}px)`
      card.style.zIndex = String(Math.round((1 - Math.cos(a)) * 1000))
      card.style.setProperty('--cap', Math.max(0, Math.min(1, 2.2 - Math.abs(d))).toFixed(2))
      if (reduced) return
      const kick = Math.max(-8, Math.min(8, vel * 5))
      const tilt = card === tiltCard ? tiltXY : [0, 0]
      const ry = 9 - d * 7 + kick + tilt[0]! * 8
      card.style.setProperty('--ry', `${ry.toFixed(2)}deg`)
      card.style.setProperty('--rx', `${(-4 - tilt[1]! * 6).toFixed(2)}deg`)
      card.style.setProperty('--par', `${(-d * 6).toFixed(2)}%`)
      card.style.setProperty('--sheen', `${(ry * 2.6 - 16).toFixed(1)}%`)
    })
  }

  function tick() {
    const diff = target - pos
    if (Math.abs(diff) < 0.001) {
      pos = target
      render()
      raf = 0
      moving.value = false
      return
    }
    pos += diff * (reduced ? 1 : CHASE_RATE)
    render()
    raf = requestAnimationFrame(tick)
  }

  function moveTo(value: number, announce = true) {
    target = value
    moving.value = true
    if (!raf) raf = requestAnimationFrame(tick)
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
    pos = -1.7
    target = 0
    moving.value = true
    if (!raf) raf = requestAnimationFrame(tick)
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
    const throwBy = (vel * 180) / (cardW * DRAG_CARD_SPAN)
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
    cleanups.push(() => el.removeEventListener(type, handler as EventListener, options))
  }

  onMounted(() => {
    const ringEl = ring.value
    const heroEl = hero.value
    if (!ringEl || !heroEl || !scene.value) return
    reduced = matchMedia('(prefers-reduced-motion: reduce)').matches
    cards = [...scene.value.children] as HTMLElement[]
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
    document.fonts?.ready.then(measure)
  })

  onBeforeUnmount(() => {
    cleanups.forEach((off) => off())
    cancelAnimationFrame(raf)
    clearTimeout(wheelTimer)
    clearTimeout(clickTimer)
  })

  return { live, ready, dragging, moving, ropeRest, ropeMaxDrop, goTo, spinIn }
}
