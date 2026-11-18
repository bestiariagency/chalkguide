import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { ServiceError, guideSchema } from '../client'

/** Email + password sign in (D2). Throws ServiceError with Supabase's `code`/status in `code`. */
export async function signInWithPassword(
  client: SupabaseClient<Database>,
  email: string,
  password: string,
) {
  const { data, error } = await client.auth.signInWithPassword({ email, password })
  if (error) throw new ServiceError(error.message, error.code ?? String(error.status ?? ''))
  return data.user
}

/** `guide.is_admin()`: true only for the user ids in guide.admins. The real guard is RLS. */
export async function fetchIsAdmin(client: SupabaseClient<Database>): Promise<boolean> {
  const { data, error } = await guideSchema(client).rpc('is_admin')
  if (error) throw new ServiceError(error.message, error.code)
  return data === true
}

export async function adminSignOut(client: SupabaseClient<Database>) {
  const { error } = await client.auth.signOut()
  if (error) throw new ServiceError(error.message, error.code)
}

/** Sends the recovery email. Auth settings and templates are shared with Chalk app: API only. */
export async function requestPasswordReset(client: SupabaseClient<Database>, email: string, redirectTo: string) {
  const { error } = await client.auth.resetPasswordForEmail(email, { redirectTo })
  if (error) throw new ServiceError(error.message, error.code ?? String(error.status ?? ''))
}

/** Sets the new password on the current (recovery) session. */
export async function updateAdminPassword(client: SupabaseClient<Database>, password: string) {
  const { error } = await client.auth.updateUser({ password })
  if (error) throw new ServiceError(error.message, error.code ?? String(error.status ?? ''))
}

/**
 * Resolves with true once a session exists (the recovery link signs the user in: PKCE code or
 * hash tokens are consumed by the client on load), false after `timeoutMs` without one.
 */
export async function waitForSession(client: SupabaseClient<Database>, timeoutMs = 4000): Promise<boolean> {
  const { data } = await client.auth.getSession()
  if (data.session) return true
  return new Promise((resolve) => {
    const { data: sub } = client.auth.onAuthStateChange((event, session) => {
      if (session && (event === 'PASSWORD_RECOVERY' || event === 'SIGNED_IN' || event === 'INITIAL_SESSION')) {
        done(true)
      }
    })
    const timer = setTimeout(() => done(false), timeoutMs)
    function done(value: boolean) {
      clearTimeout(timer)
      sub.subscription.unsubscribe()
      resolve(value)
    }
  })
}
