import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { ServiceError } from './client'

/** Starts the Google OAuth redirect. Login never subscribes to the newsletter (GDPR). */
export async function signInWithGoogle(client: SupabaseClient<Database>, redirectTo: string) {
  const { error } = await client.auth.signInWithOAuth({ provider: 'google', options: { redirectTo } })
  if (error) throw new ServiceError(error.message, error.code)
}

export async function signOut(client: SupabaseClient<Database>) {
  const { error } = await client.auth.signOut()
  if (error) throw new ServiceError(error.message, error.code)
}
