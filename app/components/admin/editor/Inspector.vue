<script setup lang="ts">
import { ChevronRight, CircleCheck, CircleX, Image as ImageIcon, TriangleAlert, X } from 'lucide-vue-next'
import type { AdminAuthorOption, AdminCategoryOption } from '~/utils/admin-articles'
import { publicationLabel, articleDisplay } from '~/utils/admin-articles'
import type { AdminMedia } from '~/utils/admin-media'
import { readingMinutes, countWords } from '~/utils/article-editor'
import type { ArticleErrors, ArticleForm, ArticleMeta, ChecklistItem, FormLocale } from '~/utils/article-form'

/** Settings of the article: publication, cover, organisation, SEO and the "ready to publish" list. */
const props = defineProps<{
  meta: ArticleMeta
  categories: AdminCategoryOption[]
  authors: AdminAuthorOption[]
  lang: FormLocale
  readonly: boolean
  cover: AdminMedia | null
  og: AdminMedia | null
  errors: ArticleErrors
  checklist: ChecklistItem[]
  /** Group keys with unpublished changes (D23). */
  changed?: string[]
}>()
defineEmits<{ cover: []; og: []; 'remove-og': []; 'remove-cover': []; 'view-changes': [] }>()
const form = defineModel<ArticleForm>('form', { required: true })

const mediaUrl = useMediaUrl()
const fields = computed(() => form.value[props.lang])
const tag = computed(() => props.lang.toUpperCase() as 'ES' | 'EN')
const options = computed(() => props.categories.map((c) => ({ value: c.id, label: c.name })))
const siteAuthor = useNoteAuthorName()
const SITE_AUTHOR = 'site'
const authorOptions = computed(() => [
  { value: SITE_AUTHOR, label: `Autor del sitio${siteAuthor.value ? ` (${siteAuthor.value})` : ''}` },
  ...props.authors.map((a) => ({ value: a.id, label: a.name })),
])
const authorValue = computed({
  get: () => form.value.authorId ?? SITE_AUTHOR,
  set: (value) => void (form.value.authorId = !value || value === SITE_AUTHOR ? null : value),
})
const display = computed(() => articleDisplay({ status: props.meta.status, published_at: props.meta.publishedAt }))
const dateLabel = computed(() => publicationLabel({ status: props.meta.status, published_at: props.meta.publishedAt }))
const reading = computed(() => readingMinutes(countWords(fields.value.body.html)))
const done = computed(() => props.checklist.filter((i) => i.ok).length)
const has = (...keys: string[]) => keys.some((key) => props.changed?.includes(key))
const bar = (...keys: string[]) => changedBar(has(...keys))
const section = 'border-b border-adm-line [&[open]>summary_.chev]:rotate-90'
const summary = 'flex h-11 cursor-pointer list-none items-center gap-2 px-4 text-sm font-semibold max-md:h-12 [&::-webkit-details-marker]:hidden'
</script>

