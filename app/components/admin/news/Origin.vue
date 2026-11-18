<script setup lang="ts">
import { Sparkles, UserPen } from 'lucide-vue-next'
import type { NewsOrigin } from '~/utils/admin-news'

/** Origin chip, separate from the status: `sparkles` is reserved for «viene del agente». */
defineProps<{ source: NewsOrigin; short?: boolean }>()
</script>

<template>
  <span v-if="source === 'agent'" :class="[admChip, 'bg-adm-subtle text-adm-meta']" title="Propuesta por el agente de novedades"><Sparkles aria-hidden="true" />{{ short ? 'Agente' : 'Propuesta por el agente' }}</span>
  <span v-else :class="[admChip, 'bg-adm-subtle text-adm-meta']"><UserPen aria-hidden="true" />Manual</span>
</template>
