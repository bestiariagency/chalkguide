const GRADES = ['4a', '5a', '5c', '6a', '6b', '6c', '7a', '7b']

/**
 * Home intro: four orange pills rise, cover the screen and lift while the grade counter
 * climbs to 7b. Once per session, never with reduced motion, skippable with click or key. The
 * inline head script (nuxt.config.ts) decides before first paint and sets `has-intro` on <html>
 * (the same mechanism as `.js`); here we only run it. `is-in` on <html> releases the title/rope.
 * @param onReveal the pills are lifting: the ring can start turning.
 */
export function useHeroIntro(onReveal: () => void) {
  const active = ref(true)
  const up = ref(false)
  const open = ref(false)
  const grade = ref(GRADES[0]!)
  const timers: number[] = []
  let counter = 0
  let finished = false
  const root = () => document.documentElement

  function reveal() {
    root().classList.add('is-in')
    onReveal()
  }

  function finish() {
    if (finished) return
    finished = true
    window.clearInterval(counter)
    timers.forEach(clearTimeout)
    up.value = true
    open.value = true
    if (!root().classList.contains('is-in')) reveal()
    timers.push(window.setTimeout(() => (active.value = false), 700))
  }

  onMounted(() => {
    if (!root().classList.contains('has-intro')) {
      active.value = false
      return
    }
    root().setAttribute(HERO_INTRO_MOUNTED_ATTR, '')
    try {
      sessionStorage.setItem(HERO_INTRO_KEY, '1')
    } catch {
      // Storage blocked: the intro may replay on reload, nothing else.
    }
    let g = 0
    counter = window.setInterval(() => {
      if (g < GRADES.length - 1) grade.value = GRADES[++g]!
    }, 80)
    timers.push(window.setTimeout(() => (up.value = true), 660))
    timers.push(
      window.setTimeout(() => {
        open.value = true
        reveal()
      }, 1180),
    )
    timers.push(window.setTimeout(finish, 1200))
    window.addEventListener('keydown', finish, { once: true })
  })

  onBeforeUnmount(() => {
    window.clearInterval(counter)
    timers.forEach(clearTimeout)
    window.removeEventListener('keydown', finish)
    if (import.meta.client) {
      root().classList.remove('has-intro', 'is-in')
      root().removeAttribute(HERO_INTRO_MOUNTED_ATTR)
    }
  })

  return { active, up, open, grade, finish }
}
