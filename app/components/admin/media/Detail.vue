<script setup lang="ts">
import { ExternalLink, Loader2, Replace, Trash2 } from 'lucide-vue-next'
import {
  formatBytes,
  formToMediaPatch,
  mediaFormatLabel,
  mediaToForm,
  MEDIA_LIMITS,
  validateMediaForm,
  type AdminMediaItem,
  type MediaErrors,
  type MediaForm,
  type MediaUsageRow,
} from '~/utils/admin-media-library'

/** Detail drawer (bottom sheet on mobile): preview, file data, ES/EN texts, credit, colour and usage. */
const props = defineProps<{ media: AdminMediaItem; usage: readonly MediaUsageRow[]; usageStatus: 'idle' | 'pending' | 'error'; busy: boolean; focusAlt?: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ save: [form: MediaForm]; replace: []; remove: [] }>()

const mediaUrl = useMediaUrl()
const url = computed(() => mediaUrl(props.media.storage_path))
const form = reactive<MediaForm>(mediaToForm(props.media))
const errors = ref<MediaErrors>({})
const color = useMediaDominantColor()

// A replacement changes the file (and its colour) but keeps what is being typed.
watch(() => props.media.version, () => (form.dominant_color = props.media.dominant_color ?? ''))
async function recalc() {
  const hex = await color.compute(url.value)
  if (hex) form.dominant_color = hex
}
function submit() {
  errors.value = validateMediaForm(form)
  if (Object.keys(errors.value).length) return
  emit('save', { ...form })
}
const dirty = computed(() => JSON.stringify(formToMediaPatch(form)) !== JSON.stringify(formToMediaPatch(mediaToForm(props.media))))
const inUse = computed(() => props.usage.length > 0 || props.media.usage_count > 0)
const uses = computed(() => props.usage.length || props.media.usage_count)
const checking = computed(() => props.usageStatus !== 'idle')
const date = (iso: string) => adminDate(iso)
const altMissing = computed(() => !form.alt_es.trim())
</script>

<template>
  <AdminModal v-model:open="open" :title="media.original_filename" placement="right" :busy="busy">
    <form id="media-form" class="space-y-5" novalidate @submit.prevent="submit">
      <div class="aspect-[3/2] overflow-hidden rounded-lg bg-adm-subtle" :style="{ backgroundColor: media.dominant_color ?? undefined }">
        <NuxtImg :src="url" :alt="`Vista previa de ${media.original_filename}`" width="440" height="293" class="size-full object-cover" />
      </div>
      <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-xs">
        <dt class="text-adm-meta">Tamaño</dt>
        <dd class="tabular-nums">{{ media.width && media.height ? `${media.width} × ${media.height} · ` : '' }}{{ formatBytes(media.size_bytes) }} · {{ mediaFormatLabel(media.mime_type) }} · v{{ media.version }}</dd>
        <dt class="text-adm-meta">Subida</dt>
        <dd>{{ date(media.created_at) }}<template v-if="media.version > 1"> · reemplazada {{ date(media.updated_at) }}</template></dd>
      </dl>
      <AdminMediaColor v-model="form.dominant_color" :error="errors.dominant_color" :busy="color.busy.value" @recalc="recalc" />
      <div class="space-y-3">
        <AdminLangPair legend="Texto alternativo">
          <template #es><AdminTextArea v-model="form.alt_es" label="Texto alternativo" lang="ES" :rows="2" :max="MEDIA_LIMITS.alt" :ideal="MEDIA_LIMITS.altIdeal" :error="errors.alt_es" :data-autofocus="focusAlt ? '' : undefined" /></template>
          <template #en><AdminTextArea v-model="form.alt_en" label="Texto alternativo" lang="EN" :rows="2" :max="MEDIA_LIMITS.alt" :ideal="MEDIA_LIMITS.altIdeal" placeholder="Opcional hasta traducir" :error="errors.alt_en" /></template>
        </AdminLangPair>
        <p :class="['text-xs', altMissing ? 'text-adm-warn' : 'text-adm-meta']">Describe lo que se ve, sin empezar por «foto de» o «imagen de». Sin texto alternativo en español no se puede usar en contenido publicado.</p>
      </div>
      <AdminLangPair legend="Pie de foto">
        <template #es><AdminTextField v-model="form.caption_es" label="Pie de foto" lang="ES" :max="MEDIA_LIMITS.caption" :error="errors.caption_es" /></template>
        <template #en><AdminTextField v-model="form.caption_en" label="Pie de foto" lang="EN" placeholder="Opcional" :max="MEDIA_LIMITS.caption" :error="errors.caption_en" /></template>
      </AdminLangPair>
      <AdminTextField v-model="form.credit" label="Crédito" placeholder="Foto: …" :max="MEDIA_LIMITS.credit" :error="errors.credit" />
      <AdminMediaUsage :rows="usage" :status="usageStatus" />
    </form>
    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="emit('replace')"><Replace aria-hidden="true" />Reemplazar…</button>
      <a :class="admBtnQuiet" :href="url" target="_blank" rel="noopener"><ExternalLink aria-hidden="true" /><span class="max-sm:sr-only">Abrir original</span></a>
      <button type="button" :class="[admBtnDangerGhost, 'sm:mr-auto']" :aria-disabled="inUse || checking || undefined" :aria-describedby="inUse ? 'nodel' : undefined" :disabled="busy" @click="emit('remove')">
        <Trash2 aria-hidden="true" />Eliminar
      </button>
      <p v-if="inUse" id="nodel" class="w-full text-left text-xs text-adm-meta">No se puede eliminar: está en uso en {{ uses }} {{ uses === 1 ? 'sitio' : 'sitios' }}.</p>
      <button type="submit" form="media-form" :class="[admBtnPrimary, 'max-sm:w-full']" :disabled="busy || !dirty" :aria-busy="busy || undefined">
        <Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar
      </button>
    </template>
  </AdminModal>
</template>
