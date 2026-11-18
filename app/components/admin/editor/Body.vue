<script setup lang="ts">
import { EditorContent, type Editor } from '@tiptap/vue-3'
import type { ArticleBody } from '~/utils/article-editor'
import { EMBED_BLOCKS } from '~/utils/article-blocks'
import { ProvisionalMarks } from '~/utils/page-provisional'
import type { DialogBlockKey } from '~/utils/article-blocks'

/**
 * Tiptap body of one language. The toolbar lives in the canvas and receives this editor; the `/`
 * menu lives here and asks the toolbar (via `dialog`) for the pickers it owns.
 */
const props = defineProps<{
  locale: 'es' | 'en'
  readonly?: boolean
  label?: string
  /** Legal pages: no image, video or item card (neither in the `/` menu nor pasted). */
  textOnly?: boolean
  /** Pages: highlight provisional marks (`[XAVI: …]`, "Texto provisional"). */
  marks?: boolean
}>()
const emit = defineEmits<{ ready: [editor: Editor | null]; dialog: [key: DialogBlockKey] }>()
const body = defineModel<ArticleBody>({ required: true })

const { editor, tick, replace } = useBodyEditor({
  body: () => body.value,
  locale: props.locale,
  placeholder: props.locale === 'es' ? 'Escribe o pulsa / para insertar…' : 'Write, or press / to insert…',
  editable: () => !props.readonly,
  textOnly: props.textOnly,
  extra: props.marks ? [ProvisionalMarks] : undefined,
  label: `${props.label ?? 'Cuerpo del artículo'} (${props.locale.toUpperCase()})`,
  onChange: (next) => (body.value = next),
})
const slash = useSlashMenu({ editor, tick, onDialog: (key) => emit('dialog', key), exclude: props.textOnly ? EMBED_BLOCKS : undefined })
watch(editor, (value) => emit('ready', value))
defineExpose({ replace })
</script>

<template>
  <EditorContent v-if="editor" :editor="editor" />
  <div v-else class="min-h-64" aria-hidden="true" />
  <AdminEditorSlashMenu
    :open="slash.open.value"
    :listbox-id="slash.listboxId"
    :option-id="slash.optionId"
    :blocks="slash.blocks.value"
    :active="slash.active.value"
    :position="slash.position.value"
    @choose="slash.choose"
    @hover="slash.active.value = $event"
  />
</template>
