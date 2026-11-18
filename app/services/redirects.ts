import type { Locale } from '~/types/domain'
import { type GuideClient, unwrap } from './client'

export type RedirectKind = 'article' | 'article_category' | 'gym' | 'resoler' | 'shoe'

/** D24: current slug for a retired one (null when there is no redirect). Single hop, no chains. */
export async function resolveRedirect(
  db: GuideClient,
  kind: RedirectKind,
  locale: Locale,
  slug: string,
): Promise<string | null> {
  const result = await db.rpc('resolve_redirect', { p_kind: kind, p_locale: locale, p_slug: slug })
  // The generated type says string, but the function returns null when nothing matches.
  return (unwrap(result) as string | null) || null
}
