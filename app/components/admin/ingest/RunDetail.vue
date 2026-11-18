<script setup lang="ts">
import { TriangleAlert } from 'lucide-vue-next'
import { runErrorLines, runWarnings, type AdminRun } from '~/utils/admin-ingest'

/**
 * Expanded row of a collection, in three columns: what came out (with the links to its news and events), warnings and errors.
 * The errors are the plain text the routine wrote: interpolated line by line, never as HTML (F1).
 */
const props = defineProps<{ run: AdminRun }>()
const warnings = computed(() => runWarnings(props.run))
const errors = computed(() => runErrorLines(props.run))
</script>

<template>
  <div class="grid gap-4 text-xs lg:grid-cols-3">
    <div>
      <p class="text-sm font-medium">Nuevos</p>
      <p v-if="run.dryRun" class="mt-1 text-adm-meta">Es una prueba (dry_run): no escribe nada. Habría creado {{ run.wouldInsert }}.</p>
      <template v-else>
        <p class="mt-1 text-adm-meta">{{ run.insertedNews }} {{ run.insertedNews === 1 ? 'noticia' : 'noticias' }} · {{ run.insertedEvents }} {{ run.insertedEvents === 1 ? 'evento' : 'eventos' }}</p>
        <p class="mt-2 flex flex-wrap gap-x-3 gap-y-1">
          <NuxtLink v-if="run.insertedNews" :to="`${adminPath('noticias')}?recogida=${run.id}&vista=todas`" class="underline underline-offset-2">Ver noticias de esta recogida</NuxtLink>
          <NuxtLink v-if="run.insertedEvents" :to="`${adminPath('agenda')}?recogida=${run.id}&vista=todos`" class="underline underline-offset-2">Ver eventos de esta recogida</NuxtLink>
        </p>
      </template>
    </div>
    <div>
      <p class="text-sm font-medium">Avisos</p>
      <ul v-if="warnings.length" class="mt-1 space-y-1 text-adm-meta">
        <li v-for="w in warnings" :key="w" class="flex gap-1.5"><TriangleAlert class="mt-px size-3.5 flex-none text-adm-warn-icon" aria-hidden="true" />{{ w }}</li>
      </ul>
      <p v-else class="mt-1 text-adm-meta">Ninguno.</p>
    </div>
    <div>
      <p class="text-sm font-medium">Errores</p>
      <ul v-if="errors.length" class="mt-1 space-y-1 text-adm-meta"><li v-for="(e, i) in errors" :key="i" class="font-mono break-words">{{ e }}</li></ul>
      <p v-else class="mt-1 text-adm-meta">Ninguno.</p>
    </div>
  </div>
</template>
