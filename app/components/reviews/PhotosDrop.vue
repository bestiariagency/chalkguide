<script setup lang="ts">
/** Renderless: listens to files dragged over the page only while it is mounted (dialog open). */
const emit = defineEmits<{ files: [files: File[]]; over: [over: boolean] }>()
const { over } = useFileDrop((files) => emit('files', files))
watch(over, (value) => emit('over', value))
onBeforeUnmount(() => emit('over', false))
</script>

<template>
  <span hidden />
</template>
