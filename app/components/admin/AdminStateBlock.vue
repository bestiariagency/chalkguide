<script setup lang="ts">
import { FileSearch, FileX2, TriangleAlert } from 'lucide-vue-next'
import type { Component } from 'vue'

/**
 * Empty / no-results / error block. `empty`: first time (give the main `action` slot) or all done
 * (no action); `no-results`: concrete exits (slot); `error`: Retry + optional technical `code`.
 */
const props = defineProps<{
  kind: 'empty' | 'no-results' | 'error'
  title?: string
  description?: string
  icon?: Component
  /** Error: technical code to quote ("PGRST301"). */
  code?: string
  /** Title element: `p` by default (the block has no fixed place in the heading outline). */
  level?: 'p' | 'h2' | 'h3'
}>()
defineEmits<{ retry: [] }>()

const defaults = {
  empty: { title: 'Todavía no hay nada', icon: FileX2 },
  'no-results': { title: 'Sin resultados', icon: FileSearch },
  error: { title: 'No se han podido cargar los datos', icon: TriangleAlert },
}
const shown = computed(() => defaults[props.kind])
</script>

<template>
  <div class="flex flex-col items-center gap-2 px-6 py-12 text-center" :role="kind === 'error' ? 'alert' : 'status'">
    <span :class="['grid size-10 place-items-center rounded-[10px] [&_svg]:size-5', kind === 'error' ? 'bg-adm-danger-soft text-adm-danger' : 'bg-adm-subtle text-adm-meta']">
      <component :is="icon ?? shown.icon" aria-hidden="true" />
    </span>
    <component :is="level ?? 'p'" class="mt-1 text-sm font-semibold">{{ title ?? shown.title }}</component>
    <p v-if="description || kind === 'error'" class="max-w-96 text-[13px] text-adm-meta">
      {{ description ?? 'Comprueba tu conexión e inténtalo de nuevo.' }}
      <span v-if="code" class="mt-1 block font-mono text-xs">Código: {{ code }}</span>
    </p>
    <div class="mt-2 flex flex-wrap justify-center gap-2">
      <button v-if="kind === 'error'" type="button" :class="admBtnGhost" @click="$emit('retry')">Reintentar</button>
      <slot />
    </div>
  </div>
</template>
