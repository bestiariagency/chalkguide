<script setup lang="ts">
/** Text with the match wrapped in `<mark>`. Plain text only: parts are interpolated, never rendered as HTML. */
import type { MarkedPart } from '~/utils/admin-search'
const props = defineProps<{ text: string; mark?: string }>()
const parts = computed<MarkedPart[]>(() => (props.mark ? markParts(props.text, props.mark) : [{ text: props.text, mark: false }]))
</script>

<template>
  <span><template v-for="(part, i) in parts" :key="i"><mark v-if="part.mark" class="rounded-[2px] bg-adm-acc-soft text-inherit underline decoration-adm-acc decoration-1 underline-offset-2">{{ part.text }}</mark><template v-else>{{ part.text }}</template></template></span>
</template>
