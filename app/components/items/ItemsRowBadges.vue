<script setup lang="ts">
/** Guest-visit badge + compact verification date shown under a listing row (gym / resoler). */
withDefaults(
  defineProps<{
    visitType: string | null
    /** Verification date (null renders no badge). */
    verifiedAt: string | null
    showVerified?: boolean
  }>(),
  { showVerified: true },
)
const { t } = useI18n()
</script>

<template>
  <div class="flex flex-wrap gap-1.5">
    <UiBadge v-if="visitType === 'invited'" kind="guest-visit">
      {{ t('transparency.guestVisit') }}
    </UiBadge>
    <ItemsVerified v-if="showVerified" :date="verifiedAt" compact />
  </div>
</template>
