<script setup lang="ts">
import { ExternalLink } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/** One value of the comparison (a model × an attribute), shared by the table and the attribute view. */
const props = defineProps<{ shoe: ShoeSummary; field: CompareField }>()
const { t, locale } = useI18n()

const noData = computed(() => t('common.noData'))
const labelled = (prefix: string, value: string | null) =>
  value ? t(`${prefix}.${value}`) : noData.value
const list = (prefix: string, values: string[]) =>
  values.length ? values.map((v) => t(`${prefix}.${v}`)).join(', ') : noData.value
const criteria = computed(() =>
  props.shoe.criteria.map((c) => `${c.name.toLowerCase()} ${c.score}`).join(' · '),
)
</script>

<template>
  <span v-if="field === 'price'" class="font-mono" :class="shoe.priceMin !== null ? 'text-accent' : 'text-meta'">
    {{ formatEurRange(shoe.priceMin, shoe.priceMax, locale) ?? t('common.priceUnavailable') }}
  </span>
  <template v-else-if="field === 'profile'">{{ labelled('shoes.profile', shoe.profile) }}</template>
  <template v-else-if="field === 'asymmetry'">{{ labelled('shoes.asymmetry', shoe.asymmetry) }}</template>
  <template v-else-if="field === 'closure'">{{ labelled('shoes.closure', shoe.closure) }}</template>
  <template v-else-if="field === 'rubber'">
    {{ shoe.rubber ?? noData }}
    <span v-if="shoe.rubberThicknessMm !== null" class="block font-mono text-note text-meta">
      {{ t('shoes.compare.thickness', { mm: formatScore(shoe.rubberThicknessMm, locale) }) }}
    </span>
  </template>
  <span v-else-if="field === 'stiffness'">
    <span v-if="shoe.stiffness !== null" class="flex flex-wrap items-center gap-x-2 gap-y-1">
      <UiIndexBar :value="shoe.stiffness" :label="t('ratings.outOfValue', { value: shoe.stiffness })" class="w-14" />
      <span class="font-mono text-caption">{{ shoe.stiffness }}/5</span>
    </span>
    <span v-else class="text-meta">{{ noData }}</span>
  </span>
  <template v-else-if="field === 'use'">{{ list('shoes.use', shoe.recommendedUse) }}</template>
  <template v-else-if="field === 'level'">{{ list('shoes.level', shoe.levels) }}</template>
  <template v-else-if="field === 'author'">
    <template v-if="shoe.authorScore !== null">
      <ItemsScore :score="shoe.authorScore" highlight />
      <!-- The per-criterion breakdown does not fit narrow columns: below md only the score stays. -->
      <span v-if="criteria" class="mt-1 hidden text-note text-meta md:block">{{ criteria }}</span>
    </template>
    <span v-else class="text-meta">{{ t('shoes.compare.notUsed') }}</span>
  </template>
  <template v-else-if="field === 'size'">
    <template v-if="shoe.authorSizeEu !== null">
      <span class="font-mono text-data">{{ formatSize(shoe.authorSizeEu, locale) }}</span>
      <span v-if="shoe.authorStreetSizeEu !== null" class="block text-note text-meta">
        {{ t('shoes.compare.streetSize', { size: formatSize(shoe.authorStreetSizeEu, locale) }) }}
      </span>
    </template>
    <span v-else class="text-meta"><span aria-hidden="true">—</span><span class="sr-only">{{ noData }}</span></span>
  </template>
  <p v-else-if="field === 'learned'" class="text-prose">
    <template v-if="shoe.authorHeadline"><span class="block border-l-2 border-accent pl-3">{{ shoe.authorHeadline }}</span></template>
    <span v-else class="text-meta"><span aria-hidden="true">—</span><span class="sr-only">{{ noData }}</span></span>
  </p>
  <template v-else>
    <template v-if="shoe.isAffiliate && isHttpUrl(shoe.affiliateUrl)">
      <UiButton
        variant="ghost"
        :href="shoe.affiliateUrl"
        :icon="ExternalLink"
        target="_blank"
        rel="sponsored nofollow noopener"
      >
        {{ t('shoes.compare.seePrice') }}
      </UiButton>
      <UiBadge kind="affiliate" class="mt-2 flex w-fit">{{ t('transparency.affiliate') }}</UiBadge>
    </template>
    <span v-else class="text-caption text-meta">{{ t('shoes.compare.noAffiliate') }}</span>
  </template>
</template>
