<script setup lang="ts">
import { ExternalLink } from 'lucide-vue-next'
import type { ChecklistItem } from '~/utils/article-form'

/** "Arreglar en Medios": one link per image of a checklist item (D27 alt text). */
defineProps<{ item: ChecklistItem }>()
</script>

<template>
  <ul v-if="!item.ok && item.links?.length" class="mt-1 flex flex-wrap gap-x-3 gap-y-0.5" :aria-label="`Imágenes: ${item.label}`">
    <li v-for="link in item.links" :key="link.to">
      <NuxtLink :to="link.to" target="_blank" class="inline-flex min-h-6 items-center font-medium underline underline-offset-2 max-md:min-h-11">{{ link.label }}<ExternalLink class="ml-1 size-3.5 flex-none" aria-hidden="true" /><span class="sr-only"> (abre Medios en otra pestaña)</span></NuxtLink>
    </li>
  </ul>
</template>
