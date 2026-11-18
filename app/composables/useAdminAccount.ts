import type { Database } from '~/types/database.types'
import { fetchAccountEmail, fetchMySessions, signOutOthers, type AdminSession } from '~/services/admin/settings'
import { updateAdminPassword } from '~/services/admin/auth'

/** "Tu cuenta" (F6.17): masked email, open sessions, close the others and change the password. */
export function useAdminAccount() {
  const client = useSupabaseClient<Database>()
  const { success, error: toastError } = useAdminToast()
  const email = ref('')
  const sessions = ref<AdminSession[]>([])
  const sessionsFailed = ref(false)
  const sessionsLoading = ref(true)
  const closing = ref(false)
  const others = computed(() => sessions.value.filter((s) => !s.is_current).length)

  async function loadSessions() {
    sessionsLoading.value = true
    sessionsFailed.value = false
    try {
      sessions.value = await fetchMySessions(client)
    } catch {
      sessionsFailed.value = true
    } finally {
      sessionsLoading.value = false
    }
  }
  onMounted(async () => {
    void loadSessions()
    try {
      email.value = await fetchAccountEmail(client)
    } catch {
      email.value = ''
    }
  })

  async function closeOthers() {
    if (closing.value) return
    closing.value = true
    try {
      await signOutOthers(client)
      success('Sesiones cerradas. Solo queda esta.')
      await loadSessions()
    } catch {
      toastError({ message: 'No se han podido cerrar las demás sesiones.', action: { label: 'Reintentar', run: () => void closeOthers() } })
    } finally {
      closing.value = false
    }
  }

  /** Returns an error text, or '' once the password is changed. */
  async function changePassword(password: string): Promise<string> {
    try {
      await updateAdminPassword(client, password)
      success('Contraseña cambiada')
      return ''
    } catch (failure) {
      const info = adminPasswordFailure(failure)
      return info.expired ? 'Tu sesión ha caducado. Vuelve a entrar y repite el cambio.' : info.message
    }
  }

  return { email, sessions, sessionsFailed, sessionsLoading, others, closing, loadSessions, closeOthers, changePassword }
}
