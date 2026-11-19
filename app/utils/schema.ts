/**
 * schema.org JSON-LD builders (no dependency: plain objects serialized by useJsonLd).
 * Rules from .ai/marketing-seo.md: AggregateRating only with >= 3 real reader opinions
 * (the caller passes `ratings` already filtered by the view/site_settings minimum); a Review is
 * emitted only when the author really wrote one.
 */
export type JsonLd = Record<string, unknown>

export const AUTHOR_NAME = 'Xavi'

/** Drops null/undefined/empty values so the JSON-LD only carries what we really know. */
export function compactLd<T extends JsonLd>(value: T): T {
  return Object.fromEntries(
    Object.entries(value).filter(([, v]) => {
      if (v === null || v === undefined || v === '') return false
      if (Array.isArray(v) && !v.length) return false
      return true
    }),
  ) as T
}

export const organizationId = (siteUrl: string) => `${siteUrl}/#organization`
export const websiteId = (siteUrl: string) => `${siteUrl}/#website`

export function siteGraphLd(input: {
  siteUrl: string
  name: string
  description?: string
  logoUrl: string
  sameAs?: string[]
  locale: 'es' | 'en'
}): JsonLd {
  const { siteUrl, name, description, logoUrl, sameAs, locale } = input
  return {
    '@context': 'https://schema.org',
    '@graph': [
      compactLd({
        '@type': 'Organization',
        '@id': organizationId(siteUrl),
        name,
        url: `${siteUrl}/`,
        logo: logoUrl,
        description,
        sameAs,
      }),
      {
        '@type': 'WebSite',
        '@id': websiteId(siteUrl),
        url: `${siteUrl}/`,
        name,
        inLanguage: locale,
        publisher: { '@id': organizationId(siteUrl) },
      },
    ],
  }
}

export function personLd(aboutUrl?: string, name: string = AUTHOR_NAME): JsonLd {
  return compactLd({ '@type': 'Person', name, url: aboutUrl })
}

export function breadcrumbLd(items: { name: string; url: string }[]): JsonLd {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: item.url,
    })),
  }
}

export function articleLd(input: {
  url: string
  siteUrl: string
  headline: string
  description?: string
  image?: string
  publishedAt: string | null
  modifiedAt: string
  section?: string
  language: 'es' | 'en'
  aboutUrl?: string
  /** Name of an article author other than the site author; it has no author page. */
  authorName?: string
}): JsonLd {
  return {
    '@context': 'https://schema.org',
    ...compactLd({
      '@type': 'Article',
      '@id': `${input.url}#article`,
      headline: input.headline,
      description: input.description,
      image: input.image ? [input.image] : undefined,
      datePublished: input.publishedAt,
      dateModified: input.modifiedAt,
      articleSection: input.section,
      inLanguage: input.language,
      mainEntityOfPage: input.url,
      author: input.authorName ? personLd(undefined, input.authorName) : personLd(input.aboutUrl),
      publisher: { '@id': organizationId(input.siteUrl) },
    }),
  }
}

/**
 * `Article` of an indexable news page (noticias-seo-spec §19.5): the author is the Organization (the routine drafts and Xavi
 * edits, so crediting him as a Person would not be true), Xavi is the `editor`, and the original is `isBasedOn` + `citation`.
 * `about` is the first related ChalkGuide page and `mentions` the related ones (up to 3). No `NewsArticle`, no `articleBody`.
 */
export function newsArticleLd(input: {
  url: string
  siteUrl: string
  headline: string
  description?: string
  image?: string
  publishedAt: string | null
  modifiedAt: string
  section?: string
  language: 'es' | 'en'
  aboutUrl?: string
  source: { url: string; name: string; title?: string | null; publishedOn?: string | null }
  related: { name: string; url?: string }[]
}): JsonLd {
  const thing = (r: { name: string; url?: string }) => compactLd({ '@type': 'Thing', name: r.name, url: r.url })
  const [about, ...rest] = input.related
  return {
    '@context': 'https://schema.org',
    ...compactLd({
      '@type': 'Article',
      '@id': `${input.url}#article`,
      headline: input.headline,
      description: input.description,
      image: input.image ? [input.image] : undefined,
      datePublished: input.publishedAt,
      dateModified: input.modifiedAt,
      articleSection: input.section,
      inLanguage: input.language,
      mainEntityOfPage: input.url,
      author: { '@id': organizationId(input.siteUrl) },
      editor: personLd(input.aboutUrl),
      publisher: { '@id': organizationId(input.siteUrl) },
      isBasedOn: compactLd({
        '@type': 'CreativeWork',
        url: input.source.url,
        name: input.source.title ?? undefined,
        publisher: { '@type': 'Organization', name: input.source.name },
        datePublished: input.source.publishedOn ?? undefined,
      }),
      citation: input.source.url,
      about: about ? thing(about) : undefined,
      mentions: input.related.length ? [...(about ? [thing(about)] : []), ...rest.map(thing)] : undefined,
    }),
  }
}

export function itemListLd(items: { name: string; url: string }[]): JsonLd {
  return {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    numberOfItems: items.length,
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      url: item.url,
      name: item.name,
    })),
  }
}
