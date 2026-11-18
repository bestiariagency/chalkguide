<script setup lang="ts">
import type { Editor } from '@tiptap/vue-3'
import type { AdminMedia } from '~/utils/admin-media'
import type { DialogBlockKey } from '~/utils/article-blocks'
import { countWords, isEmptyDoc, readingMinutes } from '~/utils/article-editor'
import type { ItemForm } from '~/utils/item-fields'

/**
 * Rich text of the author review in ES and EN. Both editors stay mounted (hidden) so each keeps its
 * undo history; the toolbar follows the active one.
 */
const props = defineProps<{ changed: string[] }>()
defineEmits<{ media: [media: AdminMedia] }>()
const form = defineModel<ItemForm>('form', { required: true })
const lang = ref<'es' | 'en'>('es')
const editors = shallowRef<Record<'es' | 'en', Editor | null>>({ es: null, en: null })
const tick = ref(0)
const toolbar = ref<{ open: (key: DialogBlockKey) => void } | null>(null)
function onReady(locale: 'es' | 'en', editor: Editor | null) {
  editors.value = { ...editors.value, [locale]: editor }
  editor?.on('transaction', () => tick.value++)
}
const words = computed(() => countWords(lang.value === 'es' ? form.value.body_json_es.html : form.value.body_json_en.html))
/** English is "incomplete" once started (verdict, review or summary) without both verdict and review. */
const enIncomplete = computed(() => {
  const { headline_en, summary_en, body_json_en } = form.value
  const hasBody = !isEmptyDoc(body_json_en.json)
  return (!!headline_en.trim() || !!summary_en.trim() || hasBody) && !(headline_en.trim() && hasBody)
})
const OPTIONS = computed(() => [
  { value: 'es' as const, label: 'ES' },
  { value: 'en' as const, label: 'EN', dot: enIncomplete.value },
])
const mark = (locale: 'es' | 'en') => changedBar(props.changed.includes(`body_json_${locale}`))
</script>

<template>
  <div class="overflow-hidden rounded-lg border border-adm-line bg-adm-elev">
    <div class="flex items-center gap-2 border-b border-adm-line bg-adm-side px-2 py-1">
      <AdminSegmented v-model="lang" :options="OPTIONS" label="Idioma de la reseña" />
    </div>
    <AdminEditorToolbar ref="toolbar" :editor="editors[lang]" :tick="tick" :words="words" :minutes="readingMinutes(words)" @media="$emit('media', $event)" />
    <div class="max-h-[28rem] min-h-48 overflow-auto px-4 py-2">
      <div v-show="lang === 'es'" :class="mark('es')"><AdminEditorBody v-model="form.body_json_es" locale="es" label="Cuerpo de la reseña" @ready="onReady('es', $event)" @dialog="toolbar?.open($event)" /></div>
      <div v-show="lang === 'en'" :class="mark('en')"><AdminEditorBody v-model="form.body_json_en" locale="en" label="Cuerpo de la reseña" @ready="onReady('en', $event)" @dialog="toolbar?.open($event)" /></div>
    </div>
  </div>
</template>
