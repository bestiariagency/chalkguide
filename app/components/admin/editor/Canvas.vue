<script setup lang="ts">
import { CircleAlert } from 'lucide-vue-next'
import type { Editor } from '@tiptap/vue-3'
import type { AdminMedia } from '~/utils/admin-media'
import type { DialogBlockKey } from '~/utils/article-blocks'
import { countWords, readingMinutes } from '~/utils/article-editor'
import { EXCERPT_MAX, type ArticleErrors, type ArticleForm, type FormLocale } from '~/utils/article-form'

/**
 * The "sheet": cover, category, title, URL, lead and body of the active language. Both bodies stay
 * mounted (hidden) so each keeps its own undo history; the toolbar follows the active one.
 */
const props = defineProps<{
  lang: FormLocale
  readonly: boolean
  cover: AdminMedia | null
  categoryName: string
  /** `#rrggbb` of the category, if known. */
  categoryColor?: string | null
  errors: ArticleErrors
  slugTaken: Record<FormLocale, boolean>
  slugSuggestion: Record<FormLocale, string>
  /** Published article: the URL is fixed until the author confirms changing it. */
  live?: boolean
  /** Published slug per language; empty = that language was never published (the URL stays free). */
  publishedSlug?: Record<FormLocale, string>
  /** Group keys with unpublished changes (D23), for the violet bars. */
  changed?: string[]
}>()
const emit = defineEmits<{ cover: []; 'remove-cover': []; media: [media: AdminMedia] }>()
const form = defineModel<ArticleForm>('form', { required: true })

const fields = computed(() => form.value[props.lang])
const bodies = ref<Partial<Record<FormLocale, { replace: (b: ArticleForm['es']['body']) => void }>>>({})
const editors = shallowRef<Record<FormLocale, Editor | null>>({ es: null, en: null })
const tick = ref(0)
const toolbar = ref<{ open: (key: DialogBlockKey) => void } | null>(null)
const activeEditor = computed(() => editors.value[props.lang])
function onReady(locale: FormLocale, editor: Editor | null) {
  editors.value = { ...editors.value, [locale]: editor }
  editor?.on('transaction', () => tick.value++)
}

const words = computed(() => countWords(fields.value.body.html))
const emptyEn = computed(() => props.lang === 'en' && !fields.value.title && !words.value)
function copySpanish() {
  bodies.value.en?.replace(form.value.es.body)
}

const marks = computed(() => {
  const has = (key: string) => props.changed?.includes(key) ?? false
  const en = props.lang === 'en'
  return {
    cover: has('coverMediaId'),
    title: has(en ? 'en.titleSlug' : 'es.title'),
    slug: has(en ? 'en.titleSlug' : 'es.slug'),
    excerpt: has(`${props.lang}.excerpt`),
    body: has(`${props.lang}.body`),
  }
})

const tag = computed(() => props.lang.toUpperCase() as 'ES' | 'EN')
const prefix = computed(() => (props.lang === 'es' ? '/blog/' : '/en/blog/'))
const titleId = useId()
const excerptId = useId()
</script>

