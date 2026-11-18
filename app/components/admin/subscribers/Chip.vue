<script setup lang="ts">
import { Clock, Hourglass, MailX, UserX } from 'lucide-vue-next'
import type { SubscriberStatus } from '~/utils/admin-subscribers'

/**
 * Status of a subscriber as a chip (text + icon, never colour alone): Activo, Sin confirmar, Caducado, Baja and
 * Rebotado. The unsubscription is not red: it is a legitimate decision of the reader, not an error.
 */
defineProps<{ status: SubscriberStatus }>()
</script>

<template>
  <span v-if="status === 'active'" :class="[admChip, 'bg-adm-st-pub-bg text-adm-st-pub']"><span class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />Activo</span>
  <span v-else-if="status === 'pending'" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><Clock aria-hidden="true" />Sin confirmar</span>
  <span v-else-if="status === 'expired'" :class="[admChip, 'bg-transparent text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line']"><Hourglass aria-hidden="true" />Caducado</span>
  <span v-else-if="status === 'bounced'" :class="[admChip, 'bg-adm-danger-soft text-adm-danger']"><MailX aria-hidden="true" />Rebotado</span>
  <span v-else :class="[admChip, 'bg-adm-subtle text-adm-meta']"><UserX aria-hidden="true" />Baja</span>
</template>
