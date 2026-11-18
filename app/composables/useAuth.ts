import type { Database } from '~/types/database.types'
import { signInWithGoogle, signOut } from '~/services/auth'

/**
 * Session state for the UI. The session exists only in the browser (useSsrCookies: false), but
 * the client plugin restores it before hydration, so everything that depends on `isSignedIn`
 * is gated by `ready` (set on mount): the HTML cached by ISR is identical for everyone.
 */
export function useAuth() {
  const client = useSupabaseClient<Database>()
  const user = useSupabaseUser()
  const ready = useState('auth-ready', () => false)

  onMounted(() => (ready.value = true))

  const userId = computed(() => {
    const claims = user.value as { sub?: string; id?: string } | null
    return ready.value ? (claims?.sub ?? claims?.id ?? null) : null
  })
  const isSignedIn = computed(() => userId.value !== null)

  /** Google OAuth; the user comes back to `next` (internal path) with `?opinar=1`. */
  async function loginWithGoogle(next: string) {
    const target = safeNextPath(next)
    const url = new URL(target, window.location.origin)
    url.searchParams.set('opinar', '1')
    await signInWithGoogle(client, url.toString())
  }

  async function logout() {
    await signOut(client)
    user.value = null
  }

  /** Link to the sign-in page that returns to `next`. */
  const signInTarget = (next: string) => ({
    name: 'sign-in' as const,
    query: { next: safeNextPath(next) },
  })

  return { ready, userId, isSignedIn, loginWithGoogle, logout, signInTarget }
}
