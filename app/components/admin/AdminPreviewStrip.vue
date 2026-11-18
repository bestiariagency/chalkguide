<script setup lang="ts">
import { ArrowLeft, Eye } from 'lucide-vue-next'

/** Sticky "no publicado" strip of the two preview pages: back to the editor, state label and ES/EN switch. */
defineProps<{
  back: string
  label: string
  /** Violet is only for unpublished changes; the other states are neutral. */
  changes: boolean
  lang: 'es' | 'en'
  other: 'es' | 'en'
}>()

const linkTarget = 'inline-flex min-h-11 items-center px-3 md:min-h-0 md:px-2'
</script>

<template>
  <div
    class="admin sticky top-0 z-50 flex flex-wrap items-center gap-x-3 gap-y-1 border-b px-3 py-2 font-sans text-sm"
    :class="changes ? 'border-adm-st-rev-line bg-adm-st-rev-bg text-adm-st-rev' : 'border-adm-line bg-adm-subtle text-adm-meta'">
    <NuxtLink :to="{ path: back }" :class="[admBtnGhost, 'flex-none']"><ArrowLeft aria-hidden="true" />Volver al editor</NuxtLink>
    <p class="flex min-w-0 flex-1 items-center gap-2">
      <Eye class="size-4 flex-none" aria-hidden="true" />
      <b>{{ label }}</b>
    </p>
    <nav aria-label="Idioma de la vista previa" class="flex gap-1">
      <span :class="[linkTarget, 'rounded bg-adm-elev py-1 text-[13px] font-medium']" aria-current="page">{{ lang.toUpperCase() }}</span>
      <NuxtLink :to="{ path: $route.path, query: { lang: other } }" :class="[linkTarget, 'rounded py-1 text-[13px] underline underline-offset-2']">{{ other.toUpperCase() }}</NuxtLink>
    </nav>
  </div>
</template>
