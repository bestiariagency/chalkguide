<script setup lang="ts">
import type { ReviewCounts } from '~/utils/admin-import-report'

/**
 * Sticky bar of the review (README §13.3). With errors the primary is "Subir el archivo corregido" and importing the
 * clean rows is secondary; without errors it is the other way round. If everything is "Sin cambios", importing is off and says why.
 */
const props = defineProps<{ counts: ReviewCounts; nouns: string }>()
defineEmits<{ import: []; 'import-clean': []; again: [] }>()
const write = computed(() => props.counts.created + props.counts.changed)
</script>

<template>
  <div class="sticky bottom-0 z-20 -mx-4 border-t border-adm-line bg-adm-elev px-4 py-3 shadow-[0_-6px_16px_-12px_rgb(0_0_0/0.25)] md:-mx-6 md:px-6">
    <div class="mx-auto flex max-w-[1440px] flex-wrap items-center gap-x-4 gap-y-2">
      <p class="text-[13px]" role="status" aria-live="polite">
        <b class="tabular-nums">{{ write }}</b> {{ write === 1 ? 'fila se escribirá' : 'filas se escribirán' }}
        <template v-if="counts.errors"> · <span class="text-adm-danger tabular-nums">{{ counts.errors }}</span> con error {{ counts.errors === 1 ? 'queda fuera' : 'quedan fuera' }}</template>
        · nada se publica
        <span v-if="write === 0 && !counts.errors" class="block text-adm-meta">Todo está igual que en el panel: no hay nada que importar.</span>
      </p>
      <div class="ml-auto flex flex-wrap items-center gap-2">
        <template v-if="counts.errors">
          <button type="button" :class="admBtnGhost" :disabled="write === 0" @click="$emit('import-clean')">Importar sin las {{ counts.errors }} con error…</button>
          <button type="button" :class="admBtnPrimary" @click="$emit('again')">Subir el archivo corregido</button>
        </template>
        <template v-else>
          <button type="button" :class="admBtnGhost" @click="$emit('again')">Subir otro archivo</button>
          <button type="button" :class="admBtnPrimary" :disabled="write === 0" @click="$emit('import')">Importar {{ write }} {{ nouns }}…</button>
        </template>
      </div>
    </div>
  </div>
</template>
