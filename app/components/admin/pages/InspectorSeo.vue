<script setup lang="ts">
import { EyeOff, Image as ImageIcon, X } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import type { PageDef } from '~/utils/admin-pages'
import type { ArticleErrors, FormLocale } from '~/utils/article-form'
import type { PageForm } from '~/utils/page-form'

/**
 * SEO of a page, per language: title (≤ 70) and description (≤ 160); if empty the description falls
 * back to the page's own default (the site copy `seo.*Description`). Indexing and share image are
 * editable only on the non-legal pages (legal: always noindex, follow; share image of Ajustes).
 */
const props = defineProps<{
  def: PageDef
  lang: FormLocale
  readonly: boolean
  errors: ArticleErrors
  og: AdminMedia | null
  changed?: string[]
  /** Default description of this page in the active language. */
  fallback: string
}>()
defineEmits<{ og: []; 'remove-og': [] }>()
const form = defineModel<PageForm>('form', { required: true })

const mediaUrl = useMediaUrl()
const fields = computed(() => form.value[props.lang])
const tag = computed(() => props.lang.toUpperCase() as 'ES' | 'EN')
const path = computed(() => (props.lang === 'es' ? props.def.routeEs : props.def.routeEn).slice(1).split('/').join(' › '))
const bar = (...keys: string[]) => changedBar(keys.some((key) => props.changed?.includes(key)))
</script>

<template>
  <div class="space-y-3 px-4 pb-4">
    <div class="rounded-md border border-adm-line bg-adm-elev p-3">
      <p class="truncate text-xs text-adm-meta">chalkguide › {{ path }}</p>
      <p class="mt-0.5 text-sm leading-5 text-adm-info">{{ fields.seoTitle || fields.title || 'Sin título' }}</p>
      <p class="mt-1 line-clamp-2 text-xs text-adm-meta">{{ fields.seoDescription || fallback }}</p>
    </div>
    <div data-page-field="seo-title" :class="bar(`${lang}.seoTitle`)"><AdminTextField v-model="fields.seoTitle" label="Título SEO" seo="title" :lang="tag" :readonly="readonly" :error="errors[`${lang}.seoTitle`]" placeholder="Se usa el título" /></div>
    <div data-page-field="seo-description" :class="bar(`${lang}.seoDescription`)">
      <AdminTextArea v-model="fields.seoDescription" label="Descripción" seo="description" :rows="3" :lang="tag" :readonly="readonly" :error="errors[`${lang}.seoDescription`]" :placeholder="fallback ? `Vacía: se usa «${fallback}»` : 'Se usa la descripción por defecto de la página'" help="Vacía, se usa la descripción por defecto de esta página (no la del sitio)." />
    </div>

    <div v-if="def.legal" class="flex items-center justify-between gap-2">
      <span class="text-adm-meta">Indexación</span>
      <span :class="[admChip, 'bg-transparent text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line']"><EyeOff aria-hidden="true" />Nunca (legal)</span>
    </div>
    <p v-if="def.legal" class="-mt-1 text-xs text-adm-meta">Las páginas legales no salen nunca en buscadores. Usan la imagen para compartir de Ajustes.</p>
    <template v-else>
      <div :class="bar('noindex')"><AdminSwitch v-model="form.noindex" label="No indexar" help="Pide a los buscadores que no la muestren." :disabled="readonly" /></div>
      <div :class="bar('ogMediaId')">
        <p class="mb-1.5 text-xs font-medium">Imagen para compartir</p>
        <div v-if="og" class="mb-2 flex items-center gap-3">
          <NuxtImg :src="mediaUrl(og.storage_path)" alt="" width="80" height="48" class="h-12 w-20 flex-none rounded object-cover" />
          <p class="min-w-0 truncate font-mono text-xs">{{ og.original_filename }}</p>
        </div>
        <p v-else class="mb-2 text-xs text-adm-meta">Se usa la de Ajustes.</p>
        <div v-if="!readonly" class="flex flex-wrap gap-2">
          <button type="button" :class="admBtnGhost" @click="$emit('og')"><ImageIcon aria-hidden="true" />{{ og ? 'Cambiar' : 'Elegir imagen' }}</button>
          <button v-if="og" type="button" :class="admBtnQuiet" @click="$emit('remove-og')"><X aria-hidden="true" />Quitar</button>
        </div>
      </div>
    </template>
  </div>
</template>
