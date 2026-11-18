<script setup lang="ts">
import { Sparkles } from 'lucide-vue-next'
import { ADMIN_NEWS_SCOPES, newsInferred, type AdminNews, type NewsCategory, type NewsScope } from '~/utils/admin-news'
import type { NewsErrors, NewsForm } from '~/utils/admin-news-form'

/**
 * «Fuente» and «Clasificación» of the news drawer. The source is always required. The link of an item from the agent is read
 * only (the agent uses it to deduplicate and the database keeps it fixed); the rest carries «deducido» until it is touched.
 */
const props = defineProps<{ news?: AdminNews; categories: readonly NewsCategory[]; errors: NewsErrors }>()
const form = defineModel<NewsForm>('form', { required: true })
const touched = ref(new Set<string>())
const touch = (key: string) => (touched.value = new Set(touched.value).add(key))
const guessed = (key: string) => !!props.news && newsInferred(props.news, key) && !touched.value.has(key)
const agentLink = computed(() => props.news?.source === 'agent')
const urlModel = computed({
  get: () => form.value.sourceUrl.replace(/^https:\/\//, ''),
  set: (v: string) => (form.value.sourceUrl = v),
})
const categoryOptions = computed(() => props.categories.map((c) => ({ value: c.id, label: c.labelEs })))
const category = computed({ get: () => form.value.categoryId || undefined, set: (v: string | undefined) => { form.value.categoryId = v ?? ''; touch('category') } })
const scope = computed<NewsScope>({ get: () => form.value.scope, set: (v) => { form.value.scope = v; touch('scope') } })
const tagDraft = ref('')
function addTag() {
  const tag = tagDraft.value.trim().toLowerCase().slice(0, 30)
  tagDraft.value = ''
  if (tag && !form.value.tags.includes(tag)) form.value.tags = [...form.value.tags, tag]
}
const mark = 'ml-auto inline-flex items-center gap-0.5 text-[11px] font-normal text-adm-meta'
const scopeId = `news-scope-${useId()}`
const uid = useId()
</script>

<template>
  <div class="space-y-6">
    <section class="space-y-4" :aria-labelledby="`${uid}-src`">
      <h3 :id="`${uid}-src`" class="flex items-center gap-2 text-sm font-semibold">Fuente <span :class="[admChip, 'bg-adm-subtle font-normal text-adm-meta']">Siempre visible en la ficha y en la carta</span></h3>
      <div class="grid gap-4 sm:grid-cols-2">
        <div>
          <AdminTextField v-model="form.sourceName" label="Medio" name="sourceName" required :max="120" :error="errors.sourceName" help="Nombre corto: «Fuente: FEEC»." @update:model-value="touch('source_name')" />
          <p v-if="guessed('source_name')" :class="[mark, 'mt-1']"><Sparkles class="size-3" aria-hidden="true" />deducido</p>
        </div>
        <div>
          <AdminTextField v-model="form.publishedOn" type="date" label="Publicada el" name="publishedOn" :error="errors.publishedOn" @update:model-value="touch('published_on')" />
          <p v-if="guessed('published_on')" :class="[mark, 'mt-1']"><Sparkles class="size-3" aria-hidden="true" />deducido</p>
        </div>
      </div>
      <AdminTextField
        v-model="urlModel"
        label="Enlace a la noticia original"
        name="sourceUrl"
        prefix="https://"
        :required="!agentLink"
        :readonly="agentLink"
        :error="errors.sourceUrl"
        :help="agentLink ? 'Fijo: lo propuso el agente y lo usa para no repetirla. Para cambiarlo, rechaza esta noticia y crea otra a mano.' : news?.status === 'published' ? 'Cambiar el enlace de una noticia publicada afecta a cómo la rutina detecta las repetidas: hazlo solo si estaba mal.' : undefined"
      />
    </section>

    <section class="space-y-4" :aria-labelledby="`${uid}-cls`">
      <h3 :id="`${uid}-cls`" class="text-sm font-semibold">Clasificación</h3>
      <div class="grid gap-4 sm:grid-cols-2">
        <div data-field="categoryId">
          <AdminSelect v-model="category" label="Categoría" required :options="categoryOptions" placeholder="Elige una categoría…" :error="errors.categoryId" />
          <p v-if="guessed('category')" :class="[mark, 'mt-1']"><Sparkles class="size-3" aria-hidden="true" />deducido</p>
        </div>
        <div>
          <p :id="scopeId" :class="admLabel">Alcance <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span></p>
          <AdminSegmented v-model="scope" class="grid! w-full grid-cols-3" :labelledby="scopeId" :options="ADMIN_NEWS_SCOPES" />
        </div>
      </div>
      <div>
        <label :for="`${uid}-tag`" :class="admLabel">Etiquetas <span class="font-normal text-adm-meta">(internas: búsqueda y carta)</span></label>
        <div :class="[admInput, 'flex h-auto min-h-8 flex-wrap items-center gap-1.5 py-1']">
          <span v-for="tag in form.tags" :key="tag" class="inline-flex h-6 items-center gap-1 rounded bg-adm-subtle pr-1 pl-2 text-xs">{{ tag }}<button type="button" :class="[admIconBtn, 'size-5!']" :aria-label="`Quitar ${tag}`" @click="form.tags = form.tags.filter((t) => t !== tag)">×</button></span>
          <input :id="`${uid}-tag`" v-model="tagDraft" class="min-w-20 flex-1 bg-transparent text-sm outline-none placeholder:text-adm-muted" placeholder="Añadir…" autocomplete="off" @keydown.enter.prevent="addTag" @keydown.,.prevent="addTag" @blur="addTag" />
        </div>
        <p v-if="errors.tags" class="mt-1.5 text-xs text-adm-danger" role="alert">{{ errors.tags }}</p>
        <p v-else class="mt-1.5 text-xs text-adm-meta">Enter o coma para añadir. No salen en el sitio en esta versión.</p>
      </div>
      <p v-if="news" class="text-xs text-adm-meta">Dirección: <span class="font-mono">/noticias/{{ news.slug }}</span> · se fija al publicar por primera vez.</p>
    </section>
  </div>
</template>
