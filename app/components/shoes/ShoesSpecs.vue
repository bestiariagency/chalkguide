<script setup lang="ts">
import { ArrowRight } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'
import type { DataRow } from '~/types/ui'

/** Technical data (manufacturer) + price box with its date and the affiliate mark. Sticky from lg. */
const props = defineProps<{ shoe: ShoeSummary }>()
const { t, locale } = useI18n()

const label = (prefix: string, value: string | null) => (value ? t(`${prefix}.${value}`) : null)
const list = (prefix: string, values: string[]) =>
  values.length ? values.map((v) => t(`${prefix}.${v}`)).join(', ') : null

const rows = computed<DataRow[]>(() => {
  const s = props.shoe
  return [
    { label: t('shoes.detail.spec.fit'), value: label('shoes.fit', s.fit) },
    { label: t('shoes.rows.profile'), value: label('shoes.profile', s.profile) },
    { label: t('shoes.rows.asymmetry'), value: label('shoes.asymmetry', s.asymmetry) },
    { label: t('shoes.rows.closure'), value: label('shoes.closure', s.closure) },
    { label: t('shoes.rows.rubber'), value: s.rubber },
    {
      label: t('shoes.detail.spec.thickness'),
      value: s.rubberThicknessMm === null ? null : t('shoes.compare.thickness', { mm: formatScore(s.rubberThicknessMm, locale.value) }),
    },
    { label: t('shoes.rows.stiffness'), value: s.stiffness === null ? null : `${s.stiffness}/5` },
    { label: t('shoes.rows.use'), value: list('shoes.use', s.recommendedUse) },
    { label: t('shoes.rows.level'), value: list('shoes.level', s.levels) },
  ].filter((row) => row.value !== null)
})
const price = computed(() => formatEurRange(props.shoe.priceMin, props.shoe.priceMax, locale.value))
const checked = computed(() =>
  props.shoe.priceCheckedAt ? formatDate(props.shoe.priceCheckedAt, locale.value, SHORT_MONTH_DATE) : null,
)
</script>

<template>
  <aside id="data" class="min-w-0 scroll-mt-20 lg:col-span-5" aria-labelledby="shoe-data-title">
    <div class="lg:sticky lg:top-24">
      <div class="flex flex-wrap items-end justify-between gap-2">
        <h2 id="shoe-data-title" class="text-title-4 font-medium">{{ t('shoes.detail.dataTitle') }}</h2>
        <UiBadge>{{ t('shoes.detail.fromMaker') }}</UiBadge>
      </div>
      <ItemsDataList v-if="rows.length" :rows="rows" class="mt-4" />

      <div class="mt-6 rounded-lg border-[0.5px] border-line-strong bg-board p-5">
        <div class="flex items-baseline justify-between gap-3">
          <p class="text-body-sm text-meta">{{ t('shoes.detail.price') }}</p>
          <p class="font-mono text-[22px] tabular-nums" :class="price ? 'text-accent' : 'text-meta'">
            {{ price ?? t('common.priceUnavailable') }}
          </p>
        </div>
        <p v-if="checked" class="mt-1 font-mono text-note text-meta">
          {{ t('shoes.detail.priceChecked', { date: checked }) }}
        </p>
        <ShoesAffiliate :shoe="shoe" variant="box" class="mt-4" />
      </div>

      <UiTextLink :to="{ name: 'climbing-shoes', query: { comparar: shoe.slug }, hash: '#comparacion' }" class="mt-5 inline-flex min-h-11 items-center gap-1.5 text-body-sm">
        {{ t('shoes.detail.compareWithOthers') }}
        <ArrowRight :size="16" aria-hidden="true" />
      </UiTextLink>
    </div>
  </aside>
</template>
