<script setup lang="ts">
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/vue-3'
import { Trash2, Youtube } from 'lucide-vue-next'

/** Editor view of a video embed: a labelled block (the video itself shows on the site). */
const props = defineProps<NodeViewProps>()
</script>

<template>
  <NodeViewWrapper
    as="figure"
    data-drag-handle
    contenteditable="false"
    class="my-5 flex items-center gap-3 rounded-md border border-adm-line bg-adm-side p-3"
    :class="selected && 'outline-2 outline-offset-2 outline-adm-acc'"
  >
    <span class="grid size-14 flex-none place-items-center rounded bg-adm-subtle text-adm-meta"><Youtube class="size-6" aria-hidden="true" /></span>
    <figcaption class="min-w-0 text-sm">
      <span class="block text-xs font-medium text-adm-meta">Vídeo de YouTube</span>
      <a class="block truncate font-mono text-xs underline underline-offset-2" :href="`https://www.youtube.com/watch?v=${node.attrs.id}`" target="_blank" rel="noopener">youtube.com/watch?v={{ node.attrs.id }}<span class="sr-only"> (se abre en otra pestaña)</span></a>
    </figcaption>
    <button v-if="editor.isEditable" type="button" :class="[admIconBtn, 'ml-auto']" aria-label="Quitar el vídeo" @click="props.deleteNode()"><Trash2 aria-hidden="true" /></button>
  </NodeViewWrapper>
</template>
