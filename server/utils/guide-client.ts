import { createClient } from '@supabase/supabase-js'
import type { H3Event } from 'h3'
import type { Database } from '../../app/types/database.types'
import { guideSchema, type GuideClient } from '../../app/services/client'

/**
 * Read-only `guide` client for the public content routes (D64, F6.19 C3). Publishable key and no
 * session: it never reads the visitor's `Authorization` header or cookies, so an admin who calls the
 * route still gets what anon gets (no drafts). Responses may be cached and shared (C5): they must
 * never depend on who asks. Never `service_role`.
 */
export function guideClient(event: H3Event): GuideClient {
  const config = useRuntimeConfig(event)
  const url = String(config.public.supabase?.url ?? '').replace(/\/$/, '')
  const key = String(config.public.supabase?.key ?? '')
  if (!url || !key) throw createError({ statusCode: 500, statusMessage: 'Supabase public config missing' })
  const client = createClient<Database>(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
  return guideSchema(client)
}

/** Project URL, for the sanitizer (images are kept only inside its public `media` bucket). */
export function supabasePublicUrl(event: H3Event): string {
  return String(useRuntimeConfig(event).public.supabase?.url ?? '')
}
