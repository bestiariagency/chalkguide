<script setup lang="ts">
import { ArrowDown } from 'lucide-vue-next'
import type { GymSummary } from '~/types/domain'

/**
 * Gym rows of the home table: table from md, "row cards" below md (design
 * system), each with the cover thumbnail next to the name. On md+ the order lives in the column
 * headers (buttons + `aria-sort`); below md the parent shows a segmented control. The whole row is clickable through an `::after` overlay on the title link, and the
 * focus ring is drawn on that overlay.
 */
const props = withDefaults(defineProps<{
  gyms: GymSummary[]
  /** Highlighted (accent) author score. */
  bestId?: string | null
  sortKey?: GymSortKey
  caption: string
  /** Searched words, highlighted in name and metadata. */
  tokens?: string[]
}>(), { bestId: null, sortKey: undefined, tokens: () => [] })
const emit = defineEmits<{ sort: [key: GymSortKey] }>()
const { t, locale } = useI18n()

const columns = computed<{ key: GymSortKey; label: string; class: string }[]>(() => [
  { key: 'price', label: t('gyms.columns.monthly'), class: 'w-[14%] pr-6 text-right' },
  { key: 'beginner', label: t('gyms.columns.beginnerIndex'), class: 'w-[26%] pr-6' },
  { key: 'score', label: t('ratings.author'), class: 'w-[16%] text-right' },
])
const meta = (gym: GymSummary) =>
  [gymTypeKey(gym) && t(gymTypeKey(gym) as string), gym.district, gym.metroStations[0]]
    .filter(Boolean).join(' · ')
const ariaSort = (key: GymSortKey) =>
  props.sortKey === key ? (key === 'price' ? 'ascending' : 'descending') : undefined
const price = (gym: GymSummary) => formatEur(gym.priceMonthly, locale.value) ?? t('common.noData')
const score = (gym: GymSummary) => formatScore(gym.beginnerIndex, locale.value) ?? t('common.noData')
</script>

<template>
  <div>
    <div class="mt-12 hidden slab bg-board px-6 md:block lg:px-8">
      <table class="w-full text-left tabular-nums">
        <caption class="sr-only">
          {{
            caption
          }}
        </caption>
        <thead>
          <tr class="border-b border-line-strong">
            <th scope="col" class="py-1 pr-4 text-note font-medium text-meta">{{ t('gyms.columns.gym') }}</th>
            <th
              v-for="col in columns"
              :key="col.key"
              scope="col"
              :aria-sort="ariaSort(col.key)"
              class="py-1 text-note font-medium"
              :class="col.class"
            >
              <button
                type="button"
                class="inline-flex min-h-11 items-center gap-1.5 transition-colors duration-150 hover:text-foreground"
                :class="sortKey === col.key ? 'text-foreground' : 'text-meta'"
                @click="emit('sort', col.key)"
              >
                {{ col.label }}
                <ArrowDown
                  :size="14"
                  aria-hidden="true"
                  :class="sortKey === col.key ? 'opacity-100' : 'opacity-45'"
                />
              </button>
            </th>
          </tr>
        </thead>
        <TransitionGroup tag="tbody" move-class="transition-transform duration-300 ease-out">
          <tr
            v-for="gym in gyms"
            :key="gym.id"
            class="group/card relative border-b border-line transition-colors duration-150 last:border-b-0 hover:bg-elevated/45"
          >
            <th scope="row" class="py-5 pr-4 font-normal">
              <div class="flex items-center gap-5">
                <GymsThumb :media="gym.cover" />
                <div class="min-w-0">
                  <NuxtLinkLocale
                    :to="{ name: 'climbing-gyms-slug', params: { slug: gym.slug } }"
                    :class="rowOverlayLink"
                  >
                    <span :class="cardTitleUnderline"><UiHighlight :text="gym.name" :tokens="tokens" /></span>
                  </NuxtLinkLocale>
                  <span class="mt-1 block text-caption text-meta"><UiHighlight :text="meta(gym)" :tokens="tokens" /></span>
                  <ItemsRowBadges
                    class="mt-1.5"
                    :visit-type="gym.visitType"
                    :verified-at="gym.pricesVerifiedAt ?? gym.verifiedAt"
                    :show-verified="false"
                  />
                </div>
              </div>
            </th>
            <td class="py-5 pr-6 text-right font-mono text-[18px] whitespace-nowrap">{{ price(gym) }}</td>
            <td class="py-5 pr-6">
              <span class="flex items-center gap-3">
                <UiIndexBar :value="gym.beginnerIndex" class="w-28 lg:w-32" />
                <span class="font-mono text-[18px]">{{ score(gym) }}</span>
              </span>
            </td>
            <td class="py-5 text-right whitespace-nowrap">
              <ItemsScore :score="gym.authorScore" :highlight="gym.id === bestId" large />
            </td>
          </tr>
        </TransitionGroup>
      </table>
    </div>

    <TransitionGroup
      tag="ul"
      move-class="transition-transform duration-300 ease-out"
      class="mt-6 space-y-4 tabular-nums md:hidden"
    >
      <li v-for="gym in gyms" :key="gym.id" class="slab relative bg-board p-4">
        <div class="flex items-start gap-3">
          <GymsThumb :media="gym.cover" />
          <div class="min-w-0 flex-1">
            <NuxtLinkLocale
              :to="{ name: 'climbing-gyms-slug', params: { slug: gym.slug } }"
              :class="rowOverlayLink"
            >
              <UiHighlight :text="gym.name" :tokens="tokens" />
            </NuxtLinkLocale>
            <p class="mt-1 text-caption leading-snug text-meta"><UiHighlight :text="meta(gym)" :tokens="tokens" /></p>
          </div>
          <ItemsScore :score="gym.authorScore" :highlight="gym.id === bestId" large />
        </div>
        <dl class="mt-4 grid grid-cols-2 gap-4 text-caption">
          <div>
            <dt class="text-meta">{{ t('gyms.columns.monthly') }}</dt>
            <dd class="mt-0.5 font-mono text-body">{{ price(gym) }}</dd>
          </div>
          <div>
            <dt class="text-meta">{{ t('gyms.sort.beginner') }}</dt>
            <dd class="mt-0.5 font-mono text-body">{{ score(gym) }}</dd>
            <dd class="mt-1.5"><UiIndexBar :value="gym.beginnerIndex" /></dd>
          </div>
        </dl>
        <ItemsRowBadges
          class="mt-3"
          :visit-type="gym.visitType"
          :verified-at="gym.pricesVerifiedAt ?? gym.verifiedAt"
          :show-verified="false"
        />
      </li>
    </TransitionGroup>
  </div>
</template>
