<script setup lang="ts">
/** Text with the searched words wrapped in <mark>. Pure text nodes: never HTML. */
const props = defineProps<{ text: string; tokens: string[] }>()
const parts = computed(() => highlightParts(props.text, props.tokens))
</script>

<template>
  <template v-for="(part, index) in parts" :key="index"
    ><mark v-if="part.hit">{{ part.text }}</mark
    ><template v-else>{{ part.text }}</template></template
  >
</template>
