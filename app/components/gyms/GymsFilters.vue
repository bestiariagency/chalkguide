<script setup lang="ts">
import type { SegmentOption } from '~/types/ui'

/** Listing controls: filter chips (all must match) + sort order. State lives in the URL. */
const props = withDefaults(defineProps<{
  active: GymFilterKey[]
  sortKey: GymListSortKey
  count: number
  total: number
  /** The "variety" criterion is active (otherwise there is no sort by it). */
  showVariety?: boolean
}>(), { showVariety: true })
const query = defineModel<string>('query', { required: true })
const emit = defineEmits<{
  toggle: [key: GymFilterKey]
  sort: [key: GymListSortKey]
  clear: []
}>()
const { t } = useI18n()

const sortOptions = computed<SegmentOption<GymListSortKey>[]>(() => [
  { value: 'price', label: t('gyms.sort.price') },
  { value: 'family', label: t('gyms.sort.family') },
  ...(props.showVariety ? [{ value: 'variety' as const, label: t('gyms.sort.variety') }] : []),
])
</script>

<template>
  <ItemsListingControls
    v-model:query="query"
    id-prefix="gym"
    :filter-keys="GYM_FILTER_KEYS"
    :filter-label="(key) => t(`gyms.filters.${key}`)"
    :active="active"
    :sort-key="sortKey"
    :sort-options="sortOptions"
    :count="count"
    :total="total"
    :noun-one="t('gyms.search.nounOne')"
    :noun-many="t('gyms.search.nounMany')"
    :placeholder="t('gyms.search.placeholder')"
    @toggle="emit('toggle', $event)"
    @sort="emit('sort', $event)"
    @clear="emit('clear')"
  />
</template>
