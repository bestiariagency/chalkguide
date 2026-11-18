import type { Database } from '~/types/database.types'
import {
  adminSignOut,
  fetchIsAdmin,
  requestPasswordReset,
  signInWithPassword,
  updateAdminPassword,
  waitForSession,
} from '~/services/admin/auth'

/** Admin check cached per user id for the session, so navigating does not call the RPC every time. */
export function useAdminAuth() {
  const client = useSupabaseClient<Database>()
  const user = useSupabaseUser()
  const verified = useState<{ userId: string; isAdmin: boolean } | null>('admin-verified', () => null)

  /** The session lives in the browser (useSsrCookies: false): read it from the client itself. */
  async function sessionUserId() {
    const { data } = await client.auth.getSession()
    return data.session?.user.id ?? null
  }

  /** null = no session; otherwise whether the session belongs to guide.admins. */
  async function checkAdmin(): Promise<boolean | null> {
    const id = await sessionUserId()
    if (!id) return null
    if (verified.value?.userId === id) return verified.value.isAdmin
    const isAdmin = await fetchIsAdmin(client)
    verified.value = { userId: id, isAdmin }
    return isAdmin
  }

  /** Signs in and checks guide.is_admin(). Non-admins are signed out. Throws on auth errors. */
  async function login(email: string, password: string): Promise<'ok' | 'no-access'> {
    await signInWithPassword(client, email, password)
    const id = await sessionUserId()
    let isAdmin: boolean
    try {
      isAdmin = await fetchIsAdmin(client)
    } catch (error) {
      await logout()
      throw error
    }
    if (!isAdmin) {
      await logout()
      return 'no-access'
    }
    if (id) verified.value = { userId: id, isAdmin: true }
    return 'ok'
  }

  async function logout() {
    verified.value = null
    clearRecent()
    await adminSignOut(client)
    user.value = null
  }

  /** Sends the recovery link; it lands on /administrador/restablecer. */
  async function sendResetLink(email: string) {
    await requestPasswordReset(client, email, `${window.location.origin}${ADMIN_RESET}`)
  }

  /** Waits for the session created by the recovery link. */
  const hasRecoverySession = () => waitForSession(client)

  /** Sets the new password, then applies the same admin check as login. */
  async function setNewPassword(password: string): Promise<'ok' | 'no-access'> {
    await updateAdminPassword(client, password)
    verified.value = null
    let isAdmin: boolean | null
    try {
      isAdmin = await checkAdmin()
    } catch (error) {
      await logout()
      throw error
    }
    if (!isAdmin) {
      await logout()
      return 'no-access'
    }
    return 'ok'
  }

  return { checkAdmin, login, logout, sendResetLink, hasRecoverySession, setNewPassword }
}
