import type { GymSummary } from '~/types/domain'

/** Gym listing state in the URL (see useUrlListing). Search: name, type, district and metro. */
export function useGymListing(gyms: MaybeRefOrGetter<GymSummary[]>, showVariety: MaybeRefOrGetter<boolean> = true) {
  const { t } = useI18n()
  return useUrlListing({
    items: gyms,
    sortKeys: () => (toValue(showVariety) ? GYM_LIST_SORT_KEYS : GYM_LIST_SORT_KEYS.filter((k) => k !== 'variety')),
    defaultSort: 'price',
    filterKeys: GYM_FILTER_KEYS,
    sort: sortGymsForList,
    filter: filterGyms,
    searchFields: (gym) => [
      gym.name,
      gymTypeKey(gym) && t(gymTypeKey(gym) as string),
      gym.district,
      ...gym.metroStations,
    ],
  })
}
