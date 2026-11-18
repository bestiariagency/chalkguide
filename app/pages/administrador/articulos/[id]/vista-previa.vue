<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'
import type { FormLocale } from '~/utils/article-form'

/**
 * `/administrador/articulos/[id]/vista-previa?lang=es|en`: the article as the editor has it now,
 * drawn with the public components. Own page (no panel layout) under a "no publicado" strip. Not
 * indexed (`/administrador/**`). Panel chrome is Spanish; the article follows `lang`.
 */
definePageMeta({ layout: false, i18n: false })

const route = useRoute()
const id = String(route.params.id)
const lang = computed<FormLocale>(() => (route.query.lang === 'en' ? 'en' : 'es'))
const { load, article, building, live, hasDraft, notFound } = useArticlePreview(id, lang)
useAdminHead(() => `Vista previa · ${article.value?.title || 'Artículo'}`)

const back = computed(() => adminPath(`articulos/${id}`))
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
      <div v-else-if="notFound" class="admin px-4 py-6 font-sans"><AdminStateBlock kind="empty" title="Este artículo no existe" /></div>
      <div v-else-if="load.status.value === 'pending' || !load.data.value || building" class="admin px-4 py-6 font-sans" :aria-busy="true">
        <p v-if="showPreparing" class="flex items-center gap-2 text-sm text-adm-meta"><Loader2 class="size-4 animate-spin motion-reduce:animate-none" aria-hidden="true" />Preparando la vista previa…</p>
      </div>
      <div v-else-if="!article" class="admin font-sans">
        <AdminStateBlock kind="empty" :title="`Todavía no hay contenido en ${lang === 'en' ? 'inglés' : 'español'}`">
          <NuxtLink :to="{ path: back }" :class="admBtnGhost">Volver al editor</NuxtLink>
        </AdminStateBlock>
      </div>
      <article v-else aria-labelledby="article-title">
        <ArticlesArticleHeader :article="article" />
        <div class="mx-auto max-w-page px-4 py-12 md:px-6 md:py-16">
          <UiProse :html="article.bodyHtml" anchors />
        </div>
      </article>
    </main>
  </div>
</template>