<template>
  <div class="text-sm">
    <details :class="section" open>
      <summary :class="summary"><ChevronRight class="chev size-3.5 text-adm-muted transition-transform motion-reduce:transition-none" aria-hidden="true" />Publicación</summary>
      <div class="space-y-3 px-4 pb-4">
        <div class="flex items-center justify-between gap-2">
          <span class="text-adm-meta">Estado</span>
          <span class="flex items-center gap-2"><AdminStatusChip :status="display" /><span v-if="display !== 'draft'" class="text-xs text-adm-meta">{{ dateLabel }}</span></span>
        </div>
        <div v-if="changed?.length" class="flex items-center justify-between gap-2">
          <span class="text-adm-meta">Sin publicar</span>
          <button type="button" class="rounded bg-adm-st-rev-bg px-1.5 py-0.5 text-xs font-medium text-adm-st-rev inline-flex min-h-6 items-center hover:underline max-md:min-h-11" @click="$emit('view-changes')">{{ changesLabel(changed.length) }} · ver</button>
        </div>
        <div :class="bar('isFeatured')"><AdminSwitch v-model="form.isFeatured" label="Destacado en el blog" :disabled="readonly" /></div>
        <div class="flex items-center justify-between"><span class="text-adm-meta">Lectura</span><span class="tabular-nums">{{ reading }} min ({{ tag }})</span></div>
      </div>
    </details>

    <details :class="section" open>
      <summary :class="summary"><ChevronRight class="chev size-3.5 text-adm-muted transition-transform motion-reduce:transition-none" aria-hidden="true" />Portada</summary>
      <div :class="['space-y-3 px-4 pb-4', bar('coverMediaId')]">
        <div v-if="cover" class="flex items-center gap-3">
          <NuxtImg :src="mediaUrl(cover.storage_path)" alt="" width="80" height="48" class="h-12 w-20 flex-none rounded object-cover" />
          <p class="min-w-0 truncate font-mono text-xs">{{ cover.original_filename }}</p>
        </div>
        <p v-else class="text-adm-meta">Sin portada.</p>
        <div v-if="!readonly" class="flex flex-wrap gap-2">
          <button type="button" :class="admBtnGhost" @click="$emit('cover')"><ImageIcon aria-hidden="true" />{{ cover ? 'Cambiar' : 'Elegir portada' }}</button>
          <button v-if="cover" type="button" :class="admBtnQuiet" @click="$emit('remove-cover')"><X aria-hidden="true" />Quitar</button>
        </div>
        <p class="text-xs text-adm-meta">El texto alternativo se edita en la biblioteca de medios.</p>
      </div>
    </details>

    <details :class="section" open>
      <summary :class="summary"><ChevronRight class="chev size-3.5 text-adm-muted transition-transform motion-reduce:transition-none" aria-hidden="true" />Organización</summary>
      <div :class="['px-4 pb-4', bar('categoryId')]">
        <AdminSelect v-model="form.categoryId" label="Categoría" :options="options" required :disabled="readonly" :error="errors.categoryId" />
      </div>
      <div :class="['px-4 pb-4', bar('authorId')]">
        <AdminSelect v-model="authorValue" label="Autor" :options="authorOptions" :disabled="readonly" />
        <NuxtLink :to="adminPath('autores')" class="mt-1.5 inline-flex items-center text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11">Gestionar autores</NuxtLink>
      </div>
    </details>

    <details :class="section" open>
      <summary :class="summary"><ChevronRight class="chev size-3.5 text-adm-muted transition-transform motion-reduce:transition-none" aria-hidden="true" />SEO<span class="ml-auto rounded-[3px] border border-adm-line-strong px-1 font-mono text-[11px] font-medium text-adm-meta">{{ tag }}</span></summary>
      <div class="space-y-3 px-4 pb-4">
        <div class="rounded-md border border-adm-line bg-adm-elev p-3">
          <p class="truncate text-xs text-adm-meta">chalkguide › {{ lang === 'en' ? 'en › ' : '' }}blog › {{ fields.slug || '…' }}</p>
          <p class="mt-0.5 text-sm leading-5 text-adm-info">{{ fields.seoTitle || fields.title || 'Sin título' }}</p>
          <p class="mt-1 line-clamp-2 text-xs text-adm-meta">{{ fields.seoDescription || fields.excerpt || 'Sin descripción' }}</p>
        </div>
        <div :class="bar(`${lang}.seoTitle`)"><AdminTextField v-model="fields.seoTitle" label="Título SEO" seo="title" :lang="tag" :readonly="readonly" :error="errors[`${lang}.seoTitle`]" placeholder="Se usa el título" /></div>
        <div :class="bar(`${lang}.seoDescription`)"><AdminTextArea v-model="fields.seoDescription" label="Descripción" seo="description" :rows="2" :lang="tag" :readonly="readonly" :error="errors[`${lang}.seoDescription`]" placeholder="Se usa la entradilla" /></div>
        <div :class="bar('ogMediaId')">
          <p class="mb-1.5 text-xs font-medium">Imagen para compartir (OG)</p>
          <div v-if="og" class="mb-2 flex items-center gap-3">
            <NuxtImg :src="mediaUrl(og.storage_path)" alt="" width="80" height="48" class="h-12 w-20 flex-none rounded object-cover" />
            <p class="min-w-0 truncate font-mono text-xs">{{ og.original_filename }}</p>
          </div>
          <p v-else class="mb-2 text-xs text-adm-meta">Se usa la portada.</p>
          <div v-if="!readonly" class="flex flex-wrap gap-2">
            <button type="button" :class="admBtnGhost" @click="$emit('og')"><ImageIcon aria-hidden="true" />{{ og ? 'Cambiar' : 'Elegir imagen' }}</button>
            <button v-if="og" type="button" :class="admBtnQuiet" @click="$emit('remove-og')"><X aria-hidden="true" />Quitar</button>
          </div>
        </div>
        <div :class="bar('canonicalUrl')"><AdminTextField v-model="form.canonicalUrl" label="URL canónica" type="url" inputmode="url" :readonly="readonly" :error="errors.canonicalUrl" placeholder="https://" help="Solo si el texto se publicó antes en otro sitio." /></div>
        <div :class="bar('noindex')"><AdminSwitch v-model="form.noindex" label="No indexar" help="Pide a los buscadores que no lo muestren." :disabled="readonly" /></div>
      </div>
    </details>

    <details :class="section" open>
      <summary :class="summary"><ChevronRight class="chev size-3.5 text-adm-muted transition-transform motion-reduce:transition-none" aria-hidden="true" />Listo para publicar<span class="ml-auto text-xs font-normal tabular-nums text-adm-meta">{{ done }} / {{ checklist.length }}</span></summary>
      <ul class="space-y-2 px-4 pb-4">
        <li v-for="item in checklist" :key="item.key" class="flex gap-2">
          <CircleCheck v-if="item.ok" class="mt-0.5 size-4 flex-none text-adm-ok" aria-hidden="true" />
          <CircleX v-else-if="item.blocking" class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />
          <TriangleAlert v-else class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
          <span>{{ item.label }}<span class="sr-only">: {{ item.ok ? 'correcto' : item.blocking ? 'falta, impide publicar' : 'recomendado' }}</span><span v-if="!item.ok && item.links?.length && item.hint" class="mt-0.5 block text-xs text-adm-meta">{{ item.hint }}</span><AdminEditorChecklistLinks :item="item" /></span>
        </li>
      </ul>
    </details>
  </div>
</template>
