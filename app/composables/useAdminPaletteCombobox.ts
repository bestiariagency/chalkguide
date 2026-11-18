import { buildPaletteGroups, emptyActions, flatOptions, type PaletteGroup, type PaletteOption } from '~/utils/admin-palette'
import { MIN_QUERY, type SearchScope } from '~/utils/admin-search'

/** State and keyboard of the ⌘K combobox: text, scope, active option, search and the result of opening an option. */
export function useAdminPaletteCombobox() {
  const { paletteOpen } = useAdminPalette()
  const query = ref('')
  const scope = ref<SearchScope>('all')
  const activeId = ref<string>()
  const recents = ref(readRecent())
  const search = useAdminSearch(query, scope)

  const term = computed(() => query.value.trim())
  const searching = computed(() => term.value.length >= MIN_QUERY)
  const noResults = computed(() => {
    if (!searching.value || search.status.value !== 'ready' || search.answered.value !== term.value) return false
    return !search.groups.value.some((g) => g.rows.length)
  })
  const groups = computed<PaletteGroup[]>(() => {
    const list = buildPaletteGroups({ term: term.value, scope: scope.value, search: search.groups.value, recents: recents.value, answered: search.answered.value === term.value })
    return noResults.value ? [...list, emptyActions(term.value, scope.value)] : list
  })
  const options = computed(() => flatOptions(groups.value))
  const activeIndex = computed(() => Math.max(0, options.value.findIndex((o) => o.id === activeId.value)))

  // The first option is active again whenever the list changes, except with no results: the create shortcut is never armed by default.
  watch(() => options.value.map((o) => o.id).join('|'), () => (activeId.value = noResults.value ? undefined : options.value[0]?.id), { immediate: true })
  watch(paletteOpen, (open) => {
    query.value = ''
    scope.value = 'all'
    search.reset()
    if (open) recents.value = readRecent()
  })

  function move(delta: number) {
    const count = options.value.length
    if (!count) return
    if (!activeId.value) {
      activeId.value = options.value[delta > 0 ? 0 : count - 1]!.id
      return
    }
    activeId.value = options.value[(activeIndex.value + delta + count) % count]!.id
    void nextTick(() => document.getElementById(`pal-${activeId.value}`)?.scrollIntoView({ block: 'nearest' }))
  }

  function open(option: PaletteOption, newTab = false) {
    if (option.type === 'more' || option.type === 'all') {
      scope.value = option.scope ?? 'all'
      return
    }
    if (option.to === undefined) return
    if (option.recent) recents.value = pushRecent({ ...option.recent, title: option.label })
    const exportTarget = EXPORT_TARGETS.find((t) => option.to === `exportar:${t}`)
    const path = exportTarget ? `${adminPath(EXPORT_CONFIGS[exportTarget].route)}?exportar=1` : option.to.startsWith('/') ? option.to : adminPath(option.to)
    paletteOpen.value = false
    if (newTab) window.open(path, '_blank', 'noopener')
    else void navigateTo(path)
  }

  function onKeydown(event: KeyboardEvent) {
    if (event.isComposing) return
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault()
      move(event.key === 'ArrowDown' ? 1 : -1)
    } else if (event.key === 'Enter') {
      const option = options.value.find((o) => o.id === activeId.value)
      if (!option) return
      event.preventDefault()
      open(option, event.metaKey || event.ctrlKey)
    } else if (event.key === 'Backspace' && !query.value && scope.value !== 'all') scope.value = 'all'
  }

  /** Esc clears the text first and only closes with an empty field. */
  function onEscape(event: Event) {
    if (!query.value) return
    event.preventDefault()
    query.value = ''
  }

  const announcement = computed(() => {
    if (search.status.value === 'error') return 'No se ha podido buscar el contenido'
    if (noResults.value) return `Nada coincide con ${term.value}. Elige una acción con las flechas`
    if (searching.value && search.status.value === 'ready') {
      const total = search.groups.value.reduce((sum, g) => sum + g.rows.length, 0)
      return `${total} ${total === 1 ? 'resultado' : 'resultados'}`
    }
    return ''
  })

  return { query, scope, term, searching, search, groups, options, activeId, noResults, announcement, move, open, onKeydown, onEscape }
}
