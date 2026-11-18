<script setup lang="ts">
import type { GymSummary } from '~/types/domain'
import type { SegmentOption } from '~/types/ui'

/**
 * Home: 3 gyms × 3 data (monthly price, beginner index, author score), sortable.
 * Table from md; "row cards" below md (design system: tables become row cards on mobile).
 */
const props = defineProps<{ gyms: GymSummary[]; total: number }>()
const { t, locale } = useI18n()
const { linkFor } = usePageLinks()

const sortKey = ref<GymSortKey>('score')
const sortOptions = computed<SegmentOption<GymSortKey>[]>(() => [
  { value: 'score', label: t('gyms.sort.score'), shortLabel: t('gyms.sort.scoreShort') },
  { value: 'price', label: t('gyms.sort.price') },
  { value: 'beginner', label: t('gyms.sort.beginner') },
])
const sorted = computed(() => sortGyms(props.gyms, sortKey.value))
const best = computed(() => sortGyms(props.gyms, 'score')[0]?.id)
const sortStatus = computed(() =>
  t('gyms.sortedBy', {
    criterion: sortOptions.value.find((o) => o.value === sortKey.value)?.label ?? '',
  }),
)
const verified = computed(() => {
  const date = latestVerification(props.gyms)
  return date ? formatDate(date, locale.value, { month: 'long', year: 'numeric' }) : null
})
</script>

<template>
  <section
    id="rocodromos"
    data-nav-section="climbing-gyms"
    class="scroll-mt-14 bg-elevated"
    aria-labelledby="home-gyms-title"
  >
    <div class="mx-auto max-w-page px-4 py-20 md:px-6 md:py-28 lg:py-[120px]">
      <h2 id="home-gyms-title" class="title-section">{{ t('home.gyms.title') }}</h2>
      <UiSegmentedControl
        v-model="sortKey"
        :label="t('common.sortBy')"
        :options="sortOptions"
        class="mt-8 w-full md:hidden"
      />

      <GymsRows
        :gyms="sorted"
        :best-id="best"
        :sort-key="sortKey"
        :caption="t('home.gyms.caption')"
        @sort="sortKey = $event"
      />
      <p class="sr-only" aria-live="polite">{{ sortStatus }}</p>

      <div class="mt-8 flex flex-wrap items-center justify-between gap-x-6 gap-y-4">
        <p class="text-caption text-meta">
          <template v-if="verified">{{ t('gyms.verifiedIn', { month: verified }) }} · </template>
          <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')">{{ t('gyms.howIndex') }}</UiTextLink>
        </p>
        <UiButton variant="ghost" arrow :to="{ name: 'climbing-gyms' }">
          {{ t('gyms.seeAll', { count: total }) }}
        </UiButton>
      </div>
    </div>
  </section>
</template>
