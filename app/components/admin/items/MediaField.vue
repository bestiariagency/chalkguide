<script setup lang="ts">
import { ImageOff } from 'lucide-vue-next'
import type { AdminMedia } from '~/utils/admin-media'

/** One image of the ficha (cover, share image): thumbnail, colour, alt state and Cambiar / Quitar. */
defineProps<{ label: string; media: AdminMedia | null; required?: boolean; changed?: boolean; help?: string }>()
defineEmits<{ change: []; remove: [] }>()
const mediaUrl = useMediaUrl()
const id = useId()
</script>

<template>
  <div :class="changedBar(!!changed)">
    <p :id="id" class="mb-1.5 text-xs font-medium">{{ label }}<span v-if="required" class="text-adm-danger" aria-hidden="true"> *</span><span v-if="changed" class="sr-only"> (cambiada)</span></p>
    <div class="flex items-center gap-3" role="group" :aria-labelledby="id">
      <NuxtImg v-if="media" :src="mediaUrl(media.storage_path)" alt="" width="112" height="72" loading="lazy" class="h-[72px] w-28 flex-none rounded-md object-cover" :style="{ backgroundColor: media.dominant_color ?? undefined }" />
      <span v-else class="grid h-[72px] w-28 flex-none place-items-center rounded-md border border-dashed border-adm-line-strong text-adm-muted"><ImageOff class="size-5" aria-hidden="true" /><span class="sr-only">Sin imagen</span></span>
      <div class="min-w-0 text-xs text-adm-meta">
        <template v-if="media">
          <p class="truncate font-mono text-adm-fg">{{ media.original_filename }}</p>
          <p class="mt-1 flex flex-wrap items-center gap-1.5">
            <template v-if="media.dominant_color"><span class="size-3 rounded-sm border border-adm-line-strong" :style="{ backgroundColor: media.dominant_color }" aria-hidden="true" /><span class="font-mono">{{ media.dominant_color }}</span> ·</template>
            <span>Texto alternativo:</span>
            <span :class="media.alt_es?.trim() ? '' : 'text-adm-warn'">ES: {{ media.alt_es?.trim() ? 'sí' : 'no' }}</span> ·
            <span>EN: {{ media.alt_en?.trim() ? 'sí' : 'no' }}</span>
          </p>
        </template>
        <p v-else-if="help">{{ help }}</p>
        <div class="mt-2 flex gap-2">
          <button type="button" :class="[admBtnGhost, 'h-7 text-xs max-md:h-11']" @click="$emit('change')">{{ media ? 'Cambiar' : 'Elegir imagen' }}</button>
          <button v-if="media" type="button" :class="[admBtnQuiet, 'h-7 text-xs max-md:h-11']" @click="$emit('remove')">Quitar</button>
        </div>
      </div>
    </div>
  </div>
</template>
