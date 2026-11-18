<script setup lang="ts">
import { CircleDashed, X } from 'lucide-vue-next'
import type { NewsStatus } from '~/utils/admin-news'

/** Status of a news item as a chip (text + icon, never colour alone): Por revisar, Publicada and Rechazada. The origin is a separate chip. */
defineProps<{ status: NewsStatus }>()
</script>

<template>
  <span v-if="status === 'draft'" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><CircleDashed aria-hidden="true" />Por revisar</span>
  <span v-else-if="status === 'published'" :class="[admChip, 'bg-adm-st-pub-bg text-adm-st-pub']"><span class="size-1.5 flex-none rounded-full bg-current" aria-hidden="true" />Publicada</span>
  <span v-else :class="[admChip, 'bg-transparent text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line']"><X aria-hidden="true" />Rechazada</span>
</template>
