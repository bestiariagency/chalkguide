<script setup lang="ts">
import { CircleAlert, File, FilePenLine, Lock, Scale, CalendarCheck } from 'lucide-vue-next'
import type { Editor } from '@tiptap/vue-3'
import type { AdminMedia } from '~/utils/admin-media'
import type { PageDef } from '~/utils/admin-pages'
import { countWords, readingMinutes } from '~/utils/article-editor'
import type { DialogBlockKey } from '~/utils/article-blocks'
import type { ArticleErrors, FormLocale } from '~/utils/article-form'
import type { PageForm } from '~/utils/page-form'

/**
 * The "sheet" of a page: kicker, title, fixed URL (read only), the "Última actualización" the reader
 * sees (legal pages) and the body of the active language. Both bodies stay mounted (hidden) so each
 * keeps its own undo history; the toolbar follows the active one. No cover, lead or slug (D34).
 */
const props = defineProps<{
  def: PageDef
  lang: FormLocale
  readonly: boolean
  errors: ArticleErrors
  /** Group keys with unpublished changes (D23), for the violet bars. */
  changed?: string[]
  /** What readers see as "Última actualización" (legal pages) and, if it will move, why. */
  revised?: { text: string; note: string } | null
}>()
const emit = defineEmits<{ media: [media: AdminMedia] }>()
const form = defineModel<PageForm>('form', { required: true })

const fields = computed(() => form.value[props.lang])
const bodies = ref<Partial<Record<FormLocale, { replace: (b: PageForm['es']['body']) => void }>>>({})
const editors = shallowRef<Record<FormLocale, Editor | null>>({ es: null, en: null })
const tick = ref(0)
const toolbar = ref<{ open: (key: DialogBlockKey) => void } | null>(null)
function onReady(locale: FormLocale, editor: Editor | null) {
  editors.value = { ...editors.value, [locale]: editor }
  editor?.on('transaction', () => tick.value++)
}

const words = computed(() => countWords(fields.value.body.html))
const emptyEn = computed(() => props.lang === 'en' && !fields.value.title && !words.value)
const emptyEs = computed(() => props.lang === 'es' && !words.value)
const has = (key: string) => props.changed?.includes(key) ?? false
const url = computed(() => (props.lang === 'es' ? props.def.routeEs : props.def.routeEn))
const titleId = useId()
</script>

<template>
  <div class="min-w-0 flex-1">
    <div class="sticky top-[104px] z-20 border-b border-adm-line bg-adm-bg/95 backdrop-blur md:top-12">
      <AdminEditorToolbar ref="toolbar" :editor="editors[lang]" :tick="tick" :disabled="readonly" :text-only="def.legal" :words="words" :minutes="readingMinutes(words)" @media="emit('media', $event)" />
    </div>

    <article class="mx-auto max-w-[760px] px-5 pt-8 pb-32 md:px-8">
      <p class="flex items-center gap-1.5 text-xs font-medium text-adm-meta">
        <Scale v-if="def.legal" class="size-3.5" aria-hidden="true" /><File v-else class="size-3.5" aria-hidden="true" />{{ def.legal ? 'Página legal' : 'Página · Sobre ChalkGuide' }}
      </p>

      <p v-if="emptyEn" class="mt-4 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px]" role="status">
        Esta página todavía no tiene versión en inglés. Déjala vacía o escríbela completa (título y cuerpo).
        <button v-if="!readonly" type="button" class="ml-1 font-medium underline underline-offset-2 max-md:min-h-11" @click="bodies.en?.replace(form.es.body)">Copiar el texto en español para traducir</button>
      </p>

      <label :for="titleId" class="sr-only">Título ({{ lang.toUpperCase() }})</label>
      <div :class="['mt-1', changedBar(has(`${lang}.title`))]">
        <span v-if="has(`${lang}.title`)" class="sr-only">Título cambiado</span>
        <textarea
          :id="titleId"
          v-model="fields.title"
          data-page-field="title"
          rows="1"
          :readonly="readonly"
          :placeholder="lang === 'es' ? 'Título de la página' : 'Page title'"
          :aria-invalid="!!errors[`${lang}.title`] || undefined"
          :aria-describedby="errors[`${lang}.title`] ? `${titleId}-e` : undefined"
          class="block w-full resize-none bg-transparent text-[28px] leading-[1.15] font-semibold tracking-tight [field-sizing:content] placeholder:text-adm-muted focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-adm-acc md:text-[34px]"
        />
        <p v-if="errors[`${lang}.title`]" :id="`${titleId}-e`" class="mt-1 flex items-center gap-1.5 text-xs text-adm-danger" role="alert"><CircleAlert class="size-3.5 flex-none" aria-hidden="true" />{{ errors[`${lang}.title`] }}</p>
      </div>

      <p class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-adm-meta">
        <span class="font-mono text-xs break-all text-adm-fg">{{ url }}</span>
        <span class="inline-flex items-center gap-1 text-xs"><Lock class="size-3" aria-hidden="true" />ruta fija del sitio</span>
      </p>
      <p v-if="def.legal && revised" class="mt-1 flex items-start gap-1.5 text-sm text-adm-meta">
        <CalendarCheck class="mt-0.5 size-3.5 flex-none" aria-hidden="true" />
        <span>Así sale en la página: «Última actualización: {{ revised.text }}»<span v-if="revised.note" class="text-xs"> · {{ revised.note }}</span></span>
      </p>
      <hr class="my-6 border-adm-line" />

      <div v-if="emptyEs" class="mb-4 rounded-lg border border-dashed border-adm-line-strong p-6 text-center">
        <span class="mx-auto grid size-10 place-items-center rounded-[10px] bg-adm-subtle text-adm-meta"><FilePenLine class="size-5" aria-hidden="true" /></span>
        <h3 class="mt-3 text-sm font-semibold">Esta página está vacía</h3>
        <p class="mx-auto mt-1 max-w-sm text-sm text-adm-meta">Escribe aquí o pega el texto si ya lo tienes. Pulsa <kbd :class="admKbd">/</kbd> para insertar bloques. No se puede publicar sin cuerpo.</p>
      </div>

      <div v-show="lang === 'es'" data-page-field="body" :class="changedBar(has('es.body') && lang === 'es')">
        <AdminEditorBody :ref="(el) => (bodies.es = el as never)" v-model="form.es.body" locale="es" label="Cuerpo de la página" marks :text-only="def.legal" :readonly="readonly" @ready="onReady('es', $event)" @dialog="toolbar?.open($event)" />
      </div>
      <div v-show="lang === 'en'" data-page-field="body" :class="changedBar(has('en.body') && lang === 'en')">
        <AdminEditorBody :ref="(el) => (bodies.en = el as never)" v-model="form.en.body" locale="en" label="Cuerpo de la página" marks :text-only="def.legal" :readonly="readonly" @ready="onReady('en', $event)" @dialog="toolbar?.open($event)" />
      </div>
    </article>
  </div>
</template>
