/** Copies a text (`what` completes the error: "el enlace" by default, '' for none) to the clipboard and reports it with a panel toast (error toast when the browser refuses). */
export function useCopyLink() {
  const { success, error: toastError } = useAdminToast()
  return async function copyLink(url: string, done: string, what = 'el enlace') {
    try {
      await navigator.clipboard.writeText(url)
      success(done)
    } catch {
      toastError({ message: `No se ha podido copiar${what ? ` ${what}` : ''}: el navegador ha bloqueado el acceso al portapapeles.`, action: { label: 'Cerrar', run: () => {} } })
    }
  }
}
