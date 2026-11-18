<script setup lang="ts">
import { GitCompareArrows, TriangleAlert } from 'lucide-vue-next'

/** Violet band under the header while a published article has unpublished changes (D23). */
const props = withDefaults(defineProps<{ count: number; since: string; conflict: boolean; published?: string }>(), { published: 'Este artículo está publicado' })
defineEmits<{ view: []; discard: []; reload: [] }>()
const link = 'inline-flex items-center font-medium underline underline-offset-2 min-h-6 max-md:min-h-11'
/** Violet is exclusive to unpublished changes: with none, the band is neutral. */
const tone = computed(() => (props.count ? 'border-adm-st-rev-line bg-adm-st-rev-bg text-adm-st-rev' : 'border-adm-line bg-adm-subtle text-adm-meta'))
</script>

<template>
  <div class="flex flex-wrap items-center gap-x-4 gap-y-1 border-b px-4 py-2.5 text-sm" :class="tone" role="status">
    <GitCompareArrows class="size-4 flex-none" aria-hidden="true" />
    <span class="min-w-[220px] flex-1">
      <template v-if="count">Estás editando un <b>borrador de cambios</b>. </template>
      <template v-else>{{ published }}: lo que escribas se guarda como <b>borrador de cambios</b>. </template>
      El sitio sigue mostrando la versión del <AdminTime :iso="since" short /> hasta que publiques.
    </span>
    <span v-if="count" class="flex gap-4">
      <button type="button" :class="link" @click="$emit('view')">Ver {{ count }} {{ count === 1 ? 'cambio' : 'cambios' }}</button>
      <button type="button" :class="[link, 'text-adm-meta hover:text-adm-fg']" @click="$emit('discard')">Descartar</button>
    </span>
    <p v-if="conflict" class="flex w-full items-center gap-2 rounded-md bg-adm-warn-soft px-3 py-2 text-[13px] text-adm-warn" role="alert">
      <TriangleAlert class="size-4 flex-none" aria-hidden="true" />
      <span class="flex-1">Lo publicado cambió mientras editabas (otra pestaña o dispositivo). Tus cambios siguen guardados.</span>
      <button type="button" :class="link" @click="$emit('reload')">Recargar</button>
    </p>
  </div>
</template>
