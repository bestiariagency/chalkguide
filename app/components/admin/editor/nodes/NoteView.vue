<script setup lang="ts">
import { NodeViewContent, NodeViewWrapper, type NodeViewProps } from '@tiptap/vue-3'

/** Editor view of the author note: orange plate with the "Nota de {name}" label (name from Ajustes, not typed). */
defineProps<NodeViewProps>()
const name = useNoteAuthorName()
</script>

<template>
  <NodeViewWrapper as="aside" data-note="author" :aria-label="name ? `Nota de ${name}` : 'Nota del autor'" class="my-5 rounded-lg bg-accent-muted px-4 py-3.5" :class="selected && 'outline-2 outline-offset-2 outline-adm-acc'">
    <p class="font-hand text-[22px] leading-none font-bold text-accent select-none" contenteditable="false" aria-hidden="true">{{ name ? `Nota de ${name}` : 'Nota del autor' }}</p>
    <NodeViewContent class="mt-2 [&_p]:!my-0 [&_p+*]:!mt-2" />
  </NodeViewWrapper>
</template>
