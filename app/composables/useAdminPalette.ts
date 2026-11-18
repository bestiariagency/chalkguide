/**
 * Open state of the ⌘K palette and the "Nuevo" sheet (shared by the sidebar, the bottom bar and
 * the shortcut). Call `useAdminShortcuts()` once in the layout to register ⌘K / Ctrl+K.
 */
export function useAdminPalette() {
  const paletteOpen = useState('admin-palette-open', () => false)
  const newOpen = useState('admin-new-open', () => false)
  return {
    paletteOpen,
    newOpen,
    openPalette: () => {
      newOpen.value = false
      paletteOpen.value = true
    },
    openNew: () => {
      paletteOpen.value = false
      newOpen.value = true
    },
  }
}

export function useAdminShortcuts() {
  const { paletteOpen, openPalette } = useAdminPalette()
  onMounted(() => {
    const onKey = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        if (paletteOpen.value) paletteOpen.value = false
        else openPalette()
      }
    }
    window.addEventListener('keydown', onKey)
    onBeforeUnmount(() => window.removeEventListener('keydown', onKey))
  })
}
