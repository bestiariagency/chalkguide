<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import { NOTE_MIN_WORDS, NEWS_LIMITS, liveSimilarity, wordCount, type AdminNews } from '~/utils/admin-news'
import type { NewsErrors, NewsForm } from '~/utils/admin-news-form'

/**
 * «Texto» section of the news drawer: ES / EN tabs (a dot marks the incomplete English), title, own summary with its live
 * similarity to the excerpt the agent read, and the optional «Nota de Xavi» with the indexing chip (≥ ~60 words, D79).
 */
const props = defineProps<{ news?: AdminNews; errors: NewsErrors }>()
const form = defineModel<NewsForm>('form', { required: true })
const lang = ref<'es' | 'en'>('es')
const enIncomplete = computed(() => !!form.value.titleEn.trim() !== !!form.value.summaryEn.trim())
const options = computed(() => [{ value: 'es' as const, label: 'Español' }, { value: 'en' as const, label: 'Inglés', dot: enIncomplete.value, dotLabel: 'incompleto' }])
const similarity = computed(() => liveSimilarity(form.value.summaryEs, props.news?.agent?.excerpt))
const words = computed(() => wordCount(form.value.noteEs))
const indexable = computed(() => words.value >= NOTE_MIN_WORDS)
// An error in the other language switches to it, so the message is never hidden in a tab.
watch(
  () => props.errors,
  (e) => {
    if ((e.titleEn || e.summaryEn || e.noteEn) && !(e.titleEs || e.summaryEs || e.noteEs)) lang.value = 'en'
    else if (e.titleEs || e.summaryEs || e.noteEs) lang.value = 'es'
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
        <AdminTextArea v-model="form.noteEs" label="Nota de Xavi (opcional)" lang="ES" name="noteEs" :rows="3" :max="NEWS_LIMITS.note" :error="errors.noteEs" placeholder="Qué opinas, a quién le importa, qué harías tú…" />
        <p class="mt-1.5 flex flex-wrap items-center gap-2 text-xs text-adm-meta">
          <span :class="[admChip, indexable ? 'bg-adm-st-pub-bg text-adm-st-pub' : 'bg-adm-subtle text-adm-meta']">{{ indexable ? 'indexable' : 'noindex' }}</span>
          <span>{{ indexable ? 'Con esta nota la ficha se indexa y entra en el sitemap (D79). Sale firmada, separada del resumen.' : `La ficha se indexa con una nota de al menos ${NOTE_MIN_WORDS} palabras${words ? ` (ahora ${words})` : ''}. Sin ella, va con noindex.` }}</span>
        </p>
      </div>
    </div>

    <div v-show="lang === 'en'" class="space-y-4">
      <AdminTextField v-model="form.titleEn" label="Title" lang="EN" name="titleEn" :max="NEWS_LIMITS.title" :error="errors.titleEn" help="Título y resumen en inglés van juntos. Sin los dos, no sale en /en/news." />
      <AdminTextArea v-model="form.summaryEn" label="Summary" lang="EN" name="summaryEn" :rows="5" :max="NEWS_LIMITS.summary" :error="errors.summaryEn" />
      <AdminTextArea v-model="form.noteEn" label="Xavi's note (optional)" lang="EN" name="noteEn" :rows="3" :max="NEWS_LIMITS.note" :error="errors.noteEn" />
    </div>
  </section>
</template>
