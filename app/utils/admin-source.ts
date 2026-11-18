/**
 * Source of what the agent brings (F8, F1–F3 of docs/security/F8.1-ingest-spec.md): the panel always shows the
 * domain in clear next to every link of the agent, and marks punycode hosts and «fuente no listada». Texts of the
 * agent are only ever interpolated: this file builds plain strings and never HTML.
 */
import { dayLabel, madridParts } from '~/utils/admin-madrid'

export const SOURCE_LINK_REL = 'nofollow noopener noreferrer ugc'

/** Hostname without `www.`, lower case; '' when the value is not a URL. */
export function sourceDomain(url: string | null | undefined): string {
  if (!url) return ''
  try {
    return new URL(url).hostname.toLowerCase().replace(/^www\./, '')
  } catch {
    return ''
  }
}

/** Only `https` and `http` links are rendered as links (a `javascript:` URL would be inert text). */
export function safeHref(url: string | null | undefined): string | undefined {
  return url && /^https?:\/\//i.test(url) ? url : undefined
}

export interface SourceFlags {
  /** The host (or the label the agent wrote) is punycode: it can imitate another domain. */
  punycode: boolean
  /** Events only: the domain is not in the allowlist of sources. */
  unlisted: boolean
}

/** `agent_meta.note` carries the markers «dominio punycode» and «fuente no listada» (separated by « · »). */
export function sourceFlags(url: string | null | undefined, note: string | null | undefined): SourceFlags {
  const text = (note ?? '').toLowerCase()
  return {
    punycode: /(^|\.)xn--/.test(sourceDomain(url)) || text.includes('dominio punycode'),
    unlisted: text.includes('fuente no listada'),
  }
}

/** «lun 16 nov, 06:12» of an instant (Madrid). */
export const runLabel = (iso: string) => `${dayLabel(iso)}, ${madridParts(iso).time}`

/** «lun 16 nov» of an instant (Madrid). */
export const runDay = (iso: string) => dayLabel(iso)
