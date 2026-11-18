<script setup lang="ts">
import { TrainFront } from 'lucide-vue-next'
import type { GymSummary } from '~/types/domain'

/**
 * Listing card (README §9.9.2): cover photo with name and type/district over a black gradient, metro line, the three value data
 * (day entry, family index, variety) and, apart, the two descriptive scales (grading, style).
 * The verification date sits on the photo's top-right corner.
 * No overall score and no beginner index on the card. The whole card links through an overlay
 * on the title; the zoom on the photo only runs with a hover-capable pointer.
 */
const props = withDefaults(defineProps<{ gym: GymSummary; tokens?: string[]; showVariety?: boolean }>(), {
  tokens: () => [],
  showVariety: true,
})
const { t, locale } = useI18n()

const meta = computed(() =>
  [gymTypeKey(props.gym) && t(gymTypeKey(props.gym) as string), props.gym.district]
    .filter(Boolean)
    .join(' · '),
)
const metro = computed(() => props.gym.metroStations[0] ?? null)
const price = computed(() => formatEur(props.gym.priceDay, locale.value))
const family = computed(() => formatScore(props.gym.familyIndex, locale.value))
const valueClass = 'font-mono text-xl leading-none'
</script>

<template>
  <article class="group/card flex h-full flex-col overflow-hidden tabular-nums" :class="cardSurface">
    <div class="grid aspect-[16/9] overflow-hidden sm:aspect-[3/2]">
      <UiPhoto
        :media="gym.cover"
        sizes="100vw sm:50vw lg:33vw"
        class="col-start-1 row-start-1 size-full motion-safe:transition-transform motion-safe:duration-[600ms] motion-safe:ease-out motion-safe:[@media(hover:hover)]:group-hover/card:scale-[1.03]"
      />
      <div
        class="pointer-events-none z-10 col-start-1 row-start-1 bg-linear-to-b from-transparent from-25% via-black/70 via-60% to-black"
        aria-hidden="true"
      />
      <!-- Not positioned on purpose: the title's ::after overlay must cover the whole card. -->
      <div class="chrome-dark z-10 col-start-1 row-start-1 self-end bg-transparent p-4 pt-10 md:p-5 md:pt-12">
        <h3 class="[text-shadow:0_1px_2px_rgb(0_0_0/0.6)]">
          <NuxtLinkLocale
            :to="{ name: 'climbing-gyms-slug', params: { slug: gym.slug } }"
            :class="rowOverlayLink"
          >
            <span :class="cardTitleUnderline"><UiHighlight :text="gym.name" :tokens="tokens" /></span>
          </NuxtLinkLocale>
        </h3>
        <p class="mt-0.5 min-h-[1.45em] truncate text-caption text-meta [text-shadow:0_1px_2px_rgb(0_0_0/0.6)]">
          <UiHighlight :text="meta" :tokens="tokens" />
        </p>
      </div>
      <!-- Anchored to the card (not the photo box) so the title overlay keeps covering the card.
           One stack, so the guest-visit badge and the verification date never overlap. -->
      <div class="pointer-events-none absolute top-3 right-3 z-20 flex max-w-[calc(100%-1.5rem)] flex-col items-end gap-1.5">
        <UiBadge v-if="gym.visitType === 'invited'" kind="guest-visit">
          {{ t('transparency.guestVisit') }}
        </UiBadge>
        <div
          v-if="gym.pricesVerifiedAt ?? gym.verifiedAt"
          class="rounded-sm bg-board shadow-[0_1px_4px_rgb(0_0_0/0.4)]"
        >
          <ItemsVerified :date="gym.pricesVerifiedAt ?? gym.verifiedAt" compact />
        </div>
      </div>
    </div>
    <div class="flex flex-1 flex-col p-4 md:p-5">
      <p class="flex min-h-[1.45em] min-w-0 items-center gap-1.5 text-caption text-meta">
        <template v-if="metro">
          <TrainFront :size="14" aria-hidden="true" class="shrink-0" />
          <span class="sr-only">{{ t('gyms.card.metro') }}</span>
          <span class="truncate"><UiHighlight :text="metro" :tokens="tokens" /></span>
        </template>
      </p>

      <dl :class="['mt-4 grid gap-3 border-t-[0.5px] border-line pt-3.5', showVariety ? 'grid-cols-3' : 'grid-cols-2']">
        <div>
          <dt class="text-note whitespace-nowrap text-meta">
            {{ t('gyms.card.entry') }}<span class="sr-only"> {{ t('gyms.card.entrySr') }}</span>
          </dt>
          <dd class="mt-1 min-h-[38px]">
            <span v-if="price" :class="[valueClass, 'text-foreground']">{{ price }}</span>
            <template v-else>
              <span :class="[valueClass, 'text-meta']" aria-hidden="true">—</span>
              <span class="sr-only">{{ t('common.noData') }}</span>
            </template>
          </dd>
        </div>
        <div>
          <dt class="text-note whitespace-nowrap text-meta">{{ t('gyms.card.family') }}</dt>
          <dd class="mt-1 min-h-[38px]">
            <template v-if="family">
              <span :class="[valueClass, 'text-foreground']">{{ family }}</span>
              <span class="sr-only"> {{ t('gyms.card.outOf5') }}</span>
              <span class="mt-2 block"><UiMeter5 :value="gym.familyIndex" /></span>
            </template>
            <template v-else>
              <span :class="[valueClass, 'text-meta']" aria-hidden="true">—</span>
              <span class="sr-only">{{ t('common.noData') }}</span>
            </template>
          </dd>
        </div>
        <div v-if="showVariety">
          <dt class="text-note whitespace-nowrap text-meta">{{ t('gyms.card.variety') }}</dt>
          <dd class="mt-1 min-h-[38px]">
            <template v-if="gym.variety !== null">
              <span :class="[valueClass, 'text-foreground']">{{ gym.variety }}</span>
              <span class="sr-only"> {{ t('gyms.card.varietySr') }}</span>
              <span class="mt-2 block"><UiMeter5 :value="gym.variety" /></span>
            </template>
            <template v-else>
              <span :class="[valueClass, 'text-meta']" aria-hidden="true">—</span>
              <span class="mt-1 block text-micro text-meta">{{ t('gyms.card.noReview') }}</span>
            </template>
          </dd>
        </div>
      </dl>

      <dl
        class="mt-3 grid gap-1.5 rounded-md border-[0.5px] border-line bg-background px-3 py-2.5"
        :aria-label="t('gyms.card.scalesLabel')"
      >
        <GymsScaleRow kind="grading" :value="gym.gradingDifficulty" />
        <GymsScaleRow kind="style" :value="gym.settingDynamism" />
      </dl>

    </div>
  </article>
</template>
