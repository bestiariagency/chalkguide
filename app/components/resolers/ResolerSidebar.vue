<script setup lang="ts">
import { ExternalLink, MapPin } from 'lucide-vue-next'
import type { ResolerSummary } from '~/types/domain'
import type { ResolerDetail } from '~/types/resoler-detail'
import type { DataRow } from '~/types/ui'

/** Sticky side column: prices and service (with verification date), contact, related articles. */
const props = defineProps<{ resoler: ResolerSummary; detail: ResolerDetail | null }>()
const { t, locale } = useI18n()

const rows = computed<DataRow[]>(() => {
  const r = props.resoler
  const range = turnaroundRange(r)
  const rand = formatEur(r.priceRand, locale.value)
  return [
    { label: t('resolers.detail.perPair'), value: formatEur(r.pricePerPair, locale.value), tone: 'accent' },
    { label: t('resolers.detail.rand'), value: rand && `+${rand}` },
    {
      label: t('resolers.detail.turnaround'),
      value: range && t('resolers.turnaround', { range: range.text }, range.count),
    },
    {
      label: t('resolers.detail.mail'),
      value: r.acceptsMail === null ? null : t(r.acceptsMail ? 'common.yes' : 'common.no'),
      tone: r.acceptsMail ? undefined : 'muted',
    },
    { label: t('resolers.detail.rubbers'), value: r.rubberBrands.join(', ') || null },
  ]
})
const place = computed(() =>
  [props.detail?.address, props.resoler.district].filter(Boolean).join(' · '),
)
</script>

<template>
  <aside class="space-y-6 lg:col-span-4">
    <div class="space-y-6 lg:sticky lg:top-20">
      <div class="rounded-lg border-[0.5px] border-line-strong bg-board p-5">
        <p class="label-mini">{{ t('resolers.detail.pricesTitle') }}</p>
        <ItemsDataList :rows="rows" class="mt-3" />
        <p v-if="resoler.acceptsMail && resoler.mailNotes" class="mt-3 text-caption text-meta">
          {{ resoler.mailNotes }}
        </p>
        <div v-if="resoler.services.length" class="mt-4">
          <p class="text-caption text-meta">{{ t('resolers.detail.services') }}</p>
          <ResolersServices :services="resoler.services" class="mt-2" />
        </div>
        <ItemsVerified :date="resoler.pricesVerifiedAt" compact class="mt-3" />
      </div>
      <div
        v-if="place || detail?.websiteUrl"
        class="rounded-lg border-[0.5px] border-line-strong bg-board p-5"
      >
        <ul class="space-y-2 text-body-sm">
          <li v-if="place" class="flex gap-2">
            <MapPin :size="16" class="mt-1 shrink-0 text-meta" aria-hidden="true" />{{ place }}
          </li>
          <li v-if="detail?.websiteUrl" class="flex gap-2">
            <ExternalLink :size="16" class="mt-1 shrink-0 text-meta" aria-hidden="true" />
            <UiTextLink :href="detail.websiteUrl" external>
              {{ t('resolers.detail.website') }}
            </UiTextLink>
          </li>
        </ul>
      </div>
      <div v-if="detail?.articles.length" class="rounded-lg border-[0.5px] border-line-strong bg-board p-5">
        <p class="label-mini">{{ t('resolers.detail.appearsIn') }}</p>
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
