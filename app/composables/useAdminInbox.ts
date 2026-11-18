import type { Ref } from 'vue'

interface InboxOptions<T extends { id: string }> {
  /** Name of the list rows for `focusListRow`. */
  kind: 'news' | 'event'
  rows: () => readonly T[]
  selectedId: Ref<string | undefined>
  checked: Ref<string[]>
  /** `A` only approves what this allows. */
  canApprove?: (row: T) => boolean
  onApprove: (row: T) => void
  onEdit: (row: T) => void
}

/**
 * Shared behaviour of the «Por revisar» / «Por aprobar» inboxes: list + detail from 1024 px (a sheet below),
 * selection that follows the list, checks, and the keys J/K (move), A (approve), E (edit), D (open the reject menu).
 */
export function useAdminInbox<T extends { id: string }>(options: InboxOptions<T>) {
  const { kind, rows, selectedId, checked, canApprove = () => true } = options
  const desktop = ref(true)
  const rejectOpen = ref(false)
  const selected = computed(() => rows().find((r) => r.id === selectedId.value))
  const index = computed(() => rows().findIndex((r) => r.id === selectedId.value))
  /** Where the selection goes once the current row leaves the list. */
  const neighbour = () => (desktop.value ? (rows()[index.value + 1]?.id ?? rows()[index.value - 1]?.id) : undefined)

  watch(
    rows,
    (list) => {
      const stillThere = list.some((r) => r.id === selectedId.value)
      if (!stillThere) selectedId.value = desktop.value ? list[0]?.id : undefined
      checked.value = checked.value.filter((id) => list.some((r) => r.id === id))
    },
    { immediate: true },
  )
  watch(desktop, (is) => {
    if (is && !selected.value) selectedId.value = rows()[0]?.id
  })

  function step(delta: 1 | -1) {
    const list = rows()
    const from = index.value < 0 ? (delta > 0 ? -1 : 0) : index.value
    const next = list[Math.max(0, Math.min(list.length - 1, from + delta))]
    if (!next) return
    selectedId.value = next.id
    focusListRow(kind, next.id)
  }

  function onKey(event: KeyboardEvent) {
    if (isShortcutBlocked(event, '[role="menu"]')) return
    const key = event.key.toLowerCase()
    const current = selected.value
    if (key === 'j') step(1)
    else if (key === 'k') step(-1)
    else if (key === 'a' && current && canApprove(current)) options.onApprove(current)
    else if (key === 'e' && current) options.onEdit(current)
    else if (key === 'd' && current && desktop.value) rejectOpen.value = true
    else return
    event.preventDefault()
  }

  onMounted(() => {
    const mq = window.matchMedia('(min-width: 1024px)')
    const sync = () => (desktop.value = mq.matches)
    sync()
    mq.addEventListener('change', sync)
    window.addEventListener('keydown', onKey)
    onBeforeUnmount(() => {
      mq.removeEventListener('change', sync)
      window.removeEventListener('keydown', onKey)
    })
  })

  const sheetOpen = computed({ get: () => !desktop.value && !!selected.value, set: (v) => !v && (selectedId.value = undefined) })
  const toggle = (id: string, on: boolean) => (checked.value = on ? [...checked.value, id] : checked.value.filter((x) => x !== id))

  return { desktop, rejectOpen, selected, neighbour, step, sheetOpen, toggle }
}
