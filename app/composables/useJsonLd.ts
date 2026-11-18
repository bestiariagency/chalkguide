type JsonLd = Record<string, unknown>

/**
 * Emits one `<script type="application/ld+json">` per object (SSR + client, deduplicated by
 * `key`). No third-party script: plain useHead. `<` is escaped so the data can never close the tag.
 */
export function useJsonLd(
  key: string,
  source: MaybeRefOrGetter<JsonLd | (JsonLd | undefined | null)[] | undefined | null>,
) {
  useHead(() => {
    const value = toValue(source)
    const list = (Array.isArray(value) ? value : [value]).filter((item): item is JsonLd => !!item)
    return {
      script: list.map((data, index) => ({
        key: `ld-${key}-${index}`,
        type: 'application/ld+json',
        innerHTML: JSON.stringify(data).replace(/</g, '\\u003c'),
      })),
    }
  })
}

/**
 * BreadcrumbList from the same crumbs the page renders (Inicio › … › current).
 * Crumbs without `to` (the current page) use the canonical URL of the page.
 */
export function useBreadcrumbJsonLd(
  crumbs: MaybeRefOrGetter<{ label: string; to?: unknown }[]>,
) {
  const localePath = useLocalePath()
  const absolute = useAbsoluteUrl()
  const route = useRoute()
  useJsonLd('breadcrumbs', () =>
    breadcrumbLd(
      toValue(crumbs).map((crumb) => ({
        name: crumb.label,
        url: absolute(crumb.to ? localePath(crumb.to as never) : route.path),
      })),
    ),
  )
}
