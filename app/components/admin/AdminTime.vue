<script setup lang="ts">
/** Panel date: relative ("hace 2 h") or short ("14 oct 2026"), always as `<time datetime>` with the full date as title. */
const props = withDefaults(defineProps<{ iso: string; short?: boolean }>(), { short: false })
const text = computed(() => (props.short ? shortDate(props.iso) : relativeUpdated(props.iso)))
const full = computed(() => adminDateTime(props.iso))
</script>

<template>
  <time :datetime="iso" :title="full" class="tabular-nums">{{ text }}</time>
</template>
