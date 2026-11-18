<script setup lang="ts">
import { CalendarX, Copy, Gauge } from 'lucide-vue-next'
import { LOW_CONFIDENCE, type AdminEvent } from '~/utils/admin-events'

/** Warnings of a draft: already past (danger), possible duplicate and low confidence (warn). */
const props = defineProps<{ event: AdminEvent }>()
const lowConfidence = computed(() => props.event.source === 'agent' && props.event.status === 'draft' && !!props.event.agent && props.event.agent.confidence < LOW_CONFIDENCE)
</script>

<template>
  <span v-if="event.status === 'draft' && event.isPast" :class="[admChip, 'bg-adm-danger-soft text-adm-danger']"><CalendarX aria-hidden="true" />Ya ha pasado</span>
  <span v-if="event.duplicate && event.status === 'draft'" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><Copy aria-hidden="true" />Posible duplicado</span>
  <span v-if="lowConfidence" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><Gauge aria-hidden="true" />Confianza baja</span>
</template>
