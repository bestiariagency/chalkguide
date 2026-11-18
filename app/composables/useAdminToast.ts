export type AdminToastKind = 'success' | 'error' | 'info'

export interface AdminToast {
  id: number
  kind: AdminToastKind
  message: string
  /** Secondary action ("Deshacer", "Reintentar"). */
  action?: { label: string; run: () => void }
  /** ms; 0 = persistent (errors). */
  duration: number
}

export type AdminToastInput = Pick<AdminToast, 'message' | 'action'> & { duration?: number }

const MAX_TOASTS = 3
let nextId = 1

/**
 * Panel toasts (rendered by `AdminToaster`, mounted once in the admin layout). Success: 5 s with
 * optional "Deshacer"; error: persistent with optional "Reintentar" (`role=alert`); info: 5 s.
 * Max 3 visible: the oldest goes away.
 */
export function useAdminToast() {
  const toasts = useState<AdminToast[]>('admin-toasts', () => [])

  function push(kind: AdminToastKind, input: AdminToastInput | string): number {
    const data = typeof input === 'string' ? { message: input } : input
    const toast: AdminToast = {
      id: nextId++,
      kind,
      message: data.message,
      action: data.action,
      duration: data.duration ?? (kind === 'error' ? 0 : 5000),
    }
    toasts.value = [...toasts.value, toast].slice(-MAX_TOASTS)
    return toast.id
  }
  const dismiss = (id: number) => (toasts.value = toasts.value.filter((t) => t.id !== id))

  return {
    toasts,
    dismiss,
    success: (input: AdminToastInput | string) => push('success', input),
    error: (input: AdminToastInput | string) => push('error', input),
    info: (input: AdminToastInput | string) => push('info', input),
  }
}
