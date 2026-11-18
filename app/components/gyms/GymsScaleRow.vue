<script setup lang="ts">
/** One compact row of "Cómo se escala" in a listing card: label · ruler · word (or "Sin dato"). */
const props = defineProps<{ kind: GymScaleKind; value: number | null }>()
const { t } = useI18n()
const { word, srText } = useGymScale(props.kind, () => props.value)
</script>

<template>
  <div class="grid min-h-5 grid-cols-[2.75rem_minmax(0,1fr)] items-center gap-2.5">
    <dt class="text-micro text-meta">{{ t(`gyms.${kind}.label`) }}</dt>
    <dd v-if="word" class="flex min-w-0 items-center gap-2.5">
      <UiScale5 :value="value" />
      <span class="truncate text-note text-foreground" aria-hidden="true">{{ word }}</span>
      <span class="sr-only">{{ srText }}</span>
    </dd>
    <dd v-else class="text-note text-meta">{{ t('common.noData') }}</dd>
  </div>
</template>
