<script setup lang="ts">
import type { GymSummary } from '~/types/domain'

/**
 * "Cómo se escala aquí" (README §9.9.2.1): grading and style as neutral rulers. Data of the gym,
 * not of the review, so it shows without a review; with neither value it is not rendered.
 */
const props = defineProps<{ gym: GymSummary }>()
const { t } = useI18n()
const { linkFor } = usePageLinks()
const visible = computed(
  () => props.gym.gradingDifficulty !== null || props.gym.settingDynamism !== null,
)
</script>

<template>
  <section
    v-if="visible"
    id="scales"
    class="scroll-mt-20"
    aria-labelledby="gym-scales-title"
  >
    <div class="max-w-read rounded-lg border-[0.5px] border-line-strong bg-board p-5 md:p-6">
      <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
        <h2 id="gym-scales-title" class="label-mini !text-accent">{{ t('gyms.scales.title') }}</h2>
        <p class="text-note text-meta">{{ t('gyms.scales.notAGrade') }}</p>
      </div>
      <dl class="mt-5 grid gap-6 sm:grid-cols-2 sm:gap-8">
        <GymsScaleBlock kind="grading" :value="gym.gradingDifficulty" />
        <GymsScaleBlock kind="style" :value="gym.settingDynamism" />
      </dl>
      <p class="mt-5 border-t-[0.5px] border-line pt-4 text-caption text-meta">
        {{ t('gyms.scales.footer') }}
        <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')">{{ t('gyms.scales.link') }}</UiTextLink>
      </p>
    </div>
  </section>
</template>
