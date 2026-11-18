import type { ToastItem, ToastType } from '~/types/ui'

const AUTO_DISMISS_MS = 5000

/**
 * Global toasts (rendered once by <UiToastRegion> in the layout).
 * Success and info leave after 5 s; errors stay until closed (role="alert").
 */
export function useToast() {
  const toasts = useState<ToastItem[]>('toasts', () => [])

  function dismiss(id: number) {
    toasts.value = toasts.value.filter((toast) => toast.id !== id)
  }

  function show(type: ToastType, title: string, body?: string, fixedId?: number) {
    const id = fixedId ?? Date.now() + Math.random()
    // A fixed id replaces the previous toast with that id (no stacking).
    toasts.value = [...toasts.value.filter((toast) => toast.id !== id), { id, type, title, body }]
    if (type !== 'error' && import.meta.client) {
      setTimeout(() => dismiss(id), AUTO_DISMISS_MS)
    }
    return id
  }

  return {
    toasts: readonly(toasts),
    dismiss,
    success: (title: string, body?: string) => show('success', title, body),
    info: (title: string, body?: string, id?: number) => show('info', title, body, id),
    error: (title: string, body?: string) => show('error', title, body),
  }
}
