<script setup lang="ts">
import { ChevronDown, ChevronUp, Eye, EyeOff, MapPin, PenLine, UserPen } from 'lucide-vue-next'
import { INSIGHT_MIN_WORDS, NEWS_LIMITS, wordCount, scopeLabel, type AdminNews } from '~/utils/admin-news'

/**
 * Detail of a draft in the inbox (read only), in the order of README §19.2: chips, title, **Fuente** (always on top, never
 * folded), summary with its similarity, indexing, what the agent found and the preview. In the sheet (< 1024) the title is the
 * dialog's and the actions sit in its footer.
 */
const props = defineProps<{ news: AdminNews; busy: boolean; labels: Record<string, string>; sheet?: boolean }>()
const emit = defineEmits<{ approve: []; edit: [focus?: 'insight']; reject: [reason: string | null]; prev: []; next: []; videosChanged: [] }>()
const rejectOpen = defineModel<boolean>('rejectOpen', { default: false })

const headId = `news-detail-${useId()}`
const flags = computed(() => sourceFlags(props.news.sourceUrl, props.news.agent?.note))
const category = computed(() => props.labels[props.news.categoryKey] ?? props.news.categoryKey)
const ranAt = computed(() => props.news.agent?.foundAt ?? props.news.createdAt)
const sourceDomains = useAdminSourceDomains()
const words = computed(() => wordCount(props.news.insightEs ?? ''))
const vids = useAdminNewsVideos(() => props.news.id, () => props.news.videos, () => emit('videosChanged'))
</script>

<template>
  <article :aria-labelledby="sheet ? undefined : headId" class="flex min-h-0 flex-1 flex-col">
    <header v-if="!sheet" class="sticky top-0 z-10 flex h-12 flex-none items-center gap-2 border-b border-adm-line bg-adm-bg px-6">
      <span class="text-xs text-adm-meta">Por revisar · <span :class="admKbd">J</span> <span :class="admKbd">K</span> para moverte</span>
      <span class="ml-auto flex flex-none gap-1">
        <button type="button" :class="admIconBtn" aria-label="Anterior (K)" @click="emit('prev')"><ChevronUp aria-hidden="true" /></button>
        <button type="button" :class="admIconBtn" aria-label="Siguiente (J)" @click="emit('next')"><ChevronDown aria-hidden="true" /></button>
      </span>
    </header>

    <div :class="['max-w-[760px] space-y-5', sheet ? '' : 'p-6']">
      <div class="flex flex-wrap items-center gap-1.5">
        <AdminNewsChip :status="news.status" /><AdminNewsOrigin :source="news.source" />
        <span :class="[admChip, 'bg-adm-subtle text-adm-meta']"><MapPin aria-hidden="true" />{{ scopeLabel(news.scope) }}</span>
        <span :class="[admChip, 'bg-adm-subtle text-adm-meta']">{{ category }}</span>
        <AdminNewsFlags :news="news" /><AdminNewsLang :has="news.hasEn" />
      </div>

      <div>
        <h2 v-if="!sheet" :id="headId" class="text-xl font-semibold tracking-tight [text-wrap:balance]">{{ news.titleEs }}</h2>
        <p v-if="news.agent && news.runId" :class="['text-xs text-adm-meta', !sheet && 'mt-1']">Recogida del {{ runLabel(ranAt) }} · <NuxtLink :to="`${adminPath('ingesta')}?recogida=${news.runId}`" class="underline underline-offset-2">ver en Ingesta</NuxtLink></p>
      </div>

      <AdminSourceCard
        :name="news.sourceName"
        :url="news.sourceUrl"
        :published-on="news.sourcePublishedOn"
        :lang="news.sourceLang"
        :approval-rate="news.sourceApprovalRate"
        :source-domain="news.sourceId ? sourceDomains[news.sourceId] : null"
        :punycode="flags.punycode"
        :unlisted="flags.unlisted"
      />

      <section aria-label="Resumen">
        <div class="flex items-center gap-2"><h3 class="text-sm font-semibold">Resumen</h3><span class="font-mono text-[11px] text-adm-muted">ES</span><span class="text-xs text-adm-meta tabular-nums">{{ news.summaryEs.length }} / {{ NEWS_LIMITS.summary }}</span></div>
        <p class="mt-2 max-w-[60ch] text-sm leading-6 [text-wrap:pretty]">{{ news.summaryEs }}</p>
        <p class="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-adm-meta">
          <AdminNewsSimilarity :value="news.similarity" />
          <span>Por encima del 35 % se marca: el resumen debe ser propio.</span>
        </p>
        <details v-if="news.titleEn || news.summaryEn" class="mt-3">
          <summary class="inline-flex min-h-6 cursor-pointer items-center gap-1.5 text-xs text-adm-meta hover:text-adm-fg max-md:min-h-11">Ver la versión en inglés</summary>
          <div class="mt-2 pl-5 text-sm leading-6" lang="en"><p class="font-medium">{{ news.titleEn }}</p><p class="mt-1 text-adm-meta">{{ news.summaryEn }}</p></div>
        </details>
      </section>

      <AdminNewsVideos
        :model-value="vids.videos.value"
        :proposed-ids="news.agent?.videos"
        :unverified="news.source === 'agent' && news.status === 'draft'"
        :disabled="vids.saving.value || news.status === 'rejected'"
        :error="vids.error.value"
        @update:model-value="vids.set"
      />

      <AdminBanner :icon="news.indexable ? Eye : EyeOff">
        <template v-if="news.indexable"><b class="font-medium">Con aporte: la ficha se indexa</b> y entra en el sitemap.</template>
        <template v-else-if="words"><b class="font-medium">El aporte tiene {{ words }} palabras.</b> Con {{ INSIGHT_MIN_WORDS }} o más la ficha se indexa; ahora sale con noindex.</template>
        <template v-else><b class="font-medium">Sin aporte: la ficha sale con noindex.</b> Si añades un aporte («Por qué importa») de al menos {{ INSIGHT_MIN_WORDS }} palabras, Google puede indexarla y entra en el sitemap.</template>
        <template #actions><button type="button" :class="[admBtnGhost, 'h-8']" @click="emit('edit', 'insight')"><PenLine aria-hidden="true" />{{ news.insightEs ? 'Editar aporte' : 'Añadir aporte' }}</button></template>
      </AdminBanner>

      <AdminNewsAgent :news="news" />
      <p v-if="!news.agent" class="flex items-center gap-1.5 text-xs text-adm-meta"><UserPen class="size-3" aria-hidden="true" />La creaste tú el <AdminTime :iso="news.createdAt" short /> y la guardaste como borrador.</p>

      <AdminNewsPreview :news="news" :category="category" />
      <p class="text-xs text-adm-meta">
        Al aprobar sale en /noticias<template v-if="news.hasEn"> y /en/news</template> en menos de 10 minutos y entra en el borrador de la carta de esta semana. Puedes retirarla cuando quieras.
      </p>
    </div>

    <div v-if="!sheet" class="sticky bottom-0 mt-auto border-t border-adm-line bg-adm-bg px-6 py-3">
      <AdminNewsActions v-model:reject-open="rejectOpen" :news="news" :busy="busy" @approve="emit('approve')" @edit="emit('edit')" @reject="(reason) => emit('reject', reason)" />
    </div>
  </article>
</template>
