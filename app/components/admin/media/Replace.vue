<script setup lang="ts">
import { ArrowRight, ImageUp, Loader2, TriangleAlert } from 'lucide-vue-next'
import { formatBytes, hasAlt, MEDIA_ACCEPT, type AdminMediaItem } from '~/utils/admin-media-library'

/** Replace the file: before → after, texts are kept. The new URL avoids stale caches. */
const props = defineProps<{ media: AdminMediaItem }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ replaced: [item: AdminMediaItem] }>()

const mediaUrl = useMediaUrl()
const r = useAdminMediaReplace((item) => {
  emit('replaced', item)
  open.value = false
})
const uses = computed(() => props.media.usage_count)
const onPick = (e: Event) => r.choose((e.target as HTMLInputElement).files?.[0])
const inputId = `rep-${useId()}`
const fileName = ref('')
const onChange = (e: Event) => {
  fileName.value = (e.target as HTMLInputElement).files?.[0]?.name ?? ''
  onPick(e)
}
</script>

<template>
  <AdminModal
    v-model:open="open"
    size="md"
    stacked
    :busy="r.busy.value"
    :title="`Reemplazar «${media.original_filename}»`"
    :description="`${uses ? `Se actualiza ${uses === 1 ? 'en el sitio donde se usa' : `en los ${uses} sitios donde se usa`}. ` : ''}El texto alternativo, el pie y el crédito se mantienen; el archivo nuevo tiene otra URL, así que no se verá la versión antigua por la caché.`"
  >
    <div class="mb-4">
      <span class="mb-1.5 block text-xs font-medium">Imagen nueva</span>
      <div class="flex items-center gap-3">
        <label :class="[admBtnGhost, 'cursor-pointer has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-adm-acc', r.busy.value && 'pointer-events-none opacity-50']">
          <ImageUp aria-hidden="true" />Elegir imagen…
          <input :id="inputId" type="file" :accept="MEDIA_ACCEPT" class="sr-only" data-autofocus :disabled="r.busy.value" @change="onChange" />
        </label>
        <span class="min-w-0 flex-1 truncate font-mono text-xs text-adm-meta" aria-live="polite">{{ fileName || 'Ningún archivo' }}</span>
      </div>
      <p v-if="r.error.value" class="mt-1.5 text-xs text-adm-danger" role="alert">{{ r.error.value }}</p>
    </div>
    <div class="grid grid-cols-[1fr_auto_1fr] items-center gap-3">
      <figure>
        <div class="aspect-[3/2] overflow-hidden rounded-md bg-adm-subtle" :style="{ backgroundColor: media.dominant_color ?? undefined }">
          <NuxtImg :src="mediaUrl(media.storage_path)" alt="Imagen actual" width="320" height="213" class="size-full object-cover opacity-80" />
        </div>
        <figcaption class="mt-1.5 text-xs text-adm-meta">Ahora · v{{ media.version }}<template v-if="media.dominant_color"> · <span class="font-mono">{{ media.dominant_color }}</span></template></figcaption>
      </figure>
      <ArrowRight class="size-5 text-adm-muted" aria-hidden="true" />
      <figure>
        <img v-if="r.preview.value" :src="r.preview.value" alt="Imagen nueva" width="320" height="213" class="aspect-[3/2] w-full rounded-md object-cover" />
        <div v-else class="grid aspect-[3/2] place-items-center rounded-md border border-dashed border-adm-line-strong bg-adm-subtle px-2 text-center text-xs text-adm-muted">Elige un archivo</div>
        <figcaption class="mt-1.5 text-xs text-adm-meta">
          <template v-if="r.prepared.value">Nueva · v{{ media.version + 1 }} · <span class="font-mono">{{ r.prepared.value.color }}</span> · {{ r.prepared.value.width }} × {{ r.prepared.value.height }} · {{ formatBytes(r.prepared.value.blob.size) }}</template>
          <template v-else>Nueva</template>
        </figcaption>
      </figure>
    </div>
    <div v-if="r.prepared.value && hasAlt(media)" class="mt-4 flex gap-2 rounded-lg bg-adm-warn-soft p-3 text-sm text-adm-fg">
      <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
      <span>Revisa que el texto alternativo siga describiendo la imagen nueva.</span>
    </div>
    <div v-if="r.busy.value" class="mt-4 h-1.5 overflow-hidden rounded-full bg-adm-subtle" role="progressbar" :aria-valuenow="Math.round(r.progress.value * 100)" aria-valuemin="0" aria-valuemax="100" aria-label="Progreso de la subida">
      <span class="block h-full bg-adm-acc transition-[width]" :style="{ width: `${r.progress.value * 100}%` }" />
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="r.busy.value" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnPrimary" :disabled="!r.prepared.value || r.busy.value" :aria-busy="r.busy.value || undefined" @click="r.confirm(media)">
        <Loader2 v-if="r.busy.value" class="animate-adm-spin" aria-hidden="true" />{{ uses ? `Reemplazar en ${uses} ${uses === 1 ? 'sitio' : 'sitios'}` : 'Reemplazar' }}
      </button>
    </template>
  </AdminModal>
</template>
