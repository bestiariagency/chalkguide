<script setup lang="ts">
import { scopeLabel, type AdminNews } from '~/utils/admin-news'

/** «Así sale en /noticias»: the row of the site with the mark «Resumen de ChalkGuide · Fuente: X», in Spanish or English. */
const props = defineProps<{ news: Pick<AdminNews, 'titleEs' | 'titleEn' | 'summaryEs' | 'summaryEn' | 'categoryKey' | 'scope' | 'sourceName' | 'sourceUrl' | 'sourcePublishedOn' | 'hasEn'>; category: string }>()
const lang = ref<'es' | 'en'>('es')
const en = computed(() => lang.value === 'en')
const title = computed(() => (en.value ? props.news.titleEn : props.news.titleEs))
const summary = computed(() => (en.value ? props.news.summaryEn : props.news.summaryEs))
const href = computed(() => safeHref(props.news.sourceUrl))
const options = [{ value: 'es', label: 'ES' }, { value: 'en', label: 'EN' }] as const
const uid = useId()
</script>

<template>
  <section :aria-labelledby="`${uid}-h`">
    <div class="flex items-center gap-2">
      <h3 :id="`${uid}-h`" class="text-sm font-semibold">Así sale en /noticias</h3>
      <AdminSegmented v-model="lang" class="ml-auto" label="Idioma de la vista previa" :options="options" />
    </div>
    <div class="mt-2 rounded-lg border border-adm-line bg-adm-side p-3" :lang="lang">
      <template v-if="title && summary">
        <p class="text-xs text-adm-meta">{{ category }} · {{ scopeLabel(news.scope) }}<template v-if="news.sourcePublishedOn"> · {{ adminDate(news.sourcePublishedOn) }}</template></p>
        <p class="mt-1 font-medium">{{ title }}</p>
        <p class="mt-1 line-clamp-2 text-xs text-adm-meta">{{ summary }}</p>
        <p class="mt-1.5 text-xs">{{ en ? 'ChalkGuide summary' : 'Resumen de ChalkGuide' }} · {{ en ? 'Source' : 'Fuente' }}: <a v-if="href" :href="href" target="_blank" :rel="SOURCE_LINK_REL" class="underline underline-offset-2">{{ news.sourceName }}<span class="sr-only"> (se abre en otra pestaña)</span></a><template v-else>{{ news.sourceName }}</template></p>
      </template>
      <p v-else class="text-xs text-adm-meta" lang="es">Sin versión en inglés: no sale en /en/news. Añade título y resumen en inglés al editar.</p>
    </div>
  </section>
</template>
