<script setup lang="ts">
import { Images, UserRound } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'

/**
 * Photo of an author with «Elegir de Medios…» / «Cambiar…» / «Quitar» (README §17.3, §17.5). `portrait`:
 * the 4:5 thumbnail of the site author (Ajustes); `circle`: the 64 px avatar of the drawer. Picking
 * or removing only changes the parent's form; the photo becomes public when the form is saved.
 */
const props = defineProps<{
  media: AdminMedia | null
  name: string
  shape: 'portrait' | 'circle'
  /** Subtitle of the picker (who the photo is for). */
  subtitle: string
  /** Text under the buttons (it is always shown). */
  help: string
  /** Text when there is no photo. */
  emptyHelp: string
  error?: string
  changed?: boolean
  /** `name` of the picking button, to focus it from an error. */
  fieldName?: string
}>()
const emit = defineEmits<{ pick: [media: AdminMedia | null] }>()
const mediaUrl = useMediaUrl()
const picking = ref(false)
const labelId = `photo-${useId()}`
const helpId = `${labelId}-help`
const errorId = `${labelId}-error`
const alt = computed(() => props.media?.alt_es?.trim() || `Foto de ${props.name.trim() || 'el autor'}`)
</script>

<template>
  <div>
    <p :id="labelId" class="mb-1.5 flex items-center gap-1.5 text-xs font-medium text-adm-fg">
      Foto<span v-if="changed" class="text-[11px] font-medium text-adm-st-rev">Sin guardar</span>
    </p>
    <div class="flex items-center gap-4">
      <template v-if="shape === 'portrait'">
        <NuxtImg v-if="media" :src="mediaUrl(media.storage_path)" :alt="alt" width="96" height="120" loading="lazy" class="h-[120px] w-24 flex-none rounded-md border border-adm-line bg-adm-subtle object-cover" :style="{ backgroundColor: media.dominant_color ?? undefined }" />
        <span v-else class="grid h-[120px] w-24 flex-none place-items-center rounded-md border border-dashed border-adm-line-strong bg-adm-subtle text-adm-muted"><UserRound class="size-6" aria-hidden="true" /></span>
      </template>
      <template v-else>
        <AdminAuthorsAvatar :media="media" :name="name" size="lg" />
      </template>
      <div class="min-w-0 space-y-2 text-xs text-adm-meta">
        <p v-if="media" class="truncate font-mono text-adm-fg">{{ media.original_filename }}<span v-if="media.width && media.height" class="block font-sans text-adm-meta">{{ media.width }} × {{ media.height }} px</span></p>
        <div class="flex flex-wrap gap-2">
          <button type="button" :name="fieldName" :aria-describedby="error ? `${labelId} ${helpId} ${errorId}` : `${labelId} ${helpId}`" :aria-invalid="!!error || undefined" :class="[admBtnGhost, 'max-md:min-h-11']" @click="picking = true">
            <Images aria-hidden="true" />{{ media ? 'Cambiar…' : 'Elegir de Medios…' }}
          </button>
          <button v-if="media" type="button" :class="[admBtnQuiet, 'max-md:min-h-11']" @click="emit('pick', null)">Quitar<span class="sr-only"> foto</span></button>
        </div>
      </div>
    </div>
    <p :id="helpId" class="mt-2 text-xs text-adm-meta">{{ media ? help : emptyHelp }}</p>
    <p v-if="error" :id="errorId" class="mt-1.5 text-xs leading-4 text-adm-danger" role="alert">{{ error }}</p>
    <AdminMediaPicker v-model:open="picking" title="Elegir foto de Medios" photo :subtitle="subtitle" @select="emit('pick', $event)" />
  </div>
</template>
