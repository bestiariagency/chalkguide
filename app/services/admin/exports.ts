import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database, Json } from '~/types/database.types'
import { parseExportCount, parseRecentExport, type ExportCount, type ExportFormat, type ExportModule, type ExportResult, type RecentExport } from '~/utils/admin-export'
import { guideSchema, unwrap } from '../client'

type Client = SupabaseClient<Database>

/**
 * Panel exports (F6.15, D36). Only the three RPCs: `admin_export` exports and writes the Actividad entry in one
 * transaction, `admin_export_count` never logs.
 */
export async function countExport(client: Client, module: ExportModule, filters: Record<string, Json>, signal?: AbortSignal): Promise<ExportCount> {
  const call = guideSchema(client).rpc('admin_export_count', { p_module: module, p_filters: filters })
  return parseExportCount(unwrap(await (signal ? call.abortSignal(signal) : call)))
}

export async function runExport(client: Client, module: ExportModule, format: ExportFormat, filters: Record<string, Json>, signal?: AbortSignal): Promise<ExportResult> {
  const call = guideSchema(client).rpc('admin_export', { p_module: module, p_format: format, p_filters: filters })
  return unwrap(await (signal ? call.abortSignal(signal) : call)) as unknown as ExportResult
}

export async function fetchRecentExport(client: Client, module: ExportModule): Promise<RecentExport | null> {
  return parseRecentExport(unwrap(await guideSchema(client).rpc('admin_recent_exports', { p_limit: 1, p_module: module })))
}
