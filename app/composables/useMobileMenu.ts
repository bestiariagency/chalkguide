import type { Ref } from 'vue'

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), textarea:not([disabled]), select:not([disabled])'

/**
 * Open state shared by every burger (header and compact bar) and the mobile menu dialog.
 * The dialog behaviour itself (focus, trap, Esc, scroll lock, route close) is `useSheetBehaviour`.
 */
export function useMobileMenu() {
  const isOpen = useState('mobile-menu-open', () => false)
  return {
    isOpen,
    open: () => (isOpen.value = true),
    close: () => (isOpen.value = false),
  }
}

/**
 * `opener`: selector of the controls that open the sheet; used to return focus when the
 * browser did not focus the clicked button (Safari).
 */
export function useSheetBehaviour(
  isOpen: Ref<boolean>,
  panel: Ref<HTMLElement | null>,
  opener?: string,
) {
  let lastFocus: HTMLElement | null = null

  const focusables = () =>
    [...(panel.value?.querySelectorAll<HTMLElement>(FOCUSABLE) ?? [])].filter(
      (el) => el.offsetParent !== null,
    )

  function onKeydown(event: KeyboardEvent) {
    if (!isOpen.value) return
    if (event.key === 'Escape') {
      isOpen.value = false
      return
    }
    if (event.key !== 'Tab') return
    const items = focusables()
    const first = items[0]
    const last = items[items.length - 1]
    if (!first || !last) return
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  watch(isOpen, (open) => {
    document.documentElement.style.overflow = open ? 'hidden' : ''
    if (open) {
      const active = document.activeElement as HTMLElement | null
      const visibleOpener = opener
        ? [...document.querySelectorAll<HTMLElement>(opener)].find(
            (el) => el.offsetParent !== null && !el.closest('[inert]'),
          )
        : undefined
      lastFocus = active && active !== document.body ? active : (visibleOpener ?? null)
      // Wait for the panel to become visible before moving focus.
      setTimeout(() => focusables()[0]?.focus(), 60)
    } else {
      // After the DOM update: the page is `inert` until then and cannot take focus back.
      const target = lastFocus
      lastFocus = null
      nextTick(() => target?.focus())
    }
  })

  const route = useRoute()
  // Path only: a query change (filters, cleaning `?opinar=1`) is not leaving the page.
  watch(
    () => route.path,
    () => {
      if (!isOpen.value) return
      lastFocus = null
      isOpen.value = false
    },
  )

  onMounted(() => window.addEventListener('keydown', onKeydown))
  onBeforeUnmount(() => {
    window.removeEventListener('keydown', onKeydown)
    document.documentElement.style.overflow = ''
  })
}

/** The menu only exists below `lg`: closing it when the viewport grows past it frees scroll lock. */
export function useCloseAtDesktop(isOpen: Ref<boolean>) {
  onMounted(() => {
    const query = window.matchMedia('(min-width: 64rem)') // = Tailwind lg
    const onChange = (event: MediaQueryListEvent) => event.matches && (isOpen.value = false)
    query.addEventListener('change', onChange)
    onBeforeUnmount(() => query.removeEventListener('change', onChange))
  })
}
