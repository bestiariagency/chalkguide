export interface AdminSortableOptions<T> {
  items: Ref<T[]>
  itemKey: (item: T) => string
  itemLabel: (item: T) => string
  /** Called once an order change is committed (drop, menu move). */
  onCommit: (items: T[], moved: { key: string; from: number; to: number }) => void
}

/**
 * Reorder logic shared by mouse drag and keyboard (Space to lift, arrows to move, Space to drop,
 * Esc to cancel) with screen-reader announcements. Pure state: the component renders it.
 */
export function useAdminSortable<T>(options: AdminSortableOptions<T>) {
  const { items, itemKey, itemLabel, onCommit } = options
  const lifted = ref<string | null>(null)
  const dragging = ref<string | null>(null)
  const drop = ref<{ key: string; after: boolean } | null>(null)
  const announcement = ref('')
  let snapshot: T[] = []
  let origin = -1

  const indexOf = (key: string) => items.value.findIndex((item) => itemKey(item) === key)
  const total = () => items.value.length
  const labelAt = (key: string) => itemLabel(items.value[indexOf(key)] as T)

  function place(key: string, to: number) {
    const from = indexOf(key)
    const target = Math.max(0, Math.min(total() - 1, to))
    if (from < 0 || from === target) return false
    const next = [...items.value]
    const [item] = next.splice(from, 1)
    next.splice(target, 0, item as T)
    items.value = next
    return true
  }

  /** Immediate move (menu "Mover arriba/abajo"): commits on its own. */
  function moveBy(key: string, delta: number) {
    const from = indexOf(key)
    if (place(key, from + delta)) {
      onCommit(items.value, { key, from, to: indexOf(key) })
      announcement.value = `${labelAt(key)} movido a la posición ${indexOf(key) + 1} de ${total()}.`
    }
  }

  function lift(key: string) {
    snapshot = [...items.value]
    origin = indexOf(key)
    lifted.value = key
    announcement.value = `${labelAt(key)} recogido, posición ${origin + 1} de ${total()}. Usa las flechas arriba y abajo para moverlo, Espacio para soltarlo y Escape para cancelar.`
  }
  function release(commit: boolean) {
    const key = lifted.value
    if (!key) return
    lifted.value = null
    if (!commit) {
      items.value = snapshot
      announcement.value = 'Movimiento cancelado. El orden no ha cambiado.'
      return
    }
    const to = indexOf(key)
    announcement.value = `${labelAt(key)} soltado en la posición ${to + 1} de ${total()}.`
    if (to !== origin) onCommit(items.value, { key, from: origin, to })
  }

  function onHandleKey(event: KeyboardEvent, key: string) {
    if (event.key === ' ' || event.key === 'Enter') {
      event.preventDefault()
      if (lifted.value === key) release(true)
      else lift(key)
    } else if (lifted.value === key && (event.key === 'ArrowUp' || event.key === 'ArrowDown')) {
      event.preventDefault()
      const to = indexOf(key) + (event.key === 'ArrowUp' ? -1 : 1)
      if (place(key, to)) announcement.value = `Posición ${indexOf(key) + 1} de ${total()}.`
    } else if (lifted.value === key && event.key === 'Escape') {
      event.preventDefault()
      event.stopPropagation()
      release(false)
    }
  }

  // Mouse drag (HTML5 drag and drop; touch uses the move menu instead).
  function dragStart(key: string, event: DragEvent) {
    dragging.value = key
    snapshot = [...items.value]
    origin = indexOf(key)
    event.dataTransfer?.setData('text/plain', key)
    if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move'
  }
  function dragOver(key: string, event: DragEvent) {
    if (!dragging.value) return
    event.preventDefault()
    const box = (event.currentTarget as HTMLElement).getBoundingClientRect()
    drop.value = { key, after: event.clientY > box.top + box.height / 2 }
  }
  function dragEnd(commit = false) {
    const key = dragging.value
    const target = drop.value
    dragging.value = null
    drop.value = null
    if (!commit || !key || !target || target.key === key) return
    let to = indexOf(target.key) + (target.after ? 1 : 0)
    if (indexOf(key) < to) to -= 1
    if (place(key, to)) {
      onCommit(items.value, { key, from: origin, to: indexOf(key) })
      announcement.value = `${labelAt(key)} soltado en la posición ${indexOf(key) + 1} de ${total()}.`
    }
  }

  return { lifted, dragging, drop, announcement, moveBy, onHandleKey, dragStart, dragOver, dragEnd, indexOf }
}
