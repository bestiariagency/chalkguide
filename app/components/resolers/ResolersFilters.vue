<script setup lang="ts">
import type { SegmentOption } from '~/types/ui'

/** Listing controls: mail + service chips + sort order. State lives in the URL. */
defineProps<{
  active: ResolerFilterKey[]
  sortKey: ResolerSortKey
  count: number
  total: number
}>()
const query = defineModel<string>('query', { required: true })
const emit = defineEmits<{
  toggle: [key: ResolerFilterKey]
  sort: [key: ResolerSortKey]
  clear: []
}>()
const { t } = useI18n()

const sortOptions = computed<SegmentOption<ResolerSortKey>[]>(() => [
  { value: 'score', label: t('resolers.sort.score'), shortLabel: t('resolers.sort.scoreShort') },
  { value: 'price', label: t('resolers.sort.price') },
  { value: 'days', label: t('resolers.sort.days') },
])
</script>

<template>
  <ItemsListingControls
    v-model:query="query"
    id-prefix="resolers"
    :filter-keys="RESOLER_FILTER_KEYS"
    :filter-label="(key) => (key === 'mail' ? t('resolers.filters.mail') : t(`resolers.services.${key}`))"
    :active="active"
    :sort-key="sortKey"
    :sort-options="sortOptions"
    :count="count"
    :total="total"
    :noun-one="t('resolers.search.nounOne')"
    :noun-many="t('resolers.search.nounMany')"
    :placeholder="t('resolers.search.placeholder')"
    @toggle="emit('toggle', $event)"
    @sort="emit('sort', $event)"
    @clear="emit('clear')"
  />
</template>
