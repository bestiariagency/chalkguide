<script setup lang="ts">
/** One scale of "Cómo se escala aquí": label · word, full-width ruler, labelled ends. */
const props = defineProps<{ kind: GymScaleKind; value: number | null }>()
const { t } = useI18n()
const { word, srText } = useGymScale(props.kind, () => props.value)
</script>

<template>
  <div>
    <dt class="sr-only">{{ t(`gyms.${kind}.label`) }}</dt>
    <div class="flex items-baseline justify-between gap-3" aria-hidden="true">
      <span class="text-caption text-meta">{{ t(`gyms.${kind}.label`) }}</span>
      <span class="text-[17px] font-medium" :class="!word && 'text-meta'">{{ word ?? t('common.noData') }}</span>
    </div>
    <dd class="mt-3">
      <UiScale5 v-if="word" :value="value" size="lg" surface="board" />
      <span v-if="srText" class="sr-only">{{ srText }}</span>
      <span v-else class="sr-only">{{ t('common.noData') }}</span>
      <span v-if="word" class="mt-1.5 flex justify-between text-micro text-meta" aria-hidden="true">
        <span>{{ t(`gyms.${kind}.low`) }}</span>
        <span>{{ t(`gyms.${kind}.high`) }}</span>
      </span>
    </dd>
  </div>
</template>
