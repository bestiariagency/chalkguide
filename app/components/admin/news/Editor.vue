<script setup lang="ts">
import { ChevronDown, CircleAlert, Loader2, Sparkles, Trash2, Undo2, X } from 'lucide-vue-next'
import type { Database } from '~/types/database.types'
import type { NewsSaveAction } from '~/composables/useAdminNewsSave'
import { fetchNewsLinks } from '~/services/admin/news'
import type { AdminNews, NewsCategory } from '~/utils/admin-news'
import { emptyNewsForm, fullSourceUrl, newsToForm, validateNews, type NewsError, type NewsErrors, type NewsField, type NewsForm } from '~/utils/admin-news-form'

/**
 * News drawer (640 px; sheet under 768, README §19.2). New: Guardar borrador / Publicar. Draft: Rechazar ▾, Guardar, Guardar y
 * publicar. Published: Retirar…, Guardar. Rejected: read only with Recuperar. Saved at once (no draft of changes, like events).
 */
const props = defineProps<{ news?: AdminNews; categories: readonly NewsCategory[]; labels: Record<string, string>; busy: boolean; serverError?: NewsError; focus?: 'insight' }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ save: [form: NewsForm, action: NewsSaveAction]; reject: [reason: string | null]; recover: []; retire: []; remove: [] }>()

const client = useSupabaseClient<Database>()
const firstCategory = () => props.categories.find((c) => c.active)?.id ?? props.categories[0]?.id ?? ''
const form = ref<NewsForm>(props.news ? newsToForm(props.news) : emptyNewsForm(firstCategory()))
const snapshot = ref(JSON.stringify(form.value))
const dirty = computed(() => JSON.stringify(form.value) !== snapshot.value)
const errors = ref<NewsErrors>({})
const banner = ref<HTMLElement>()
const leaving = ref(false)

const isNew = computed(() => !props.news)
const status = computed(() => props.news?.status)
const locked = computed(() => status.value === 'rejected')
const agent = computed(() => props.news?.source === 'agent')
const title = computed(() => (props.news ? 'Editar noticia' : 'Nueva noticia'))
const found = computed(() => (props.news?.agent?.foundAt ? runDay(props.news.agent.foundAt) : null))

const FIELD_LABELS: Partial<Record<NewsField, string>> = { titleEs: 'título', titleEn: 'título en inglés', summaryEs: 'resumen', summaryEn: 'resumen en inglés', insightEs: 'aporte', insightEn: 'aporte en inglés', seoKeywordEs: 'keyword', seoKeywordEn: 'keyword en inglés', metaDescriptionEs: 'meta description', metaDescriptionEn: 'meta description en inglés', sourceName: 'medio', sourceUrl: 'enlace a la fuente', publishedOn: 'fecha', categoryId: 'categoría', image: 'imagen', imageLicense: 'licencia', imageCredit: 'crédito', tags: 'etiquetas', videos: 'vídeos' }
const errorFields = computed(() => (Object.keys(errors.value) as NewsField[]).filter((k) => errors.value[k]))

function focusField(field: NewsField) {
  const root = document.getElementById('news-form')
  root?.querySelector<HTMLElement>(`[name="${field}"]:not([type=hidden]), [data-field="${field}"] button, [data-field="${field}"] input`)?.focus()
}
function fail(next: NewsErrors) {
  errors.value = next
  void nextTick(() => banner.value?.focus())
}
function submit(action: NewsSaveAction) {
  if (props.busy || locked.value) return
  const result = validateNews(form.value, { agent: agent.value, publishing: action === 'publish' || action === 'save-publish' || status.value === 'published' })
  if (Object.keys(result).length) return fail(result)
  errors.value = {}
  emit('save', { ...form.value, links: [...form.value.links] }, action)
}
watch(
  () => props.serverError,
  (e) => {
    if (!e) return
    errors.value = e.field ? { ...errors.value, [e.field]: e.message } : errors.value
    void nextTick(() => banner.value?.focus())
  },
)

// The related links live in their own table: load them, then take the snapshot so they do not count as changes.
onMounted(async () => {
  if (props.news) {
    try {
      form.value.links = await fetchNewsLinks(client, props.news.id)
    } catch {
      // Without links the item can still be edited; saving then keeps what the form shows.
    }
  }
  snapshot.value = JSON.stringify(form.value)
  if (props.focus === 'insight') void nextTick(() => document.querySelector<HTMLElement>('#news-form [name="insightEs"]')?.focus())
})

/** Closing with unsaved changes asks first. */
function requestClose(value: boolean) {
  if (value) return
  if (dirty.value && !props.busy) leaving.value = true
  else open.value = false
}
function leave() {
  leaving.value = false
  open.value = false
}
const preview = computed(() => ({
  titleEs: form.value.titleEs,
  titleEn: form.value.titleEn || null,
  summaryEs: form.value.summaryEs,
  summaryEn: form.value.summaryEn || null,
  categoryKey: props.categories.find((c) => c.id === form.value.categoryId)?.key ?? '',
  scope: form.value.scope,
  sourceName: form.value.sourceName,
  sourceUrl: fullSourceUrl(form.value.sourceUrl),
  sourcePublishedOn: form.value.publishedOn || null,
  hasEn: !!form.value.titleEn && !!form.value.summaryEn,
}))
const bannerText = computed(() => props.serverError?.message)
</script>

