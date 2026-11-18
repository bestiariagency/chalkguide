/** Mobile drawer of the panel menu (< 768). Closes on route change and with Escape. */
export function useAdminMenu() {
  const open = useState('admin-menu-open', () => false)
  const route = useRoute()

  watch(() => route.fullPath, () => (open.value = false))

  onMounted(() => {
    const onKey = (event: KeyboardEvent) => event.key === 'Escape' && (open.value = false)
    window.addEventListener('keydown', onKey)
    onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
  })

  return { open, toggle: () => (open.value = !open.value), close: () => (open.value = false) }
}
