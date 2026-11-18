<script setup lang="ts">
import { confidenceSegments, confidenceWord } from '~/utils/admin-events'

/** Agent confidence: 5 segments plus the word for screen readers (or visible with `label`). */
defineProps<{ value: number; label?: boolean }>()
</script>

<template>
  <span class="inline-flex items-center gap-1.5 text-xs text-adm-meta" title="Confianza del agente">
    <span class="inline-flex gap-0.5" aria-hidden="true"><i v-for="n in 5" :key="n" :class="['h-1.5 w-2 rounded-xs', n <= confidenceSegments(value) ? 'bg-adm-fg' : 'bg-adm-line-strong']" /></span>
    <span :class="label ? '' : 'sr-only'">{{ label ? '' : 'Confianza ' }}{{ confidenceWord(value) }}</span>
  </span>
</template>
