<script setup lang="ts">
import { Loader2, Trash2 } from 'lucide-vue-next'
import { SOURCE_KINDS, SOURCE_LANGS, type AdminSource } from '~/utils/admin-ingest'
import { INSTRUCTIONS_MAX, emptySourceForm, sourceToForm, validateSource, type SourceErrors, type SourceForm } from '~/utils/admin-ingest-form'
import { ADMIN_NEWS_SCOPES } from '~/utils/admin-news'

/**
 * Drawer of a source (README §19.4): name, page to read, what it is for, scope, language, notes for the agent (≤ 280, never
 * links or personal data) and active. The domain is taken from the address. Events only from Barcelona and Catalonia (D71).
 */
const props = defineProps<{ source?: AdminSource; busy: boolean; error?: string }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ save: [form: SourceForm]; remove: [] }>()

const form = ref<SourceForm>(props.source ? sourceToForm(props.source) : emptySourceForm())
const errors = ref<SourceErrors>({})
const kindId = `src-kind-${useId()}`
const scopeId = `src-scope-${useId()}`
const langOptions = [{ value: 'none', label: 'Sin indicar' }, ...SOURCE_LANGS.map((l) => ({ value: l.value as string, label: l.label }))]
const lang = computed<string | undefined>({ get: () => form.value.lang || 'none', set: (v) => (form.value.lang = !v || v === 'none' ? '' : v) })
const domain = computed(() => sourceDomain(/^https?:\/\//i.test(form.value.url) ? form.value.url : `https://${form.value.url}`))
const canRemove = computed(() => !!props.source && !props.source.newsTotal && !props.source.eventsTotal)

function submit() {
  if (props.busy) return
  errors.value = validateSource(form.value)
  if (Object.keys(errors.value).length) return
  emit('save', form.value)
}
</script>

<template>
  <AdminModal v-model:open="open" placement="right" :title="source ? 'Editar fuente' : 'Nueva fuente'" :busy="busy">
    <form id="source-form" novalidate class="space-y-4" @submit.prevent="submit">
      <p v-if="error" class="rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] text-adm-danger" role="alert">{{ error }}</p>
      <AdminTextField v-model="form.name" label="Nombre" required :max="120" :error="errors.name" help="Es el que sale en «Fuente: …»." data-autofocus />
      <AdminTextField v-model="form.url" label="Web" required prefix="https://" type="text" inputmode="url" :error="errors.url" :help="domain ? `La página que debe revisar: la de noticias o la de calendario, no la portada. Dominio: ${domain}` : 'La página que debe revisar: la de noticias o la de calendario, no la portada.'" />
      <div><p :id="kindId" :class="admLabel">Para <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span></p><AdminSegmented v-model="form.kind" class="grid! w-full grid-cols-3" :labelledby="kindId" :options="SOURCE_KINDS" /></div>
      <div>
        <p :id="scopeId" :class="admLabel">Alcance <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span></p>
        <AdminSegmented v-model="form.scope" class="grid! w-full grid-cols-3" :labelledby="scopeId" :options="ADMIN_NEWS_SCOPES" />
        <p class="mt-1.5 text-xs text-adm-meta">Los eventos solo se aceptan de Barcelona y Cataluña (D71).</p>
      </div>
      <AdminSelect v-model="lang" label="Idioma de la web" :options="langOptions" />
      <AdminTextArea v-model="form.instructions" label="Indicaciones (opcional)" :rows="3" :max="INSTRUCTIONS_MAX" :error="errors.instructions" help="Para el agente: qué mirar y qué no, y dónde está el feed. Nunca enlaces ni datos personales." />
      <AdminSwitch v-model="form.trusted" label="De confianza" help="El sitio enlaza esta fuente sin nofollow (D79). Actívalo solo si la has verificado." />
      <AdminSwitch v-model="form.active" label="Activa: la rutina la revisa" />
    </form>
    <template #footer>
      <button v-if="canRemove" type="button" :class="[admBtnDangerGhost, 'sm:mr-auto']" :disabled="busy" @click="emit('remove')"><Trash2 aria-hidden="true" />Eliminar…</button>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="submit" form="source-form" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar</button>
    </template>
  </AdminModal>
</template>
