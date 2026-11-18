<script setup lang="ts">
import type { ResolerSummary } from '~/types/domain'

/**
 * Resoler rows: table from lg (7 columns), "row cards" below lg. The whole row is clickable through an
 * `::after` overlay on the title link (focus ring drawn on the overlay), like the gym rows.
 */
withDefaults(defineProps<{
  resolers: ResolerSummary[]
  /** Highlighted (accent) author score. */
  bestId?: string | null
  caption: string
  /** Searched words, highlighted in name and metadata. */
  tokens?: string[]
}>(), { bestId: null, tokens: () => [] })
const { t, locale } = useI18n()

const noData = computed(() => t('common.noData'))
const meta = (r: ResolerSummary) => [r.district, r.rubberBrands.join(', ')].filter(Boolean).join(' · ')
const perPair = (r: ResolerSummary) => formatEur(r.pricePerPair, locale.value) ?? noData.value
const rand = (r: ResolerSummary) => {
  const value = formatEur(r.priceRand, locale.value)
  return value ? `+${value}` : noData.value
}
const days = (r: ResolerSummary, short = false) => {
  const range = turnaroundRange(r)
  if (!range) return noData.value
  return short
    ? t('resolers.turnaroundShort', { range: range.text })
    : t('resolers.turnaround', { range: range.text }, range.count)
}
const mailShort = (r: ResolerSummary) =>
  r.acceptsMail === null ? null : t(r.acceptsMail ? 'resolers.mail.accepts' : 'resolers.mail.declines')
const mailCell = (r: ResolerSummary) =>
  r.acceptsMail === null ? noData.value : t(r.acceptsMail ? 'common.yes' : 'common.no')
const cardMeta = (r: ResolerSummary) => [r.district, mailShort(r)].filter(Boolean).join(' · ')
</script>

<template>
  <div>
    <table class="mt-8 hidden w-full text-left tabular-nums lg:table">
      <caption class="sr-only">
        {{ caption }}
      </caption>
      <thead>
        <tr class="border-b-[0.5px] border-line-strong label-mini whitespace-nowrap">
          <th scope="col" class="py-3 pr-4 font-normal">{{ t('resolers.columns.workshop') }}</th>
          <th scope="col" class="py-3 pr-4 text-right font-normal">{{ t('resolers.columns.perPair') }}</th>
          <th scope="col" class="py-3 pr-4 text-right font-normal">{{ t('resolers.columns.rand') }}</th>
          <th scope="col" class="py-3 pr-4 text-right font-normal">{{ t('resolers.columns.turnaround') }}</th>
          <th scope="col" class="py-3 pr-4 pl-4 font-normal">{{ t('resolers.columns.services') }}</th>
          <th scope="col" class="py-3 pr-4 font-normal">{{ t('resolers.columns.mail') }}</th>
          <th scope="col" class="py-3 text-right font-normal">{{ t('ratings.author') }}</th>
        </tr>
      </thead>
      <TransitionGroup tag="tbody" move-class="transition-transform duration-300 ease-out">
        <tr
          v-for="r in resolers"
          :key="r.id"
          class="group/card relative border-b-[0.5px] border-line transition-colors duration-150 hover:bg-elevated/60"
        >
          <th scope="row" class="py-5 pr-4 font-normal">
            <NuxtLinkLocale
              :to="{ name: 'climbing-shoe-resoling-slug', params: { slug: r.slug } }"
              :class="rowOverlayLink"
            >
              <span :class="cardTitleUnderline"><UiHighlight :text="r.name" :tokens="tokens" /></span>
            </NuxtLinkLocale>
            <span class="block text-caption text-meta"><UiHighlight :text="meta(r)" :tokens="tokens" /></span>
            <ItemsRowBadges
              class="mt-1.5"
              :visit-type="r.visitType"
              :verified-at="r.pricesVerifiedAt ?? r.verifiedAt"
            />
          </th>
          <td class="whitespace-nowrap py-5 pr-4 text-right font-mono text-accent">{{ perPair(r) }}</td>
          <td class="whitespace-nowrap py-5 pr-4 text-right font-mono">{{ rand(r) }}</td>
          <td class="whitespace-nowrap py-5 pr-4 text-right font-mono">{{ days(r) }}</td>
          <td class="max-w-[26ch] py-5 pr-4 pl-4">
            <ResolersServices v-if="r.services.length" :services="r.services" />
            <span v-else class="text-caption text-meta">{{ noData }}</span>
          </td>
          <td class="max-w-[22ch] py-5 pr-4 text-caption">
            <span :class="r.acceptsMail ? '' : 'text-meta'">{{ mailCell(r) }}</span>
            <span v-if="r.acceptsMail && r.mailNotes" class="block text-meta">{{ r.mailNotes }}</span>
          </td>
          <td class="py-5 text-right">
            <ItemsScore :score="r.authorScore" :highlight="r.id === bestId" />
          </td>
        </tr>
      </TransitionGroup>
    </table>

    <TransitionGroup
      tag="ul"
      move-class="transition-transform duration-300 ease-out"
      class="mt-8 space-y-3 tabular-nums lg:hidden"
    >
      <li
        v-for="r in resolers"
        :key="r.id"
        class="relative rounded-md border-[0.5px] border-line-strong bg-board p-4"
      >
        <div class="flex items-start justify-between gap-3">
          <div>
            <NuxtLinkLocale
              :to="{ name: 'climbing-shoe-resoling-slug', params: { slug: r.slug } }"
              :class="rowOverlayLink"
            >
              <UiHighlight :text="r.name" :tokens="tokens" />
            </NuxtLinkLocale>
            <p class="text-caption text-meta"><UiHighlight :text="cardMeta(r)" :tokens="tokens" /></p>
          </div>
          <ItemsScore :score="r.authorScore" :highlight="r.id === bestId" class="shrink-0" />
        </div>
        <dl class="mt-4 grid grid-cols-3 gap-3 text-caption">
          <div>
            <dt class="text-meta">{{ t('resolers.columns.perPair') }}</dt>
            <dd class="font-mono text-body text-accent">{{ perPair(r) }}</dd>
          </div>
          <div>
            <dt class="text-meta">{{ t('resolers.columns.rand') }}</dt>
            <dd class="font-mono text-body">{{ rand(r) }}</dd>
          </div>
          <div>
            <dt class="text-meta">{{ t('resolers.columns.turnaround') }}</dt>
            <dd class="font-mono text-body">{{ days(r, true) }}</dd>
          </div>
        </dl>
        <ResolersServices :services="r.services" class="mt-3" />
        <ItemsRowBadges
          class="mt-3"
          :visit-type="r.visitType"
          :verified-at="r.pricesVerifiedAt ?? r.verifiedAt"
        />
      </li>
    </TransitionGroup>
  </div>
</template>
