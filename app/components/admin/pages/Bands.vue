<script setup lang="ts">
import { EyeOff, TriangleAlert } from 'lucide-vue-next'
import type { PageDef } from '~/utils/admin-pages'
import type { PageChecklistItem } from '~/utils/page-form'

/** Bands under the editor header: "sin publicar" (side) and "inglés incompleto" (amber). The violet band of D23 is `AdminEditorChangesBand`. */
defineProps<{ def: PageDef; live: boolean; english: PageChecklistItem | null }>()
defineEmits<{ goto: [target: 'en'] }>()
const band = 'flex flex-wrap items-center gap-x-3 gap-y-1 border-b border-adm-line px-4 py-2.5 text-sm'
</script>

<template>
  <div v-if="!live" :class="[band, 'bg-adm-side']" role="status">
    <EyeOff class="size-4 flex-none text-adm-meta" aria-hidden="true" />
    <span class="min-w-[220px] flex-1">Sin publicar: <span class="font-mono text-xs">{{ def.routeEs }}</span> muestra «Esta página aún no está publicada» y no sale en buscadores<template v-if="def.key === 'transparency'">. Ya la enlazan las fichas, las reseñas y los artículos</template>.</span>
  </div>
  <div v-if="english" :class="[band, 'bg-adm-warn-soft text-adm-warn']" role="status">
    <TriangleAlert class="size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
    <span class="min-w-[220px] flex-1">
      <b>Inglés incompleto:</b> {{ english.hint }}
      {{ live ? `No se pueden publicar los cambios (ni los del español) hasta arreglarlo. ${def.routeEn} sigue con la versión publicada.` : 'No se puede publicar hasta arreglarlo.' }}
      <AdminEditorChecklistLinks :item="english" />
    </span>
    <button v-if="english.key === 'en'" type="button" class="font-medium underline underline-offset-2 max-md:min-h-11" @click="$emit('goto', 'en')">Ir al inglés</button>
  </div>
</template>
