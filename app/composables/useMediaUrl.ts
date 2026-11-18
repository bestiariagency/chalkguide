import { mediaPublicUrl } from '~/services/media'

/** Public URL builder for `media` objects (bucket is public; no signed URLs needed). */
export function useMediaUrl() {
  const config = useRuntimeConfig()
  const base = String(config.public.supabase?.url ?? '')
  return (path: string) => mediaPublicUrl(base, path)
}
