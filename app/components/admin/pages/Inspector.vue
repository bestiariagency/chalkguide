<script setup lang="ts">
import { ChevronRight, CircleCheck, CircleX, Clock, CornerDownRight, Lock, TriangleAlert } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'
import { PAGE_DELAY, revisedLabel, type PageDef } from '~/utils/admin-pages'
import type { ArticleErrors, FormLocale } from '~/utils/article-form'
import type { PageVersion } from '~/services/admin/pages'
import type { PageChecklistItem, PageForm, PageMeta } from '~/utils/page-form'

/** Settings of a page: publication, last update (legal), SEO, "ready to publish", where it is linked and history. */
const props = defineProps<{
  def: PageDef
  meta: PageMeta
  lang: FormLocale
  readonly: boolean
  errors: ArticleErrors
  checklist: PageChecklistItem[]
  og: AdminMedia | null
  /** Group keys with unpublished changes (D23). */
  changed?: string[]
  /** The published version already has English. */
  enLive: boolean
  /** The English being edited is complete (title and body). */
  enReady: boolean
  empty: boolean
  fallback: string
  versions: PageVersion[]
  /** When the stored draft of changes was last saved (ISO). */
  draftAt: string | null
  /** The "Última actualización" that publishing now would set, if it is not the stored one. */
  nextRevision?: string
}>()
defineEmits<{ og: []; 'remove-og': []; 'view-changes': [] }>()
const form = defineModel<PageForm>('form', { required: true })

const done = computed(() => props.checklist.filter((i) => i.ok).length)
const section = 'border-b border-adm-line [&[open]>summary_.chev]:rotate-90'
const summary = 'flex h-11 cursor-pointer list-none items-center gap-2 px-4 text-sm font-semibold max-md:h-12 [&::-webkit-details-marker]:hidden'
const chevron = 'chev size-3.5 text-adm-muted transition-transform motion-reduce:transition-none'
const publications = computed(() => [...new Map(props.versions.map((v) => [v.publishedAt, v])).values()])
</script>

