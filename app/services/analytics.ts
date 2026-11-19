import type { GuideClient } from './client'
import type { TrackDevice, TrackExtra, TrackName } from '~/utils/track'

export interface TrackEventInput extends TrackExtra {
  name: TrackName
  path: string
  locale: 'es' | 'en'
  device?: TrackDevice
}

/**
 * Writes one event through `guide.track_event` (D69). Never blocks and never throws: an analytics
 * failure must not touch the page, so every error is swallowed.
 */
export async function trackEvent(db: GuideClient, input: TrackEventInput): Promise<void> {
  try {
    await db.rpc('track_event', {
      p_name: input.name,
      p_path: input.path,
      p_locale: input.locale,
      p_content_type: input.contentType,
      p_content_slug: input.contentSlug,
      p_pillar: input.pillar,
      p_partner: input.partner,
      p_source: input.source,
      p_device: input.device,
    })
  } catch {
    // Swallowed on purpose.
  }
}
