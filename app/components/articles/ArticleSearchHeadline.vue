<script setup lang="ts">
/**
 * Search snippet from `guide.search_articles`: plain text with matches between U+0002 and
 * U+0003. Rendered as text nodes and <mark> only; never `v-html` (leona-lia, mandatory).
 */
const props = defineProps<{ headline: string }>()
const parts = computed(() => headlineParts(props.headline))
</script>

<template>
  <template v-for="(part, index) in parts" :key="index"
    ><mark v-if="part.hit">{{ part.text }}</mark
    ><template v-else>{{ part.text }}</template></template
  >
</template>
