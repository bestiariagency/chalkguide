<script setup lang="ts">
import type { GymSummary } from '~/types/domain'
import type { GymDetail } from '~/types/gym-detail'
import type { BreadcrumbItem } from '~/types/ui'

/** Gym page header: breadcrumbs, name, key data, author score + transparency, section nav. */
const props = defineProps<{ gym: GymSummary; detail?: GymDetail | null }>()
const { t, locale } = useI18n()

const crumbs = computed<BreadcrumbItem[]>(() => [
  { label: t('nav.home'), to: '/' },
  { label: t('nav.gyms'), to: { name: 'climbing-gyms' } },
  { label: props.gym.name },
])
const kicker = computed(() =>
  [gymTypeKey(props.gym) && t(gymTypeKey(props.gym) as string), props.gym.district]
    .filter(Boolean)
    .join(' · '),
)
const facts = computed(() => {
  const f = props.detail?.facilities
  const n = (value: number | null, key: string) =>
    value === null ? null : t(key, { count: value }, value)
  return [
    props.gym.priceMonthly !== null &&
      t('gyms.detail.perMonth', { price: formatEur(props.gym.priceMonthly, locale.value) }),
    f && f.maxHeightM !== null && t('gyms.detail.height', { value: f.maxHeightM }),
    n(f?.routesCount ?? null, 'gyms.detail.routes'),
    f?.autobelaysCount ? n(f.autobelaysCount, 'gyms.detail.autobelays') : null,
  ].filter((fact): fact is string => typeof fact === 'string')
})
const sections = ['review', 'data', 'facilities', 'opinions', 'partner'] as const
</script>

<template>
  <section class="border-b-[0.5px] border-line board-tex">
    <div class="mx-auto max-w-page px-4 pt-8 pb-10 md:px-6 md:pt-10 md:pb-14">
      <UiBreadcrumbs :items="crumbs" />
      <div class="mt-5 grid items-end gap-8 lg:grid-cols-12">
        <div class="lg:col-span-8">
          <p v-if="kicker" class="label-mini">{{ kicker }}</p>
          <h1 class="mt-3 text-title-1 font-medium">{{ gym.name }}</h1>
          <p v-if="gym.summary" class="mt-4 max-w-read text-body-lg text-meta">
            {{ gym.summary }}
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
          <template v-if="gym.authorScore !== null">
            <p class="text-caption text-meta">{{ t('ratings.author') }}</p>
            <p class="mt-1">
              <span class="font-mono text-[44px] leading-none text-accent">
                {{ formatScore(gym.authorScore, locale) }}
              </span>
              <span class="ml-1 text-meta">{{ t('ratings.outOf') }}</span>
            </p>
          </template>
          <p class="mt-3 flex flex-wrap gap-2 lg:justify-end">
            <UiBadge v-if="gym.visitType === 'invited'" kind="guest-visit">
              {{ t('transparency.guestVisit') }}
            </UiBadge>
            <ItemsVerified :date="detail?.prices.verifiedAt ?? gym.verifiedAt" compact />
          </p>
        </div>
      </div>
      <nav :aria-label="t('gyms.detail.onThisPage')" class="mt-8 -mx-4 overflow-x-auto px-4">
        <ul class="flex gap-6 text-body-sm whitespace-nowrap">
          <li v-for="id in sections" :key="id">
            <a
              :href="`#${id}`"
              class="inline-flex min-h-11 items-center text-meta transition-colors duration-150 hover:text-foreground focus-visible:text-foreground"
            >
              {{ t(`gyms.detail.nav.${id}`) }}
            </a>
          </li>
        </ul>
      </nav>
    </div>
  </section>
</template>
