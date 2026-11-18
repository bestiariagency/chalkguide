<script setup lang="ts">
import { Ban, CircleDashed, History, X } from 'lucide-vue-next'
import { chipState, type AdminEvent } from '~/utils/admin-events'

/**
 * Status of an event as a chip (text + icon, never colour alone): Por aprobar, En la agenda, Pasado,
 * Cancelado (stays on the site, marked) and Descartado. Origin is a separate chip (`AdminEventsOrigin`).
 */
const props = defineProps<{ event: Pick<AdminEvent, 'status' | 'isPast'> }>()
const state = computed(() => chipState(props.event))
</script>

<template>
  <span v-if="state === 'draft'" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><CircleDashed aria-hidden="true" />Por aprobar</span>
  <span v-else-if="state === 'live'" :class="[admChip, 'bg-adm-st-pub-bg text-adm-st-pub']"><span class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />En la agenda</span>
  <span v-else-if="state === 'past'" :class="[admChip, 'bg-adm-subtle text-adm-meta']"><History aria-hidden="true" />Pasado</span>
  <span v-else-if="state === 'cancelled'" :class="[admChip, 'bg-adm-subtle text-adm-meta']"><Ban aria-hidden="true" />Cancelado</span>
  <span v-else :class="[admChip, 'bg-transparent text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line']"><X aria-hidden="true" />Descartado</span>
</template>
