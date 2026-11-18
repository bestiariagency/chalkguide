<script setup lang="ts">
import type { ResolerSummary } from '~/types/domain'
import type { BreadcrumbItem } from '~/types/ui'

/** Resoler page header: breadcrumbs, name, key facts, author score + transparency badges. */
const props = defineProps<{ resoler: ResolerSummary }>()
const { t, locale } = useI18n()

const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.resoling'), to: { name: 'climbing-shoe-resoling' } },
  { label: props.resoler.name },
])
const kicker = computed(() =>
  [t('resolers.detail.kicker'), props.resoler.district].filter(Boolean).join(' · '),
)
const facts = computed(() => {
  const range = turnaroundRange(props.resoler)
  const price = formatEur(props.resoler.pricePerPair, locale.value)
  return [
    price && t('resolers.detail.perPairFact', { price }),
    range && t('resolers.turnaround', { range: range.text }, range.count),
  ].filter((fact): fact is string => typeof fact === 'string')
})
</script>

<template>
  <section class="border-b-[0.5px] border-line board-tex">
    <div class="mx-auto max-w-page px-4 pt-8 pb-10 md:px-6 md:pt-10 md:pb-14">
      <UiBreadcrumbs :items="crumbs" />
      <div class="mt-5 grid items-end gap-8 lg:grid-cols-12">
        <div class="lg:col-span-8">
          <p class="label-mini">{{ kicker }}</p>
          <h1 class="mt-3 text-title-1 font-medium">{{ resoler.name }}</h1>
          <p v-if="resoler.summary" class="mt-4 max-w-read text-body-lg text-meta">
            {{ resoler.summary }}
          </p>
          <ul v-if="facts.length" class="mt-5 flex flex-wrap gap-2 tabular-nums">
            <li
              v-for="fact in facts"
              :key="fact"
              class="rounded-sm bg-elevated px-2 py-1.25 font-mono text-note leading-none"
            >
              {{ fact }}
            </li>
          </ul>
        </div>
        <div class="lg:col-span-4 lg:text-right">
          <template v-if="resoler.authorScore !== null">
            <p class="text-caption text-meta">{{ t('ratings.author') }}</p>
            <p class="mt-1">
              <span class="font-mono text-[44px] leading-none text-accent">
                {{ formatScore(resoler.authorScore, locale) }}
              </span>
              <span class="ml-1 text-meta">{{ t('ratings.outOf') }}</span>
            </p>
          </template>
          <p class="mt-3 flex flex-wrap gap-2 lg:justify-end">
            <UiBadge v-if="resoler.visitType === 'invited'" kind="guest-visit">
              {{ t('transparency.guestVisit') }}
            </UiBadge>
            <ItemsVerified :date="resoler.pricesVerifiedAt ?? resoler.verifiedAt" compact />
          </p>
        </div>
      </div>
    </div>
  </section>
</template>
