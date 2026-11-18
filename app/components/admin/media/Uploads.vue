<script setup lang="ts">
import { Check, FileX, ImageUp, X } from 'lucide-vue-next'
import type { UploadEntry } from '~/composables/useAdminMediaUpload'
import { formatBytes } from '~/utils/admin-media-library'

/** Drop zone (desktop) and per-file progress list (live region). */
defineProps<{ entries: readonly UploadEntry[]; over: boolean; active: boolean }>()
const emit = defineEmits<{ cancel: [key: number]; dismiss: [key: number]; clear: []; describe: [id: string] }>()

const done = (entries: readonly UploadEntry[]) => entries.filter((e) => e.status === 'done').length
</script>

<template>
  <div :class="['grid gap-4', entries.length && 'lg:grid-cols-[1fr_420px]']">
    <p class="text-xs text-adm-meta md:hidden">«Subir» abre la cámara o la galería del móvil.</p>
    <div
      :class="['hidden flex-col items-center gap-3 rounded-lg border border-dashed p-5 text-center transition-colors motion-reduce:transition-none sm:flex-row sm:text-left md:flex', over ? 'border-adm-acc bg-adm-acc-soft' : 'border-adm-line-strong bg-adm-subtle']"
    >
      <span class="grid size-10 flex-none place-items-center rounded-lg border border-adm-line bg-adm-elev text-adm-meta"><ImageUp class="size-5" aria-hidden="true" /></span>
      <div class="text-sm">
        <p class="font-medium">Suelta imágenes aquí o en cualquier parte de la pantalla</p>
        <p class="mt-0.5 text-xs text-adm-meta">JPG, PNG, WebP, AVIF o GIF · hasta 10 MB · JPG, PNG y WebP se reducen a 2400 px y pierden los datos EXIF y GPS; AVIF y GIF se suben tal cual, con sus metadatos</p>
      </div>
    </div>
    <section v-if="entries.length" class="rounded-lg border border-adm-line bg-adm-elev" aria-labelledby="h-up">
      <div class="flex items-center gap-2 border-b border-adm-line px-4 py-2.5">
        <h2 id="h-up" class="text-sm font-semibold">{{ active ? `Subiendo ${entries.length} ${entries.length === 1 ? 'imagen' : 'imágenes'}` : 'Subidas' }}</h2>
        <span class="ml-auto text-xs text-adm-meta tabular-nums">{{ done(entries) }} de {{ entries.length }}</span>
        <button v-if="!active" type="button" :class="admIconBtn" aria-label="Limpiar lista" @click="emit('clear')"><X aria-hidden="true" /></button>
      </div>
      <ul class="max-h-72 divide-y divide-adm-line overflow-y-auto text-sm" aria-live="polite">
        <li v-for="e in entries" :key="e.key" class="flex items-center gap-3 px-4 py-2.5">
          <span v-if="e.status === 'error'" class="grid size-9 flex-none place-items-center rounded bg-adm-danger-soft text-adm-danger"><FileX class="size-4" aria-hidden="true" /></span>
          <img v-else-if="e.preview" :src="e.preview" alt="" width="36" height="36" class="size-9 flex-none rounded object-cover" :style="{ backgroundColor: e.color }" />
          <div class="min-w-0 flex-1">
            <p class="truncate font-mono text-xs">{{ e.name }}</p>
            <p v-if="e.status === 'error'" class="text-xs text-adm-danger">{{ e.error }}</p>
            <p v-else-if="e.status === 'done'" class="flex items-center gap-1 text-xs text-adm-ok">
              <Check class="size-3.5" aria-hidden="true" />Subida · {{ formatBytes(e.size ?? 0) }}
              <span v-if="e.color" class="size-2.5 rounded-sm ring-1 ring-black/10" :style="{ backgroundColor: e.color }" aria-hidden="true" /><span v-if="e.color" class="font-mono">{{ e.color }}</span>
            </p>
            <p v-else-if="e.status !== 'uploading'" class="text-xs text-adm-meta">{{ e.status === 'queued' ? 'En cola' : 'Optimizando…' }}</p>
            <div v-else class="mt-1.5 h-1.5 overflow-hidden rounded-full bg-adm-subtle" role="progressbar" :aria-valuenow="Math.round(e.progress * 100)" aria-valuemin="0" aria-valuemax="100" :aria-label="`Progreso de ${e.name}`">
              <span class="block h-full bg-adm-acc transition-[width] motion-reduce:transition-none" :style="{ width: `${e.progress * 100}%` }" />
            </div>
          </div>
          <button v-if="e.status === 'done' && e.media && !e.media.alt_es" type="button" :class="[admBtnQuiet, 'md:h-7!']" @click="emit('describe', e.media.id)">Describir</button>
          <button v-if="['queued', 'preparing', 'uploading'].includes(e.status)" type="button" :class="admIconBtn" aria-label="Cancelar subida" @click="emit('cancel', e.key)"><X aria-hidden="true" /></button>
          <button v-else-if="e.status === 'error'" type="button" :class="admIconBtn" aria-label="Quitar de la lista" @click="emit('dismiss', e.key)"><X aria-hidden="true" /></button>
        </li>
      </ul>
    </section>
  </div>
</template>
