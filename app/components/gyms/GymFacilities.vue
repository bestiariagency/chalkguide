<script setup lang="ts">
import type { GymSummary } from '~/types/domain'
import type { GymDetail } from '~/types/gym-detail'
import type { DataRow } from '~/types/ui'

/** Facilities (Yes/No) and the derived indices, which are computed, not opined. */
const props = defineProps<{ gym: GymSummary; detail: GymDetail }>()
const { t, locale } = useI18n()
const { linkFor } = usePageLinks()

const yesNo = (value: boolean | null): Pick<DataRow, 'value' | 'tone'> =>
  value === null
    ? { value: null, tone: 'muted' }
    : { value: t(value ? 'common.yes' : 'common.no'), tone: value ? undefined : 'muted' }
const num = (value: number | null, unit = ''): string | null =>
  value === null ? null : `${new Intl.NumberFormat(locale.value).format(value)}${unit}`

const f = computed(() => props.detail.facilities)
const sizeRows = computed<DataRow[]>(() => [
  { label: t('gyms.detail.fac.surface'), value: num(f.value.surfaceM2, ' m²') },
  { label: t('gyms.detail.fac.height'), value: num(f.value.maxHeightM, ' m') },
  { label: t('gyms.detail.fac.routes'), value: num(f.value.routesCount) },
  { label: t('gyms.detail.fac.autobelays'), value: num(f.value.autobelaysCount) },
  { label: t('gyms.detail.fac.boulder'), ...yesNo(f.value.hasBoulder) },
  { label: t('gyms.detail.fac.training'), ...yesNo(f.value.hasTrainingArea) },
  {
    label: t('gyms.detail.fac.belayTest'),
    value:
      f.value.belayTestRequired === null
        ? null
        : t(f.value.belayTestRequired ? 'gyms.detail.fac.required' : 'gyms.detail.fac.notRequired'),
  },
])
const serviceRows = computed<DataRow[]>(() => [
  { label: t('gyms.detail.fac.gearRental'), ...yesNo(f.value.gearRental) },
  { label: t('gyms.detail.fac.courses'), ...yesNo(f.value.hasBeginnerCourses) },
  { label: t('gyms.detail.fac.cafe'), ...yesNo(f.value.hasCafe) },
  { label: t('gyms.detail.fac.beer'), ...yesNo(f.value.servesBeer) },
  {
    label: t('gyms.detail.fac.kids'),
    ...yesNo(f.value.hasKidsArea),
    ...(f.value.hasKidsArea === false && f.value.kidsMinAge !== null
      ? { value: t('gyms.detail.fac.noFromAge', { age: f.value.kidsMinAge }) }
      : {}),
  },
  { label: t('gyms.detail.fac.showers'), ...yesNo(f.value.hasShowers) },
  { label: t('gyms.detail.fac.wifi'), ...yesNo(f.value.hasWifi) },
])
</script>

<template>
  <section id="facilities" class="scroll-mt-20" aria-labelledby="gym-fac-title">
    <h2 id="gym-fac-title" class="text-title-2 font-medium">{{ t('gyms.detail.nav.facilities') }}</h2>
    <div class="mt-6 grid gap-x-8 md:grid-cols-2">
      <ItemsDataList :rows="sizeRows" />
      <ItemsDataList :rows="serviceRows" />
    </div>

    <h3 class="mt-12 label-mini">{{ t('gyms.detail.indices.title') }}</h3>
    <div class="mt-4 grid gap-3 tabular-nums sm:grid-cols-3">
      <div class="rounded-lg border-[0.5px] border-line-strong bg-board p-5">
        <p class="text-caption text-meta">{{ t('gyms.sort.beginner') }}</p>
        <p class="mt-1 font-mono text-2xl">
          {{ formatScore(gym.beginnerIndex, locale) ?? t('common.noData') }}
          <span class="text-caption text-meta">{{ t('ratings.outOf') }}</span>
        </p>
        <UiIndexBar :value="gym.beginnerIndex" class="mt-3" />
      </div>
      <div class="rounded-lg border-[0.5px] border-line-strong bg-board p-5">
        <p class="text-caption text-meta">{{ t('gyms.detail.indices.family') }}</p>
        <p class="mt-1 font-mono text-2xl">
          {{ formatScore(gym.familyIndex, locale) ?? t('common.noData') }}
          <span class="text-caption text-meta">{{ t('ratings.outOf') }}</span>
        </p>
        <UiIndexBar :value="gym.familyIndex" class="mt-3" />
      </div>
      <div class="rounded-lg border-[0.5px] border-line-strong bg-board p-5">
        <p class="text-caption text-meta">{{ t('gyms.detail.indices.monthlyCost') }}</p>
        <p class="mt-1 font-mono text-2xl">
          {{ formatEur(gym.monthlyCost2pw, locale) ?? t('common.noData') }}
        </p>
      </div>
    </div>
    <p class="mt-4 text-caption text-meta">
      <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')">{{ t('transparency.learnMore') }}</UiTextLink>
    </p>
  </section>
</template>
