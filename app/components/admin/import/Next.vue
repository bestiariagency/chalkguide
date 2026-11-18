<script setup lang="ts">
import { Download, FileUp, GitBranch, ImageOff, Send } from 'lucide-vue-next'
import type { ImportOutcome } from '~/composables/useAdminImport'
import type { ImportTotals } from '~/utils/admin-import-report'

/** "Y ahora" (README §13.5): one card per action. Covers and batch publishing open from the list filtered on this import. */
const props = defineProps<{ totals: ImportTotals; excluded: number; route: string; outcome?: ImportOutcome }>()
defineEmits<{ errors: []; again: [] }>()
const filtered = (extra: string) => `${props.route}?importacion=hoy&${extra}`
</script>

<template>
  <section class="grid gap-2" aria-labelledby="import-next">
    <h3 id="import-next" class="text-sm font-semibold">Y ahora</h3>
    <div v-if="totals.withoutCover" class="flex items-start gap-3 rounded-lg border border-adm-line bg-adm-elev px-4 py-3.5">
      <span class="grid size-8 flex-none place-items-center rounded-lg bg-adm-warn-soft text-adm-warn"><ImageOff class="size-4" aria-hidden="true" /></span>
      <div class="min-w-0 flex-1 text-[13px]">
        <p class="font-medium">{{ totals.withoutCover }} {{ totals.withoutCover === 1 ? 'ficha sin portada' : 'fichas sin portada' }}</p>
        <p class="text-adm-meta">Sube las fotos a Medios con el nombre que tienen en el archivo y vuelve a subir el mismo archivo: las enlaza y el resto sale «Sin cambios». O asígnalas a mano.</p>
      </div>
      <div class="flex flex-wrap justify-end gap-2">
        <a :href="adminPath('medios')" target="_blank" rel="noopener" :class="admBtnGhost">Abrir Medios<span class="sr-only"> (pestaña nueva)</span> ↗</a>
        <NuxtLink :to="filtered('asignar=portadas')" :class="admBtnGhost">Asignar a mano</NuxtLink>
      </div>
    </div>
    <div v-if="totals.ready" class="flex items-start gap-3 rounded-lg border border-adm-line bg-adm-elev px-4 py-3.5">
      <span class="grid size-8 flex-none place-items-center rounded-lg bg-adm-ok-soft text-adm-ok"><Send class="size-4" aria-hidden="true" /></span>
      <div class="min-w-0 flex-1 text-[13px]">
        <p class="font-medium">{{ totals.ready }} {{ totals.ready === 1 ? 'lista para publicar' : 'listas para publicar' }}</p>
        <p class="text-adm-meta">Nada las bloquea. Las ves antes de publicar.</p>
      </div>
      <NuxtLink :to="filtered('publicar=1')" :class="outcome && outcome !== 'done' ? admBtnGhost : admBtnPrimary">Publicar las listas…</NuxtLink>
    </div>
    <div v-if="totals.drafted" class="flex items-start gap-3 rounded-lg border border-adm-line bg-adm-elev px-4 py-3.5">
      <span class="grid size-8 flex-none place-items-center rounded-lg bg-adm-st-rev-bg text-adm-st-rev"><GitBranch class="size-4" aria-hidden="true" /></span>
      <div class="min-w-0 flex-1 text-[13px]">
        <p class="font-medium">{{ totals.drafted }} {{ totals.drafted === 1 ? 'publicada con cambios' : 'publicadas con cambios' }}</p>
        <p class="text-adm-meta">Se publican una a una, con su diff.</p>
      </div>
      <NuxtLink :to="`${route}#cambios`" :class="admBtnGhost">Ver con cambios</NuxtLink>
    </div>
    <div v-if="excluded" class="flex items-start gap-3 rounded-lg border border-adm-line bg-adm-elev px-4 py-3.5">
      <span class="grid size-8 flex-none place-items-center rounded-lg bg-adm-danger-soft text-adm-danger"><Download class="size-4" aria-hidden="true" /></span>
      <div class="min-w-0 flex-1 text-[13px]">
        <p class="font-medium">{{ excluded }} {{ excluded === 1 ? 'fila quedó fuera' : 'filas quedaron fuera' }}</p>
        <p class="text-adm-meta">Descarga los errores, corrige el archivo y súbelo de nuevo.</p>
      </div>
      <div class="flex flex-wrap justify-end gap-2">
        <button type="button" :class="admBtnGhost" @click="$emit('errors')">Descargar errores</button>
        <button type="button" :class="admBtnGhost" @click="$emit('again')"><FileUp aria-hidden="true" />Subir corregido</button>
      </div>
    </div>
    <NuxtLink :to="`${route}?importacion=hoy`" :class="[admBtnGhost, 'w-fit']">Ver las fichas importadas</NuxtLink>
  </section>
</template>
