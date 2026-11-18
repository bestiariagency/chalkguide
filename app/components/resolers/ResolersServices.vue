<script setup lang="ts">
import type { ResolerService } from '~/types/domain'

/** Service chips of a workshop (half sole, rand, ...). Renders nothing without services. */
defineProps<{ services: ResolerService[] }>()
const { t } = useI18n()
</script>

<template>
  <ul v-if="services.length" class="flex flex-wrap gap-1.5">
    <li
      v-for="service in services"
      :key="service"
      class="rounded-sm bg-elevated px-2 py-1 text-note leading-none text-prose"
    >
      {{ t(`resolers.services.${service}`) }}
    </li>
  </ul>
</template>
