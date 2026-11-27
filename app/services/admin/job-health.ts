import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import type { JobHealth } from '~/utils/admin-dashboard-health'
import { guideSchema, unwrap } from '../client'

/** Last hourly check (`guide.job_health`, admin-only RLS) of the given jobs; `details` is reduced to numbers and the `alerts` texts. */
export async function fetchJobHealth(client: SupabaseClient<Database>, jobs: string[]): Promise<JobHealth[]> {
  const rows = unwrap(await guideSchema(client).from('job_health').select('job, checked_at, status_code, details').in('job', jobs))
  return rows.map((r) => {
    const d = (r.details && typeof r.details === 'object' && !Array.isArray(r.details) ? r.details : {}) as Record<string, unknown>
    return {
      job: r.job,
      checkedAt: r.checked_at,
      statusCode: r.status_code,
      alerts: Array.isArray(d.alerts) ? d.alerts.filter((a): a is string => typeof a === 'string') : [],
      numbers: Object.fromEntries(Object.entries(d).filter(([, v]) => typeof v === 'number')) as Record<string, number>,
    }
  })
}
