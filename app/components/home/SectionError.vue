<script setup lang="ts">
/** Error state for a home block whose data failed to load (the rest of the page still works). */
defineProps<{ onRetry?: () => void }>()
const { t } = useI18n()
</script>

<template>
  <UiEmptyState :title="t('states.errorTitle')" :body="t('states.errorBody')">
    <template v-if="onRetry" #action>
      <UiButton variant="ghost" @click="onRetry">{{ t('common.retry') }}</UiButton>
    </template>
  </UiEmptyState>
</template>
