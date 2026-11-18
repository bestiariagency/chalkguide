<script setup lang="ts">
import { Sparkles, UserPen } from 'lucide-vue-next'
import type { EventSource } from '~/utils/admin-events'

/** Origin chip, separate from the status: `sparkles` is reserved for "comes from the agent". */
defineProps<{ source: EventSource; short?: boolean }>()
</script>

<template>
  <span v-if="source === 'agent'" :class="[admChip, 'bg-adm-subtle text-adm-meta']" title="Propuesto por el agente de novedades"><Sparkles aria-hidden="true" />{{ short ? 'Agente' : 'Propuesto por el agente' }}</span>
  <span v-else :class="[admChip, 'bg-adm-subtle text-adm-meta']"><UserPen aria-hidden="true" />Manual</span>
</template>
