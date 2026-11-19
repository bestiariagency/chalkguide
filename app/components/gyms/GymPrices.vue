<script setup lang="ts">
import { ExternalLink, MapPin, TrainFront } from 'lucide-vue-next'
import type { GymDetail } from '~/types/gym-detail'
import type { DataRow } from '~/types/ui'

/** Prices (with verification date, "old" past 6 months), opening hours and location. */
const props = defineProps<{ detail: GymDetail }>()
const { t, locale } = useI18n()

const eur = (value: number | null) => formatEur(value, locale.value)
const priceRows = computed<DataRow[]>(() => {
  const p = props.detail.prices
  return [
    { label: t('gyms.detail.price.monthly'), value: eur(p.monthly), tone: 'accent' as const },
    { label: t('gyms.detail.price.pass10'), value: eur(p.pass10) },
    { label: t('gyms.detail.price.day'), value: eur(p.day) },
    { label: t('gyms.detail.price.registration'), value: eur(p.registration) },
  ].filter((row) => row.value !== null)
})
const hoursRows = computed<DataRow[]>(() =>
  groupHours(props.detail.openingHours).map((row) => ({
    label: formatWeekdayGroup(
      row.days.map((day) => WEEKDAYS.indexOf(day)),
      locale.value,
    ),
    value: row.slots,
  })),
)
const place = computed(() =>
  [props.detail.address, props.detail.city].filter(Boolean).join(' · '),
)
</script>

<template>
  <section id="data" class="scroll-mt-20" aria-labelledby="gym-data-title">
    <div class="flex flex-wrap items-end justify-between gap-3">
      <h2 id="gym-data-title" class="text-title-2 font-medium">{{ t('gyms.detail.nav.data') }}</h2>
      <ItemsVerified :date="detail.prices.verifiedAt" />
    </div>
    <div class="mt-6 grid gap-8 md:grid-cols-2">
      <div>
        <ItemsDataList v-if="priceRows.length" :rows="priceRows" />
        <p v-else class="text-meta">{{ t('common.priceUnavailable') }}</p>
        <p v-if="detail.prices.discounts" class="mt-4 text-caption text-meta">
          {{ detail.prices.discounts }}
        </p>
      </div>
      <div>
        <ItemsDataList v-if="hoursRows.length" :rows="hoursRows" />
        <p v-if="detail.openingHoursNote" class="mt-4 text-caption text-meta">
          {{ detail.openingHoursNote }}
        </p>
        <ul class="mt-5 space-y-2 text-body-sm">
          <li v-if="place" class="flex gap-2">
            <MapPin :size="16" class="mt-1 shrink-0 text-meta" aria-hidden="true" />{{ place }}
          </li>
          <li v-if="detail.metroStations.length" class="flex gap-2">
            <TrainFront :size="16" class="mt-1 shrink-0 text-meta" aria-hidden="true" />
            {{ detail.metroStations.join(' · ') }}
          </li>
          <li v-if="detail.websiteUrl" class="flex gap-2">
            <ExternalLink :size="16" class="mt-1 shrink-0 text-meta" aria-hidden="true" />
            <UiTextLink :href="detail.websiteUrl" external data-track="outbound_gym">
              {{ t('gyms.detail.website') }}
            </UiTextLink>
          </li>
        </ul>
      </div>
    </div>
  </section>
</template>