<template>
  <div class="min-w-0 flex-1">
    <div class="sticky top-[104px] z-20 border-b border-adm-line bg-adm-bg/95 backdrop-blur md:top-12">
      <AdminEditorToolbar ref="toolbar" :editor="activeEditor" :tick="tick" :disabled="readonly" :words="words" :minutes="readingMinutes(words)" @media="emit('media', $event)" />
    </div>

    <article class="mx-auto max-w-[760px] px-5 pt-6 pb-32 md:px-8">
      <div :class="changedBar(marks.cover)">
        <AdminEditorCover :media="cover" :readonly="readonly" @change="emit('cover')" @remove="emit('remove-cover')" />
        <span v-if="marks.cover" class="sr-only">Portada cambiada</span>
      </div>

      <p class="mt-6 flex items-center gap-2 text-xs font-medium text-adm-meta"><span class="size-2 rounded-full" :class="categoryColor ? undefined : 'bg-adm-acc'" :style="categoryColor ? { backgroundColor: categoryColor } : undefined" aria-hidden="true" />{{ categoryName }}</p>

      <p v-if="emptyEn" class="mt-4 mb-4 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px]" role="status">
        Este artículo todavía no tiene versión en inglés. Déjala vacía o escríbela completa (título, URL y cuerpo).
        <button v-if="!readonly" type="button" class="ml-1 font-medium underline underline-offset-2 max-md:min-h-11" @click="copySpanish">Copiar el texto en español para traducir</button>
      </p>

      <label :for="titleId" class="sr-only">Título ({{ lang.toUpperCase() }})</label>
      <div :class="changedBar(marks.title)">
        <span v-if="marks.title" class="sr-only">Título cambiado</span>
        <textarea
          :id="titleId"
          v-model="fields.title"
          rows="2"
          :readonly="readonly"
          :placeholder="lang === 'es' ? 'Título del artículo' : 'Article title'"
          :aria-invalid="!!errors[`${lang}.title`] || undefined"
          :aria-describedby="errors[`${lang}.title`] ? `${titleId}-e` : undefined"
          class="mt-1 block w-full resize-none bg-transparent text-[28px] leading-[1.15] font-semibold tracking-tight [field-sizing:content] placeholder:text-adm-muted focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-adm-acc md:text-[34px]"
        />
        <p v-if="errors[`${lang}.title`]" :id="`${titleId}-e`" class="mt-1 flex items-center gap-1.5 text-xs text-adm-danger" role="alert"><CircleAlert class="size-3.5 flex-none" aria-hidden="true" />{{ errors[`${lang}.title`] }}</p>
      </div>

      <div :class="['mt-3', changedBar(marks.slug)]">
        <AdminSlugField
          :key="lang"
          v-model="fields.slug"
          :prefix="prefix"
          :source="fields.title"
          :taken="slugTaken[lang]"
          :suggestion="slugTaken[lang] ? slugSuggestion[lang] : undefined"
          :available="!!fields.slug && !slugTaken[lang] && !errors[`${lang}.slug`]"
          :error="errors[`${lang}.slug`]"
          :published="live && !!publishedSlug?.[lang]"
          :original="publishedSlug?.[lang] || undefined"
          :readonly="readonly"
        />
      </div>

      <div :class="['mt-5', changedBar(marks.excerpt)]">
        <label :for="excerptId" class="sr-only">Entradilla en {{ tag }}, que también se usa como extracto</label>
        <textarea
          :id="excerptId"
          v-model="fields.excerpt"
          rows="2"
          :readonly="readonly"
          :placeholder="lang === 'es' ? 'Una o dos frases que resuman el artículo' : 'One or two sentences summing up the article'"
          :aria-invalid="!!errors[`${lang}.excerpt`] || undefined"
          :aria-describedby="`${excerptId}-c`"
          class="block w-full resize-none bg-transparent text-lg leading-7 text-adm-meta [field-sizing:content] placeholder:text-adm-muted focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-adm-acc"
        />
        <p :id="`${excerptId}-c`" class="mt-1 flex items-center justify-end gap-2 text-xs tabular-nums" :class="errors[`${lang}.excerpt`] ? 'text-adm-danger' : 'text-adm-muted'">
          <span v-if="errors[`${lang}.excerpt`]" class="mr-auto flex items-center gap-1.5" role="alert"><CircleAlert class="size-3.5 flex-none" aria-hidden="true" />{{ errors[`${lang}.excerpt`] }}</span>
          <span>{{ fields.excerpt.length }} / {{ EXCERPT_MAX }}</span>
        </p>
      </div>
      <hr class="my-6 border-adm-line" />

      <div v-show="lang === 'es'" :class="changedBar(marks.body && lang === 'es')"><AdminEditorBody :ref="(el) => (bodies.es = el as never)" v-model="form.es.body" locale="es" :readonly="readonly" @ready="onReady('es', $event)" @dialog="toolbar?.open($event)" /></div>
      <div v-show="lang === 'en'" :class="changedBar(marks.body && lang === 'en')"><AdminEditorBody :ref="(el) => (bodies.en = el as never)" v-model="form.en.body" locale="en" :readonly="readonly" @ready="onReady('en', $event)" @dialog="toolbar?.open($event)" /></div>
    </article>
  </div>
</template>
