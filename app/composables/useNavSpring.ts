import type { Ref } from 'vue'

/* Spring constants, delays and sizes of the approved mock (docs/design/site/pages/home-nav-desktop.html). */
const CARD_SPRING = { pull: 0.1, damping: 0.74 }
const LINE_SPRING = { pull: 0.16, damping: 0.68 }
const CARD_WIDTH = 292
const CARD_EDGE_GAP = 16
const INTENT_MS = 90
const LEAVE_MS = 150
const REST_EPSILON = 0.06
const MAX_LEAN_DEG = 4

interface NavSpringOptions {
  /** Index of the link the home section tracking marks (null: none). */
  spy: Ref<number | null>
  /** Preview cards: when they arrive while a link is hovered, the card opens. */
  cards: Ref<unknown>
  /** First hover or focus of the nav: time to fetch the card data. */
  onUse: () => void
}

/**
 * Orange line and preview card of the desktop nav, ported from the mock. The root holds
 * `[data-nav-link="<route name>"]` links, one `[data-nav-ind]` line and one `[data-nav-card]` with
 * `[data-nav-face="<route name>"]` faces. State lives in data attributes and inline styles written
 * per frame (no reactive state); the card only reacts to a real hover (`hover: hover`).
 */
export function useNavSpring(root: Ref<HTMLElement | null>, options: NavSpringOptions) {
  const route = useRoute()
  let refresh = () => {}
  let rest = () => {}
  let restIfIdle = () => {}

  onMounted(() => {
    const el = root.value
    const ind = el?.querySelector<HTMLElement>('[data-nav-ind]')
    const card = el?.querySelector<HTMLElement>('[data-nav-card]')
    if (!el || !ind || !card) return
    const links = [...el.querySelectorAll<HTMLElement>('[data-nav-link]')]
    const faces = () => [...card.querySelectorAll<HTMLElement>('[data-nav-face]')]
    const reducedQuery = matchMedia('(prefers-reduced-motion: reduce)')
    const canHover = matchMedia('(hover: hover)').matches
    const abort = new AbortController()
    const { signal } = abort

    let x = 0,
      vx = 0,
      tx = 0 // card: position, velocity, target (centre under the link)
    let ix = 0,
      iw = 40,
      vix = 0,
      viw = 0,
      tix = 0,
      tiw = 40 // line: left, width, velocities, targets
    let frame = 0,
      leaveTimer = 0,
      cardTimer = 0,
      boxLeft = 0
    let active: HTMLElement | null = null

    const current = () => links.find((link) => link.hasAttribute('aria-current')) ?? null
    const spied = () => (options.spy.value === null ? null : (links[options.spy.value] ?? null))
    const centre = (link: HTMLElement) => link.offsetLeft + link.offsetWidth / 2

    function draw() {
      // Keeps the card inside the viewport (boxLeft is measured on hover, not per frame).
      const min = CARD_EDGE_GAP - boxLeft
      const max = document.documentElement.clientWidth - boxLeft - CARD_EDGE_GAP - CARD_WIDTH
      const cx = Math.max(min, Math.min(max, x - CARD_WIDTH / 2))
      const lean = reducedQuery.matches
        ? 0
        : Math.max(-MAX_LEAN_DEG, Math.min(MAX_LEAN_DEG, -vx * 0.18))
      card!.style.transform = `translateX(${cx.toFixed(1)}px) rotate(${lean.toFixed(2)}deg)`
      ind!.style.transform = `translateX(${ix.toFixed(1)}px) scaleX(${(iw / 100).toFixed(3)})`
    }

    function step() {
      vx = (vx + (tx - x) * CARD_SPRING.pull) * CARD_SPRING.damping
      x += vx
      vix = (vix + (tix - ix) * LINE_SPRING.pull) * LINE_SPRING.damping
      ix += vix
      viw = (viw + (tiw - iw) * LINE_SPRING.pull) * LINE_SPRING.damping
      iw += viw
      draw()
      const motion =
        Math.abs(tx - x) + Math.abs(vx) + Math.abs(tix - ix) + Math.abs(vix) + Math.abs(tiw - iw)
      if (motion < REST_EPSILON) {
        x = tx
        ix = tix
        iw = tiw
        vx = vix = viw = 0
        draw()
        frame = 0
        return
      }
      frame = requestAnimationFrame(step)
    }

    function go() {
      if (reducedQuery.matches) {
        x = tx
        ix = tix
        iw = tiw
        draw()
        return
      }
      if (!frame) frame = requestAnimationFrame(step)
    }

    rest = () => {
      const target = current() ?? spied()
      links.forEach((link) => link.removeAttribute('data-near'))
      card.removeAttribute('data-on')
      ind.toggleAttribute('data-on', !!target)
      if (target) {
        tix = target.offsetLeft
        tiw = target.offsetWidth
      }
      active = null
      go()
    }

    function near(link: HTMLElement) {
      clearTimeout(leaveTimer)
      clearTimeout(cardTimer)
      active = link
      boxLeft = el!.getBoundingClientRect().left
      links.forEach((other) => other.toggleAttribute('data-near', other === link))
      ind!.toggleAttribute('data-on', true)
      tix = link.offsetLeft
      tiw = link.offsetWidth
      tx = centre(link)
      options.onUse()
      const face = faces().find((item) => item.dataset.navFace === link.dataset.navLink)
      if (!face) {
        card!.removeAttribute('data-on')
        go()
        return
      }
      const show = () => {
        faces().forEach((item) => item.toggleAttribute('data-on', item === face))
        card!.toggleAttribute('data-on', true)
      }
      if (card!.hasAttribute('data-on')) {
        show()
        go()
        return
      }
      x = tx
      vx = 0
      draw()
      go()
      cardTimer = window.setTimeout(show, INTENT_MS)
    }

    const away = () => {
      clearTimeout(cardTimer)
      clearTimeout(leaveTimer)
      leaveTimer = window.setTimeout(rest, LEAVE_MS)
    }

    refresh = () => active && near(active)
    restIfIdle = () => !active && rest()

    if (canHover) {
      links.forEach((link) => {
        link.addEventListener('pointerenter', () => near(link), { signal })
        link.addEventListener('focus', () => near(link), { signal })
        link.addEventListener('blur', away, { signal })
        link.addEventListener('click', () => rest(), { signal })
      })
      el.addEventListener('pointerleave', away, { signal })
      card.addEventListener('pointerenter', () => clearTimeout(leaveTimer), { signal })
      card.addEventListener('pointerleave', away, { signal })
      window.addEventListener('keydown', (event) => event.key === 'Escape' && active && rest(), {
        signal,
      })
    }
    window.addEventListener('resize', () => rest(), { signal })

    const start = current()
    if (start) {
      ix = tix = start.offsetLeft
      iw = tiw = start.offsetWidth
    }
    ind.toggleAttribute('data-on', !!start)
    draw()
    document.fonts?.ready.then(() => !signal.aborted && rest())

    onBeforeUnmount(() => {
      abort.abort()
      cancelAnimationFrame(frame)
      clearTimeout(leaveTimer)
      clearTimeout(cardTimer)
    })
  })

  watch(options.spy, () => nextTick(() => restIfIdle()))
  watch(options.cards, () => nextTick(() => refresh()))
  // A new page changes the current link; the line moves there (after the DOM update).
  watch(
    () => route.fullPath,
    () => nextTick(() => rest()),
  )
}
