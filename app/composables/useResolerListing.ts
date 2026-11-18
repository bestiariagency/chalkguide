import type { ResolerSummary } from '~/types/domain'

/** Resoler listing state in the URL (see useUrlListing). Search: name, district and services. */
export function useResolerListing(items: MaybeRefOrGetter<ResolerSummary[]>) {
  const { t } = useI18n()
  return useUrlListing({
    items,
    sortKeys: RESOLER_SORT_KEYS,
    defaultSort: 'score',
    filterKeys: RESOLER_FILTER_KEYS,
    sort: sortResolers,
    filter: filterResolers,
    searchFields: (resoler) => [
      resoler.name,
      resoler.district,
      ...resoler.services.map((service) => t(`resolers.services.${service}`)),
    ],
  })
}
