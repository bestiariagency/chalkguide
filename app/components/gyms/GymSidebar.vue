<script setup lang="ts">
import type { GymSummary } from '~/types/domain'
import type { GymDetail } from '~/types/gym-detail'
import type { DataRow } from '~/types/ui'

/** Sticky side column: key data and the articles that mention the gym. */
const props = defineProps<{ gym: GymSummary; detail: GymDetail }>()
const { t, locale } = useI18n()

const rows = computed<DataRow[]>(() =>
  [
    {
      label: t('gyms.detail.price.monthly'),
      value: formatEur(props.detail.prices.monthly, locale.value),
      tone: 'accent' as const,
    },
    { label: t('gyms.detail.price.day'), value: formatEur(props.detail.prices.day, locale.value) },
    { label: t('gyms.detail.metro'), value: props.detail.metroStations[0] ?? null },
  ].filter((row) => row.value !== null),
)
</script>

<template>
  <aside class="space-y-6 lg:col-span-4">
    <div class="space-y-6 lg:sticky lg:top-20">
      <div v-if="rows.length" class="rounded-lg border-[0.5px] border-line-strong bg-board p-5">
        <p class="label-mini">{{ t('gyms.detail.keyData') }}</p>
        <ItemsDataList :rows="rows" class="mt-3" />
      </div>
      <div
        v-if="detail.articles.length"
        class="rounded-lg border-[0.5px] border-line-strong bg-board p-5"
      >
        <p class="label-mini">{{ t('gyms.detail.appearsIn') }}</p>
        <ul class="mt-3 space-y-2 text-body-sm">
          <li v-for="article in detail.articles" :key="article.id">
            <UiTextLink :to="{ name: 'blog-slug', params: { slug: article.slug } }">
              {{ article.title }}
            </UiTextLink>
          </li>
        </ul>
      </div>
    </div>
  </aside>
</template>
