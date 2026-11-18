import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { parseActivityPage, type ActivityArgs, type ActivityPage } from '~/utils/admin-activity'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>

/** One page of `guide.admin_activity_list` (cursor pagination). Errors: 22023 invalid parameter, 42501 not admin. */
export async function fetchActivity(client: Client, args: ActivityArgs, signal?: AbortSignal): Promise<ActivityPage> {
  const call = guideSchema(client).rpc('admin_activity_list', args)
  return parseActivityPage(unwrap(await (signal ? call.abortSignal(signal) : call)))
}
