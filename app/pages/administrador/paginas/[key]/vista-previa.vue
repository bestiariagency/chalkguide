<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'
import { PAGE_DEFS, isPageKey, revisedLabel, type PageKey } from '~/utils/admin-pages'
import type { FormLocale } from '~/utils/article-form'

/**
 * `/administrador/paginas/[key]/vista-previa?lang=es|en`: the page as the editor has it now, drawn with
 * the public prose under a "no publicado" strip. Own page (no panel layout). Not indexed (`/administrador/**`).
 */
definePageMeta({ layout: false, i18n: false })

const route = useRoute()
const raw = String(route.params.key)
if (!isPageKey(raw)) throw createError({ statusCode: 404, statusMessage: 'Página no encontrada', fatal: true })
const key: PageKey = raw
const def = PAGE_DEFS[key]
const lang = computed<FormLocale>(() => (route.query.lang === 'en' ? 'en' : 'es'))
const { load, page, building, revisedOn, live, hasDraft, notFound } = usePagePreview(key, lang)
useAdminHead(() => `Vista previa · ${page.value?.title || def.label}`)

const back = adminPath(`paginas/${key}`)
/** Violet is only for unpublished changes; the other two states are neutral. */
const variant = computed(() => (live.value && hasDraft.value ? 'changes' : live.value ? 'published' : 'draft'))
const label = computed(() => ({
  changes: 'Vista previa · incluye tus cambios sin publicar',
  published: 'Vista previa · versión publicada',
  draft: 'Vista previa · borrador, no publicado',
})[variant.value])
const showPreparing = useDelayedFlag(() => load.status.value === 'pending' || !load.data.value || building.value, 300)
const other = computed<FormLocale>(() => (lang.value === 'es' ? 'en' : 'es'))
</script>

<template>
  <div class="min-h-dvh bg-background">
    <AdminPreviewStrip :back="back" :label="label" :changes="variant === 'changes'" :lang="lang" :other="other" />

    <main id="contenido">
      <div v-if="load.error.value" class="admin px-4 py-6 font-sans"><AdminStateBlock kind="error" title="No se ha podido cargar la vista previa" @retry="load.refresh()" /></div>
      <div v-else-if="notFound" class="admin px-4 py-6 font-sans"><AdminStateBlock kind="empty" title="Esta página no existe" /></div>
      <div v-else-if="load.status.value === 'pending' || !load.data.value || building" class="admin px-4 py-6 font-sans" :aria-busy="true">
        <p v-if="showPreparing" class="flex items-center gap-2 text-sm text-adm-meta"><Loader2 class="size-4 animate-spin motion-reduce:animate-none" aria-hidden="true" />Preparando la vista previa…</p>
      </div>
      <div v-else-if="!page" class="admin font-sans">
        <AdminStateBlock kind="empty" :title="`Todavía no hay contenido en ${lang === 'en' ? 'inglés' : 'español'}`">
          <NuxtLink :to="{ path: back }" :class="admBtnGhost">Volver al editor</NuxtLink>
        </AdminStateBlock>
      </div>
      <article v-else aria-labelledby="page-title">
        <section class="board-tex border-b-[0.5px] border-line">
          <div class="mx-auto max-w-page px-4 pt-8 pb-12 md:px-6 md:pt-10 md:pb-16">
            <h1 id="page-title" class="text-title-1 font-medium">{{ page.title }}</h1>
            <p v-if="revisedOn" class="mt-3 text-sm text-meta">Última actualización: {{ revisedLabel(revisedOn) }}</p>
          </div>
        </section>
        <div class="mx-auto max-w-page px-4 py-12 md:px-6 md:py-16"><UiProse :html="page.bodyHtml" /></div>
      </article>
    </main>
  </div>
</template>
