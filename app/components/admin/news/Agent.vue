<script setup lang="ts">
import { Sparkles } from 'lucide-vue-next'
import { newsInferred, type AdminNews } from '~/utils/admin-news'

/**
 * «Qué encontró el agente»: confidence, its note, the fields it deduced and the literal excerpt (only to verify; never
 * published). All of it is text from a hostile web page: interpolated, never rendered as HTML or Markdown.
 */
const props = defineProps<{ news: AdminNews }>()
const agent = computed(() => props.news.agent)
const DEDUCED = [['category', 'categoría'], ['published_on', 'fecha'], ['source_name', 'medio'], ['title_en', 'título EN'], ['summary_en', 'resumen EN']] as const
const deduced = computed(() => DEDUCED.filter(([key]) => newsInferred(props.news, key)))
const uid = useId()
</script>

<template>
  <section v-if="agent" class="rounded-lg border border-adm-line p-3 text-sm" :aria-labelledby="`${uid}-h`">
    <h3 :id="`${uid}-h`" class="flex items-center gap-2 font-semibold"><Sparkles class="size-4 text-adm-meta" aria-hidden="true" />Qué encontró el agente</h3>
    <dl class="mt-2 grid grid-cols-[110px_minmax(0,1fr)] gap-x-3 gap-y-1.5 text-xs">
      <dt class="text-adm-meta">Confianza</dt>
      <dd class="flex items-center gap-2"><AdminEventsConfidence :value="agent.confidence" /><span class="tabular-nums">{{ agent.confidence.toFixed(2).replace('.', ',') }}</span> · {{ confidenceWord(agent.confidence) }}</dd>
      <template v-if="agent.note"><dt class="text-adm-meta">Nota</dt><dd>{{ agent.note }}</dd></template>
      <template v-if="deduced.length">
        <dt class="text-adm-meta">Deducido</dt>
        <dd class="flex flex-wrap gap-x-2"><span v-for="[key, label] in deduced" :key="key" class="inline-flex items-center gap-0.5 text-[11px] text-adm-meta"><Sparkles class="size-3" aria-hidden="true" />{{ label }}</span></dd>
      </template>
      <dt class="text-adm-meta">Imagen</dt>
      <dd>{{ news.mediaId ? 'Elegida por ti, de Medios.' : 'Ninguna: el agente no propone imágenes, nunca se enlaza la de la fuente.' }}</dd>
    </dl>
    <template v-if="agent.excerpt">
      <blockquote class="mt-3 border-l-2 border-adm-line-strong pl-3 text-xs leading-5 text-adm-meta" :lang="news.sourceLang && news.sourceLang !== 'other' ? news.sourceLang : undefined">{{ agent.excerpt }}</blockquote>
      <p class="mt-1 text-xs text-adm-meta">Extracto literal de la fuente, solo para verificar. Nunca se publica.</p>
    </template>
  </section>
</template>
