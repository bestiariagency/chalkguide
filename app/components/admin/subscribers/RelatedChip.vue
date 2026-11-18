<script setup lang="ts">
import { Clock, MegaphoneOff } from 'lucide-vue-next'
import type { RelatedStatus } from '~/utils/admin-subscribers-related'

/** D66: state of the related-products consent (text + icon, never colour alone). `none` is a muted dash read as «Sin dar». */
defineProps<{ status: RelatedStatus }>()
</script>

<template>
  <span v-if="status === 'granted'" :class="[admChip, 'bg-adm-st-pub-bg text-adm-st-pub']"><span class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />Dado</span>
  <span v-else-if="status === 'pending'" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><Clock aria-hidden="true" />Pendiente</span>
  <span v-else-if="status === 'withdrawn'" :class="[admChip, 'bg-adm-subtle text-adm-meta']"><MegaphoneOff aria-hidden="true" />Retirado</span>
  <span v-else class="text-adm-muted" role="img" aria-label="Sin dar">—</span>
</template>
