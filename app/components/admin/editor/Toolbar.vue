<script setup lang="ts">
import { ToolbarButton, ToolbarRoot, ToolbarSeparator } from 'reka-ui'
import type { Editor } from '@tiptap/vue-3'
import { Bold, ImageIcon, Italic, Link2, List, ListOrdered, Mountain, Quote, Redo2, Undo2, Youtube } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import type { DialogBlockKey } from '~/utils/article-blocks'

/**
 * Format bar (roving focus: Tab enters once, arrows move). The block type (paragraph, h2/h3, quote)
 * is a dropdown, as the title is the h1. Image, video (YouTube) and item card open a picker; the `/`
 * menu of the body reaches the same pickers through `open()`.
 */
const props = defineProps<{ editor: Editor | null; tick: number; disabled?: boolean; words: number; minutes: number; textOnly?: boolean }>()
const emit = defineEmits<{ media: [media: AdminMedia] }>()

const mediaUrl = useMediaUrl()
const linkOpen = ref(false)
const imageOpen = ref(false)
const videoOpen = ref(false)
const itemOpen = ref(false)
const dialogs = { image: imageOpen, video: videoOpen, item: itemOpen }
/** Opens a picker (used by the `/` menu). */
function open(key: DialogBlockKey) {
  dialogs[key].value = true
}
defineExpose({ open })

/** Reading `tick` makes these re-evaluate after each transaction (selection moves, marks change). */
const active = (name: string, attrs?: Record<string, unknown>) => (props.tick >= 0 ? !!props.editor?.isActive(name, attrs) : false)
const can = (action: 'undo' | 'redo') => (props.tick >= 0 ? !!props.editor?.can()[action]() : false)
const run = (fn: (chain: ReturnType<Editor['chain']>) => ReturnType<Editor['chain']>) => {
  if (props.editor) fn(props.editor.chain().focus()).run()
}

const btn = `${admIconBtn} aria-pressed:bg-adm-subtle aria-pressed:text-adm-fg aria-pressed:shadow-[inset_0_0_0_1px_var(--adm-line-strong)]`
const EMBED_KEYS = ['image', 'video', 'item']
/** Text-only bodies (legal pages) drop the picker buttons and the separator left dangling. */
const items = computed(() => {
  const list = allItems.value.filter((item) => !props.textOnly || !item || !EMBED_KEYS.includes(item.key))
  while (props.textOnly && list.length && list[list.length - 1] === null) list.pop()
  return list
})
const allItems = computed(() => [
  { key: 'bold', label: 'Negrita', icon: Bold, on: active('bold'), act: () => run((c) => c.toggleBold()) },
  { key: 'italic', label: 'Cursiva', icon: Italic, on: active('italic'), act: () => run((c) => c.toggleItalic()) },
  { key: 'link', label: 'Enlace', icon: Link2, on: active('link'), act: () => (linkOpen.value = true) },
  null,
  { key: 'ul', label: 'Lista con viñetas', icon: List, on: active('bulletList'), act: () => run((c) => c.toggleBulletList()) },
  { key: 'ol', label: 'Lista numerada', icon: ListOrdered, on: active('orderedList'), act: () => run((c) => c.toggleOrderedList()) },
  { key: 'quote', label: 'Cita', icon: Quote, on: active('blockquote'), act: () => run((c) => c.toggleBlockquote()) },
  null,
  { key: 'image', label: 'Imagen de la biblioteca', icon: ImageIcon, on: false, act: () => open('image') },
  { key: 'video', label: 'Vídeo de YouTube', icon: Youtube, on: false, act: () => open('video') },
  { key: 'item', label: 'Tarjeta de ficha', icon: Mountain, on: false, act: () => open('item') },
])

function insertImage(item: AdminMedia) {
  run((c) =>
    c.insertContent({
      type: 'imageFigure',
      attrs: { src: mediaUrl(item.storage_path), alt: item.alt_es ?? '', mediaId: item.id, width: item.width, height: item.height, widthMode: 'column' },
    }),
  )
  emit('media', item)
}
</script>

<template>
  <ToolbarRoot aria-label="Formato" class="mx-auto flex h-11 max-w-[760px] items-center gap-0.5 overflow-x-auto px-2 md:px-6">
    <ToolbarButton :class="btn" aria-label="Deshacer" :disabled="disabled || !can('undo')" @click="run((c) => c.undo())"><Undo2 aria-hidden="true" /></ToolbarButton>
    <ToolbarButton :class="btn" aria-label="Rehacer" :disabled="disabled || !can('redo')" @click="run((c) => c.redo())"><Redo2 aria-hidden="true" /></ToolbarButton>
    <ToolbarSeparator class="mx-1 h-5 w-px flex-none bg-adm-line" />
    <AdminEditorBlockMenu :editor="editor" :tick="tick" :disabled="disabled" />
    <template v-for="(item, i) in items" :key="item?.key ?? `sep-${i}`">
      <ToolbarSeparator v-if="!item" class="mx-1 h-5 w-px flex-none bg-adm-line" />
      <ToolbarButton v-else :class="btn" :aria-label="item.label" :title="item.label" :aria-pressed="['image', 'video', 'item'].includes(item.key) ? undefined : item.on" :disabled="disabled" @click="item.act">
        <component :is="item.icon" aria-hidden="true" />
      </ToolbarButton>
    </template>
    <span v-if="textOnly" class="hidden flex-none pl-2 text-[11px] text-adm-muted sm:inline">Legal: sin imágenes, vídeo ni fichas</span>
    <span class="ml-auto hidden flex-none pl-2 text-xs text-adm-muted tabular-nums sm:inline">{{ words }} palabras · {{ minutes }} min</span>
  </ToolbarRoot>
  <AdminEditorTableBar v-if="!textOnly && active('table')" :editor="editor" :tick="tick" :disabled="disabled" />
  <AdminEditorLinkDialog v-model:open="linkOpen" :editor="editor" />
  <template v-if="!textOnly">
    <AdminEditorVideoDialog v-model:open="videoOpen" :editor="editor" />
    <AdminEditorItemDialog v-model:open="itemOpen" :editor="editor" />
    <AdminMediaPicker v-model:open="imageOpen" title="Elegir imagen" @select="insertImage" />
  </template>
</template>
