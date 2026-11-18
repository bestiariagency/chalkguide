<script setup lang="ts">
import { NodeViewWrapper, type NodeViewProps } from '@tiptap/vue-3'
import { Footprints, Mountain, Trash2, Wrench } from 'lucide-vue-next'
import { ITEM_KIND_LABEL, itemCardHref, type ItemKind } from '~/utils/article-embeds'

/** Editor view of an item card (rocódromo, resolador, pie de gato). */
const props = defineProps<NodeViewProps>()
const ICON = { gym: Mountain, resoler: Wrench, shoe: Footprints }
const kind = computed(() => props.node.attrs.kind as ItemKind)
</script>

<template>
  <NodeViewWrapper
    as="div"
    data-drag-handle
    contenteditable="false"
    class="my-5 flex items-center gap-3 rounded-md border border-adm-line bg-adm-side p-3"
    :class="selected && 'outline-2 outline-offset-2 outline-adm-acc'"
  >
    <span class="grid size-14 flex-none place-items-center rounded bg-adm-subtle text-adm-meta"><component :is="ICON[kind]" class="size-6" aria-hidden="true" /></span>
    <div class="min-w-0 text-sm">
      <p class="text-xs font-medium text-adm-meta">Tarjeta de ficha · {{ ITEM_KIND_LABEL[kind] }}</p>
      <p class="truncate font-medium">{{ node.attrs.name || node.attrs.slug }}</p>
      <p class="truncate font-mono text-xs text-adm-meta">{{ itemCardHref(kind, node.attrs.slug, 'es') }}</p>
    </div>
    <button v-if="editor.isEditable" type="button" :class="[admIconBtn, 'ml-auto']" aria-label="Quitar la tarjeta" @click="props.deleteNode()"><Trash2 aria-hidden="true" /></button>
  </NodeViewWrapper>
</template>
