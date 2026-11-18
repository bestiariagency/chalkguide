/**
 * Domains a source must not have (leona-lia, F8.16). The allowlist accepts subdomains, so a source on a multi-user platform
 * would let anyone with an account there pass for a trusted medium; and a public suffix would allow every site under it.
 * Client-side guard with a clear message; the real boundary stays the allowlist and the agent's own checks.
 */

/** Multi-user platforms: the domain itself and every subdomain of it are rejected. */
const PLATFORMS: readonly string[] = [
  'blogspot.com', 'blogspot.com.es', 'wordpress.com', 'substack.com', 'medium.com', 'github.io', 'gitlab.io', 'netlify.app', 'vercel.app',
  'pages.dev', 'workers.dev', 'herokuapp.com', 'wixsite.com', 'weebly.com', 'squarespace.com', 'tumblr.com', 'ghost.io', 'notion.site',
  'webflow.io', 'carrd.co', 'linktr.ee', 'bio.link', 'beacons.ai', 'facebook.com', 'instagram.com', 'x.com', 'twitter.com', 'youtube.com',
  'tiktok.com', 'linkedin.com', 'reddit.com', 'telegram.me', 't.me', 'fandom.com', 'wikia.com', 'blogger.com', 'sites.google.com',
]

/** Public suffixes (only the exact host is rejected: `bbc.co.uk` is a normal domain, `co.uk` is not). */
const PUBLIC_SUFFIXES: readonly string[] = [
  'co.uk', 'org.uk', 'me.uk', 'ac.uk', 'gov.uk', 'com.es', 'org.es', 'nom.es', 'gob.es', 'edu.es', 'com.au', 'co.nz', 'co.jp', 'com.br', 'com.mx',
  'com.ar', 'co.za', 'co.in', 'com.pt', 'com.fr', 'asso.fr', 'com.de', 'co.at', 'com.cn', 'com.tr', 'co.il', 'cat', 'com', 'org', 'net', 'es', 'eu', 'info', 'io', 'app', 'dev',
]

export type SourceDomainProblem = 'platform' | 'suffix' | null

/** Why a host cannot be a source, or null when it can. `host` is lower case, without `www.`. */
export function sourceDomainProblem(host: string): SourceDomainProblem {
  const h = host.toLowerCase().replace(/^www\./, '').replace(/\.$/, '')
  if (!h) return null
  if (PLATFORMS.some((p) => h === p || h.endsWith(`.${p}`))) return 'platform'
  if (PUBLIC_SUFFIXES.includes(h)) return 'suffix'
  return null
}

export const SOURCE_DOMAIN_MESSAGES: Record<Exclude<SourceDomainProblem, null>, string> = {
  platform: 'Es una plataforma donde puede publicar cualquiera (blogspot, wordpress, substack, medium, github.io…): no puede ser una fuente. Usa la web propia del medio.',
  suffix: 'Es un sufijo público (co.uk, com.es…), no la web de un medio. Escribe el dominio completo del medio.',
}

/** True when the host of a news item is not exactly the source's domain (a subdomain, another host, a look-alike). */
export function hostDiffers(sourceUrl: string, domain: string | null | undefined): boolean {
  if (!domain) return false
  try {
    return new URL(sourceUrl).hostname.toLowerCase().replace(/^www\./, '') !== domain.toLowerCase().replace(/^www\./, '')
  } catch {
    return false
  }
}
