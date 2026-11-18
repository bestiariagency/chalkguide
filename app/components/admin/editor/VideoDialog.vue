<script setup lang="ts">
import type { Editor } from '@tiptap/vue-3'
import { parseYoutubeId } from '~/utils/article-embeds'

/** Inserts a YouTube video (privacy-enhanced embed) from a pasted link. */
const props = defineProps<{ editor: Editor | null }>()
const open = defineModel<boolean>('open', { default: false })

const url = ref('')
const error = ref('')
watch(open, (value) => {
  if (!value) return
  url.value = ''
  error.value = ''
})

function apply() {
  const id = parseYoutubeId(url.value)
  if (!id) {
    error.value = 'Pega un enlace de YouTube válido, por ejemplo https://www.youtube.com/watch?v=…'
    return
  }
  props.editor?.chain().focus().insertContent({ type: 'videoEmbed', attrs: { id } }).run()
  open.value = false
}
</script>

<template>
  <AdminModal v-model:open="open" title="Vídeo de YouTube" description="Se incrusta con el modo de privacidad mejorada (youtube-nocookie.com).">
    <form id="video-form" @submit.prevent="apply">
      <AdminTextField v-model="url" label="Enlace del vídeo" type="url" inputmode="url" placeholder="https://www.youtube.com/watch?v=" :error="error" data-autofocus />
    </form>
    <template #footer>
      <button type="button" :class="admBtnGhost" @click="open = false">Cancelar</button>
      <button type="submit" form="video-form" :class="admBtnPrimary">Insertar vídeo</button>
    </template>
  </AdminModal>
</template>
