import type { SupabaseClient } from '@supabase/supabase-js'
import type { Database } from '~/types/database.types'
import { ServiceError } from './client'

export interface StorageConfig {
  baseUrl: string
  apiKey: string
}

export interface StorageUpload {
  bucket: string
  path: string
  blob: Blob
  mime: string
  /** `max-age` in seconds. */
  maxAge: number
  onProgress?: (fraction: number) => void
  signal?: AbortSignal
}

/**
 * POST to Storage with real progress (supabase-js has none): raw body, bearer = the user's session,
 * never `upsert` (objects are immutable). Rejects with `ServiceError.code` = the HTTP status.
 */
export async function uploadObject(client: SupabaseClient<Database>, config: StorageConfig, file: StorageUpload): Promise<void> {
  const { data } = await client.auth.getSession()
  const token = data.session?.access_token
  if (!token) throw new ServiceError('Sesión caducada. Vuelve a entrar.', '401')
  await new Promise<void>((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('POST', `${config.baseUrl.replace(/\/$/, '')}/storage/v1/object/${file.bucket}/${file.path}`)
    xhr.setRequestHeader('Authorization', `Bearer ${token}`)
    xhr.setRequestHeader('apikey', config.apiKey)
    xhr.setRequestHeader('Content-Type', file.mime)
    xhr.setRequestHeader('Cache-Control', `max-age=${file.maxAge}`)
    xhr.upload.onprogress = (e) => e.lengthComputable && file.onProgress?.(e.loaded / e.total)
    xhr.onload = () => (xhr.status >= 200 && xhr.status < 300 ? resolve() : reject(new ServiceError(`upload ${xhr.status}`, String(xhr.status))))
    xhr.onerror = () => reject(new ServiceError('Error de red al subir el archivo.'))
    xhr.onabort = () => reject(new DOMException('Cancelada', 'AbortError'))
    file.signal?.addEventListener('abort', () => xhr.abort(), { once: true })
    xhr.send(file.blob)
  })
}

/** Removes objects from a bucket (a missing object is not an error for Storage). */
export async function removeObjects(client: SupabaseClient<Database>, bucket: string, paths: string[]): Promise<void> {
  if (!paths.length) return
  const { error } = await client.storage.from(bucket).remove(paths)
  if (error) throw new ServiceError(error.message)
}