<template>
  <AdminModal :open="open" :title="title" placement="right" extra :busy="busy" @update:open="requestClose">
    <form id="news-form" novalidate @submit.prevent="submit(isNew ? 'draft' : 'save')">
      <fieldset :disabled="locked" class="min-w-0 space-y-6">
        <div v-if="news" class="flex flex-wrap items-center gap-2"><AdminNewsChip :status="news.status" /><AdminNewsOrigin :source="news.source" /><AdminNewsFlags :news="news" /></div>

        <div v-if="errorFields.length || bannerText" ref="banner" tabindex="-1" role="alert" class="flex items-start gap-2 rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] leading-5 text-adm-danger outline-none">
          <CircleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
          <span>
            <template v-if="bannerText && !errorFields.length">{{ bannerText }}</template>
            <template v-else>
              Revisa {{ errorFields.length }} {{ errorFields.length === 1 ? 'campo' : 'campos' }}:
              <template v-for="(field, i) in errorFields" :key="field">
                <button type="button" class="underline underline-offset-2" @click="focusField(field)">{{ FIELD_LABELS[field] ?? field }}</button>{{ i < errorFields.length - 1 ? ', ' : '.' }}
              </template>
            </template>
          </span>
        </div>

        <AdminBanner v-if="agent && status === 'draft'" :icon="Sparkles">
          Propuesta por el agente<template v-if="found"> el <b>{{ found }}</b></template>. Lo marcado <span class="inline-flex items-center gap-0.5 text-[11px] text-adm-meta"><Sparkles class="size-3" aria-hidden="true" />deducido</span> lo puso él: compruébalo. La marca se quita al tocar el campo.
        </AdminBanner>
        <p v-if="locked" class="rounded-lg bg-adm-subtle px-3 py-2 text-[13px] text-adm-meta">Está rechazada: no se edita. «Recuperar» la devuelve a Por revisar.</p>

        <AdminNewsEditorText v-model:form="form" :news="news" :errors="errors" />
        <AdminNewsEditorSource v-model:form="form" :news="news" :categories="categories" :errors="errors" />
        <AdminNewsVideos v-model="form.videos" data-field="videos" :proposed-ids="news?.agent?.videos" :unverified="agent && status === 'draft'" :error="errors.videos" />
        <AdminNewsEditorImage v-model:form="form" :errors="errors" />
        <AdminNewsEditorLinks v-model:form="form" />
      </fieldset>

      <div class="mt-6 space-y-5 border-t border-adm-line pt-4">
        <AdminNewsPreview :news="preview" :category="labels[preview.categoryKey] ?? ''" />
        <details v-if="news?.agent?.excerpt" class="rounded-lg border border-adm-line">
          <summary class="flex min-h-10 cursor-pointer items-center gap-2 px-3 text-sm font-medium">Lo que leyó el agente</summary>
          <div class="space-y-2 px-3 pb-3 text-xs text-adm-meta">
            <blockquote class="border-l-2 border-adm-line-strong pl-3 leading-5">{{ news.agent.excerpt }}</blockquote>
            <p>Confianza {{ news.agent.confidence.toFixed(2).replace('.', ',') }}<template v-if="news.agent.note"> · {{ news.agent.note }}</template></p>
          </div>
        </details>
      </div>
    </form>

    <template #footer>
      <template v-if="locked">
        <button type="button" :class="admBtnGhost" @click="open = false">Cerrar</button>
        <button type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('recover')"><Undo2 aria-hidden="true" />Recuperar</button>
      </template>
      <template v-else>
        <div v-if="status === 'draft'" class="flex gap-2 sm:mr-auto max-md:w-full max-md:[&>*]:flex-1">
          <AdminNewsRejectMenu :agent="agent" side="top" @select="(reason) => emit('reject', reason)">
            <button type="button" :class="[admBtnGhost, 'max-md:w-full']" :disabled="busy" aria-haspopup="menu"><X aria-hidden="true" />Rechazar…<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /></button>
          </AdminNewsRejectMenu>
          <button v-if="!agent" type="button" :class="admBtnDangerGhost" :disabled="busy" @click="emit('remove')"><Trash2 aria-hidden="true" />Eliminar…</button>
        </div>
        <button v-else-if="status === 'published'" type="button" :class="[admBtnGhost, 'sm:mr-auto']" :disabled="busy" @click="emit('retire')"><Undo2 aria-hidden="true" />Retirar…</button>
        <button type="button" :class="admBtnGhost" :disabled="busy" @click="requestClose(false)">Cancelar</button>
        <template v-if="isNew">
          <button type="button" :class="admBtnGhost" :disabled="busy" @click="submit('draft')">Guardar borrador</button>
          <button type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined" @click="submit('publish')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Publicar</button>
        </template>
        <template v-else-if="status === 'draft'">
          <button type="button" :class="admBtnGhost" :disabled="busy" @click="submit('save')">Guardar</button>
          <button type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined" @click="submit('save-publish')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar y publicar</button>
        </template>
        <button v-else type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined" @click="submit('save')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar</button>
      </template>
    </template>
  </AdminModal>

  <AdminModal v-model:open="leaving" alert stacked title="¿Salir sin guardar?" description="Tienes cambios sin guardar en esta noticia. Si sales, se pierden.">
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus @click="leaving = false">Seguir editando</button>
      <button type="button" :class="admBtnDanger" @click="leave">Salir sin guardar</button>
    </template>
  </AdminModal>
</template>
