import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { SettingsLoaded, SettingsRow } from '~/utils/admin-settings'
import { ServiceError, guideSchema, one, unwrap } from '../client'

type Client = SupabaseClient<Database>

const MEDIA = 'id, storage_path, original_filename, alt_es, alt_en, width, height, dominant_color'

/** Published gyms and shoes (calculated boxes of «En números»); null if they cannot be counted (it is only a preview). */
async function countPublished(client: Client): Promise<{ gyms: number; shoes: number } | null> {
  const count = (category: 'gym' | 'shoe') =>
    guideSchema(client).from('items').select('id', { count: 'exact', head: true }).eq('published', true).eq('category', category)
  const [gyms, shoes] = await Promise.all([count('gym'), count('shoe')])
  return gyms.error || shoes.error ? null : { gyms: gyms.count ?? 0, shoes: shoes.count ?? 0 }
}

/** The single settings row, the open consent version and the OG image (name, size, alt) of F6.17. */
export async function fetchSettings(client: Client): Promise<SettingsLoaded> {
  const schema = guideSchema(client)
  const [row, consent, calc] = await Promise.all([
    schema
      .from('site_settings')
      .select(`*, og:media!site_settings_default_og_media_id_fkey(${MEDIA}), author_photo:media!site_settings_author_photo_media_id_fkey(${MEDIA})`)
      .eq('id', 1)
      .single()
      .then(unwrap),
    schema.from('consent_texts').select('version, valid_from').is('valid_to', null).maybeSingle().then((r) => {
      if (r.error) throw new ServiceError(r.error.message, r.error.code)
      return r.data
    }),
    countPublished(client),
  ])
  const { og, author_photo, ...settings } = row
  return {
    row: settings as SettingsRow,
    consent: { version: consent?.version ?? settings.consent_version, validFrom: consent?.valid_from ?? null },
    og: one(og),
    authorPhoto: one(author_photo),
    calc,
  }
}

/** Atomic save with conflict detection: `base` are the loaded values of the same columns. Returns the saved row. */
export async function updateSettings(client: Client, changes: Record<string, unknown>, base: Record<string, unknown>): Promise<SettingsRow> {
  const result = await guideSchema(client).rpc('admin_update_settings', { p_changes: changes as never, p_base: base as never })
  if (result.error) throw new ServiceError(result.error.message, result.error.code, result.error.details ?? undefined)
  return result.data
}

export interface AdminSession {
  is_current: boolean
  user_agent: string
  created_at: string
  last_active_at: string
}

export async function fetchMySessions(client: Client): Promise<AdminSession[]> {
  return unwrap(await guideSchema(client).rpc('admin_my_sessions'))
}

export async function fetchAccountEmail(client: Client): Promise<string> {
  const { data, error } = await client.auth.getUser()
  if (error) throw new ServiceError(error.message, error.code ?? String(error.status ?? ''))
  return data.user?.email ?? ''
}

export async function signOutOthers(client: Client): Promise<void> {
  const { error } = await client.auth.signOut({ scope: 'others' })
  if (error) throw new ServiceError(error.message, error.code ?? String(error.status ?? ''))
}
