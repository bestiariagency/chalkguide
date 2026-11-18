<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import { warningText, type AdminNews } from '~/utils/admin-news'

/** Warnings of a draft (confianza baja, parecido alto, posible duplicado): amber chips with `triangle-alert`. */
defineProps<{ news: Pick<AdminNews, 'warnings' | 'agent' | 'similarity'> }>()
</script>

<template>
  <span v-for="w in news.warnings" :key="w" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><TriangleAlert aria-hidden="true" />{{ warningText(w, news) }}</span>
</template>