<template>
  <div class="text-sm">
    <details :class="section" open>
      <summary :class="summary"><ChevronRight :class="chevron" aria-hidden="true" />Publicación</summary>
      <div class="space-y-3 px-4 pb-4">
        <div class="flex items-center justify-between gap-2">
          <span class="text-adm-meta">Estado</span>
          <AdminStatusChip :status="meta.published ? 'published' : 'draft'" :label="meta.published ? 'Publicada' : empty ? 'Sin contenido' : 'Borrador'" />
        </div>
        <div v-if="changed?.length" class="flex items-center justify-between gap-2">
          <span class="text-adm-meta">Sin publicar</span>
          <button type="button" class="inline-flex min-h-6 items-center rounded bg-adm-st-rev-bg px-1.5 py-0.5 text-xs font-medium text-adm-st-rev hover:underline max-md:min-h-11" @click="$emit('view-changes')">{{ changesLabel(changed.length) }} · ver</button>
        </div>
        <div class="flex items-center justify-between gap-2">
          <span class="text-adm-meta">En inglés</span>
          <span v-if="meta.published ? enLive : enReady" class="rounded bg-adm-subtle px-1 py-0.5 text-xs font-medium">{{ meta.published ? 'Sí, publicado' : 'Sí, al publicar' }}</span>
          <span v-else class="text-adm-meta">No · {{ def.routeEn }} da 404</span>
        </div>
        <p class="flex gap-1.5 text-xs text-adm-meta"><Clock class="mt-0.5 size-3.5 flex-none" aria-hidden="true" />{{ PAGE_DELAY }}</p>
      </div>
    </details>

    <details v-if="def.legal" :class="section" open>
      <summary :class="summary"><ChevronRight :class="chevron" aria-hidden="true" />Última actualización</summary>
      <div class="space-y-2 px-4 pb-4">
        <div class="flex items-center justify-between gap-2"><span class="text-adm-meta">Fecha que ve el lector</span><span class="tabular-nums">{{ meta.revisedOn ? revisedLabel(meta.revisedOn) : 'Aún sin fecha' }}</span></div>
        <p v-if="nextRevision" class="text-xs text-adm-meta">Al publicar se propondrá {{ nextRevision }}. Podrás mantener la fecha anterior si solo corriges una errata.</p>
        <p class="text-xs text-adm-meta">No se escribe a mano: se fija al publicar un cambio de título o de texto.</p>
      </div>
    </details>

    <details :class="section" open>
      <summary :class="summary"><ChevronRight :class="chevron" aria-hidden="true" />SEO<span class="ml-auto rounded-[3px] border border-adm-line-strong px-1 font-mono text-[11px] font-medium text-adm-meta">{{ lang.toUpperCase() }}</span></summary>
      <AdminPagesInspectorSeo v-model:form="form" :def="def" :lang="lang" :readonly="readonly" :errors="errors" :og="og" :changed="changed" :fallback="fallback" @og="$emit('og')" @remove-og="$emit('remove-og')" />
    </details>

    <details :class="section" open>
      <summary :class="summary"><ChevronRight :class="chevron" aria-hidden="true" />Listo para publicar<span class="ml-auto text-xs font-normal tabular-nums text-adm-meta">{{ done }} / {{ checklist.length }}</span></summary>
      <ul class="space-y-2 px-4 pb-4" aria-label="Comprobaciones antes de publicar">
        <li v-for="item in checklist" :key="item.key" class="flex gap-2">
          <CircleCheck v-if="item.ok" class="mt-0.5 size-4 flex-none text-adm-ok" aria-hidden="true" />
          <CircleX v-else-if="item.blocking" class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />
          <TriangleAlert v-else class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
          <span>{{ item.label }}<span class="sr-only">: {{ item.ok ? 'correcto' : item.blocking ? 'falta, impide publicar' : 'recomendado' }}</span><span v-if="!item.ok && item.hint" class="mt-0.5 block text-xs text-adm-meta">{{ item.hint }}</span><AdminEditorChecklistLinks :item="item" /></span>
        </li>
      </ul>
    </details>

    <details :class="section">
      <summary :class="summary"><ChevronRight :class="chevron" aria-hidden="true" />Dónde se enlaza</summary>
      <ul class="space-y-1.5 px-4 pb-4">
        <li v-for="link in def.links" :key="link" class="flex gap-2"><CornerDownRight class="mt-0.5 size-3.5 flex-none text-adm-muted" aria-hidden="true" />{{ link }}</li>
      </ul>
    </details>

    <details :class="section">
      <summary :class="summary"><ChevronRight :class="chevron" aria-hidden="true" />{{ def.legal ? 'Versiones publicadas' : 'Historial' }}</summary>
      <div class="space-y-2 px-4 pb-4">
        <template v-if="def.legal">
          <ul v-if="publications.length" class="space-y-2">
            <li v-for="v in publications" :key="v.publishedAt" class="flex gap-2">
              <span class="mt-1.5 size-2 flex-none rounded-full bg-adm-ok" aria-hidden="true" />
              <span>Texto del {{ revisedLabel(v.revisedOn) }}<span class="block text-xs text-adm-muted">publicado <AdminTime :iso="v.publishedAt" /></span></span>
            </li>
          </ul>
          <p v-else class="text-adm-meta">Aún no se ha publicado ninguna versión.</p>
          <p class="text-xs text-adm-meta">Cada publicación de una página legal guarda una copia fechada: sirve para saber qué texto estaba vigente cuando alguien se suscribió.</p>
        </template>
        <ol v-else class="space-y-2">
          <li v-if="draftAt" class="flex gap-2"><span class="mt-1.5 size-2 flex-none rounded-full bg-adm-st-rev" aria-hidden="true" /><span>Borrador de cambios<span class="block text-xs text-adm-muted"><AdminTime :iso="draftAt" /> · {{ changesLabel(changed?.length ?? 0) }}</span></span></li>
          <li v-if="meta.published" class="flex gap-2"><span class="mt-1.5 size-2 flex-none rounded-full bg-adm-ok" aria-hidden="true" /><span>Publicada<span class="block text-xs text-adm-muted"><AdminTime :iso="meta.updatedAt" /></span></span></li>
          <li class="flex gap-2"><span class="mt-1.5 size-2 flex-none rounded-full bg-adm-line-strong" aria-hidden="true" /><span>Creada<span class="block text-xs text-adm-muted"><AdminTime :iso="meta.createdAt" /></span></span></li>
        </ol>
      </div>
    </details>

    <p class="flex gap-2 px-4 py-4 pb-24 text-xs text-adm-meta md:pb-4"><Lock class="mt-0.5 size-3.5 flex-none" aria-hidden="true" />Las páginas fijas no se duplican ni se eliminan.</p>
  </div>
</template>
