<script setup lang="ts">
import type { Editor } from '@tiptap/vue-3'
import { normalizeLinkUrl } from '~/utils/article-editor'

/** URL of a link (http, https or mailto only; the sanitizer enforces it again on save). */
const props = defineProps<{ editor: Editor | null }>()
const open = defineModel<boolean>('open', { default: false })

const url = ref('')
const error = ref('')
watch(open, (value) => {
  if (!value) return
  url.value = (props.editor?.getAttributes('link').href as string | undefined) ?? ''
  error.value = ''
})

function apply() {
  const href = normalizeLinkUrl(url.value)
  if (!href) {
    error.value = 'Escribe una dirección válida: https://… o mailto:…'
    return
  }
  const chain = props.editor?.chain().focus()
  if (props.editor?.state.selection.empty && !props.editor.isActive('link')) {
    chain?.insertContent({ type: 'text', text: href, marks: [{ type: 'link', attrs: { href } }] }).run()
  } else {
    chain?.extendMarkRange('link').setLink({ href }).run()
  }
  open.value = false
}
function remove() {
  props.editor?.chain().focus().extendMarkRange('link').unsetLink().run()
  open.value = false
}
</script>

<template>
  <AdminModal v-model:open="open" title="Enlace" description="Selecciona antes el texto al que quieres enlazar; sin selección se inserta la dirección como texto.">
    <form id="link-form" @submit.prevent="apply">
      <AdminTextField v-model="url" label="Dirección (URL)" type="url" inputmode="url" placeholder="https://" :error="error" data-autofocus />
    </form>
    <template #footer>
      <button v-if="editor?.isActive('link')" type="button" :class="[admBtnQuiet, 'mr-auto']" @click="remove">Quitar enlace</button>
      <button type="button" :class="admBtnGhost" @click="open = false">Cancelar</button>
      <button type="submit" form="link-form" :class="admBtnPrimary">Aplicar</button>
    </template>
  </AdminModal>
</template>
