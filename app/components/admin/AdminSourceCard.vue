<script setup lang="ts">
import { ExternalLink, TriangleAlert } from 'lucide-vue-next'

/**
 * Block «Fuente» of Noticias and Agenda (README §19.2/§19.5), always on top and never folded: medio, domain in clear (marked
 * when it is punycode or not in the allowlist, F3), full URL, date, language and approval rate of the source, and the
 * collection it came from. Everything the agent wrote is interpolated; the only link out is built from `url` with the
 * safe `rel` of F3.
 */
const props = defineProps<{
  /** Medio; events carry no name, only the address. */
  name?: string
  url: string
  publishedOn?: string | null
  lang?: string | null
  /** 0–1 share of this source's drafts that Xavi published. */
  approvalRate?: number | null
  /** «lun 16 nov, 06:12» of the collection and the route that opens it in Ingesta. */
  runLabel?: string
  runTo?: string
  /** Domain registered for the source (`news_sources.domain`); when the real host differs, the card says so. */
  sourceDomain?: string | null
  punycode?: boolean
  unlisted?: boolean
}>()
const LANGS: Record<string, string> = { es: 'en español', ca: 'en catalán', en: 'en inglés', fr: 'en francés', it: 'en italiano', de: 'en alemán', other: 'otro idioma' }
const domain = computed(() => sourceDomain(props.url))
const href = computed(() => safeHref(props.url))
const initials = computed(() => Array.from((props.name ?? domain.value).replace(/[^\p{L}\p{N} ]/gu, '').trim()).slice(0, 2).join('').toUpperCase() || '··')
const facts = computed(() =>
  [
    props.publishedOn ? `Publicada el ${adminDate(props.publishedOn)}` : '',
    props.lang ? (LANGS[props.lang] ?? props.lang) : '',
    props.approvalRate != null ? `${Math.round(props.approvalRate * 100)} % aprobadas` : '',
  ].filter(Boolean),
)
const differs = computed(() => hostDiffers(props.url, props.sourceDomain))
const warned = computed(() => props.punycode || props.unlisted || differs.value)
</script>

<template>
  <section class="rounded-lg border border-adm-line-strong bg-adm-elev p-3" aria-label="Fuente">
    <div class="flex items-start gap-3">
      <span class="grid size-8 flex-none place-items-center rounded-md bg-adm-subtle font-mono text-[11px] font-medium text-adm-meta" aria-hidden="true">{{ initials }}</span>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-medium">Fuente<template v-if="name"> · {{ name }}</template></p>
        <p class="mt-0.5 flex flex-wrap items-center gap-1.5">
          <span :class="[admChip, 'font-mono', warned ? 'bg-adm-warn-soft text-adm-warn' : 'bg-adm-subtle text-adm-fg']">{{ domain || 'sin dominio' }}</span>
          <span v-if="punycode" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><TriangleAlert aria-hidden="true" />Dominio punycode: puede imitar a otro</span>
          <span v-if="differs" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><TriangleAlert aria-hidden="true" />El enlace apunta a un host distinto del de la fuente ({{ sourceDomain }})</span>
          <span v-if="unlisted" :class="[admChip, 'bg-adm-warn-soft text-adm-warn']"><TriangleAlert aria-hidden="true" />Fuente no listada</span>
        </p>
        <p class="mt-1 text-xs break-all text-adm-meta">{{ url }}</p>
        <p v-if="facts.length" class="mt-1 text-xs text-adm-meta">{{ facts.join(' · ') }}</p>
        <p v-if="runLabel" class="mt-1 text-xs text-adm-meta">
          Recogida del {{ runLabel }}<template v-if="runTo"> · <NuxtLink :to="runTo" class="underline underline-offset-2">ver en Ingesta</NuxtLink></template>
        </p>
      </div>
      <a v-if="href" :href="href" target="_blank" :rel="SOURCE_LINK_REL" :class="[admBtnGhost, 'h-8 flex-none px-2.5']">Abrir<ExternalLink aria-hidden="true" /><span class="sr-only"> la fuente (se abre en otra pestaña)</span></a>
    </div>
  </section>
</template>
