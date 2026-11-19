<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import { INSIGHT_MIN_WORDS, NEWS_LIMITS, liveSimilarity, wordCount, type AdminNews } from '~/utils/admin-news'
import type { NewsErrors, NewsForm } from '~/utils/admin-news-form'

/**
 * «Texto» section of the news drawer: ES / EN tabs (a dot marks the incomplete English), title, own summary with its live
 * similarity to the excerpt the agent read, and the «Aporte propio» (why it matters) with its word counter and the indexing chip (≥ 80 words, D92), plus the internal SEO keyword and the optional meta description.
 */
const props = defineProps<{ news?: AdminNews; errors: NewsErrors }>()
const form = defineModel<NewsForm>('form', { required: true })
const lang = ref<'es' | 'en'>('es')
const enIncomplete = computed(() => !!form.value.titleEn.trim() !== !!form.value.summaryEn.trim())
const options = computed(() => [{ value: 'es' as const, label: 'Español' }, { value: 'en' as const, label: 'Inglés', dot: enIncomplete.value, dotLabel: 'incompleto' }])
const similarity = computed(() => liveSimilarity(form.value.summaryEs, props.news?.agent?.excerpt))
const words = computed(() => wordCount(form.value.insightEs))
const wordsEn = computed(() => wordCount(form.value.insightEn))
const indexable = computed(() => words.value >= INSIGHT_MIN_WORDS)
// An error in the other language switches to it, so the message is never hidden in a tab.
watch(
  () => props.errors,
  (e) => {
    if ((e.titleEn || e.summaryEn || e.insightEn || e.seoKeywordEn || e.metaDescriptionEn) && !(e.titleEs || e.summaryEs || e.insightEs || e.seoKeywordEs || e.metaDescriptionEs)) lang.value = 'en'
    else if (e.titleEs || e.summaryEs || e.insightEs || e.seoKeywordEs || e.metaDescriptionEs) lang.value = 'es'
  },
)
const uid = useId()
const simHigh = computed(() => (similarity.value ?? 0) >= HIGH_SIMILARITY)
</script>

<template>
  <section class="space-y-4" :aria-labelledby="`${uid}-h`">
    <div class="flex items-center gap-2">
      <h3 :id="`${uid}-h`" class="text-sm font-semibold">Texto</h3>
      <AdminSegmented v-model="lang" class="ml-auto" label="Idioma" :options="options" />
    </div>

    <div v-show="lang === 'es'" class="space-y-4">
      <AdminTextField v-model="form.titleEs" label="Título" lang="ES" name="titleEs" required :max="NEWS_LIMITS.title" :error="errors.titleEs" data-autofocus />
      <AdminTextArea v-model="form.summaryEs" label="Resumen propio" lang="ES" name="summaryEs" required :rows="6" :max="NEWS_LIMITS.summary" :error="errors.summaryEs" help="Con tus palabras: nunca frases copiadas de la fuente." />
      <p v-if="similarity != null" :class="['-mt-2 flex items-center gap-2 text-xs', simHigh ? 'text-adm-warn' : 'text-adm-meta']" role="status">
        <TriangleAlert v-if="simHigh" class="size-3.5" aria-hidden="true" />Parecido con la fuente: <b class="font-medium tabular-nums">{{ Math.round(similarity * 100) }} %</b><span v-if="simHigh"> · alto: reescríbelo con tus palabras.</span>
      </p>
      <div>
        <AdminTextArea v-model="form.insightEs" label="Aporte (por qué importa)" lang="ES" name="insightEs" :rows="6" :max="NEWS_LIMITS.insight" :error="errors.insightEs" placeholder="Por qué importa a quien escala en Cataluña, qué cambia, qué harías tú…" help="Texto plano. Sale en «Por qué importa», sin enlaces." />
        <p class="mt-1.5 flex flex-wrap items-center gap-2 text-xs text-adm-meta">
          <span :class="[admChip, indexable ? 'bg-adm-st-pub-bg text-adm-st-pub' : 'bg-adm-subtle text-adm-meta']">{{ indexable ? 'indexable' : 'noindex' }}</span>
          <span class="tabular-nums">{{ words }} / {{ INSIGHT_MIN_WORDS }} palabras</span>
          <span>{{ indexable ? 'Con este aporte la ficha se indexa y entra en el sitemap.' : `La ficha se indexa con un aporte de al menos ${INSIGHT_MIN_WORDS} palabras. Sin él, va con noindex.` }}</span>
        </p>
        <!-- Announced only when the state changes, not on every word. -->
        <p class="sr-only" role="status">{{ indexable ? 'Aporte suficiente: la ficha se indexa.' : 'Aporte corto: la ficha va con noindex.' }}</p>
      </div>
      <AdminTextField v-model="form.seoKeywordEs" label="Keyword SEO (interna)" lang="ES" name="seoKeywordEs" :max="NEWS_LIMITS.keyword" :error="errors.seoKeywordEs" help="Solo para ti: no se muestra en el sitio." />
      <AdminTextField v-model="form.metaDescriptionEs" label="Meta description (opcional)" lang="ES" name="metaDescriptionEs" :max="NEWS_LIMITS.metaDescription" :error="errors.metaDescriptionEs" help="Sin ella se usan las primeras frases del aporte." />
    </div>

    <div v-show="lang === 'en'" class="space-y-4">
      <AdminTextField v-model="form.titleEn" label="Título (EN)" lang="EN" name="titleEn" :max="NEWS_LIMITS.title" :error="errors.titleEn" help="Título y resumen en inglés van juntos. Sin los dos, no sale en /en/news." />
      <AdminTextArea v-model="form.summaryEn" label="Resumen (EN)" lang="EN" name="summaryEn" :rows="5" :max="NEWS_LIMITS.summary" :error="errors.summaryEn" />
      <div>
        <AdminTextArea v-model="form.insightEn" label="Aporte (EN)" lang="EN" name="insightEn" :rows="6" :max="NEWS_LIMITS.insight" :error="errors.insightEn" />
        <p class="mt-1.5 text-xs tabular-nums text-adm-meta">{{ wordsEn }} / {{ INSIGHT_MIN_WORDS }} palabras</p>
      </div>
      <AdminTextField v-model="form.seoKeywordEn" label="Keyword SEO (EN)" lang="EN" name="seoKeywordEn" :max="NEWS_LIMITS.keyword" :error="errors.seoKeywordEn" />
      <AdminTextField v-model="form.metaDescriptionEn" label="Meta description (EN)" lang="EN" name="metaDescriptionEn" :max="NEWS_LIMITS.metaDescription" :error="errors.metaDescriptionEn" />
    </div>
  </section>
</template>
