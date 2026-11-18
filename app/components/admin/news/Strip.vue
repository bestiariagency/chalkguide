<script setup lang="ts">
import { Bot, CircleAlert } from 'lucide-vue-next'
import type { NewsSummary } from '~/utils/admin-news'

/** Under the title: the last collection (new and duplicated), the next one and the link to Ingesta. When the health fails it becomes a red banner. */
const props = defineProps<{ summary?: NewsSummary }>()
const run = computed(() => props.summary?.lastRun)
const failing = computed(() => props.summary?.health?.ok === false)
const next = computed(() => runLabel(nextRunAt()))
</script>

<template>
  <div v-if="summary">
    <AdminBanner v-if="failing" kind="err" class="mx-4 my-2 md:mx-6" :icon="CircleAlert">
      <b class="font-medium">La rutina de novedades no está recogiendo.</b> Mira el motivo y qué hacer en <NuxtLink :to="adminPath('ingesta')" class="underline underline-offset-2">Ingesta</NuxtLink>.
    </AdminBanner>
    <div v-else class="flex flex-wrap items-center gap-x-3 gap-y-1 border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta md:px-6">
      <span><Bot class="-mt-0.5 mr-1 inline size-3.5" aria-hidden="true" /><template v-if="run">Última recogida: <b class="font-medium text-adm-fg">{{ runLabel(run.startedAt) }}</b> · {{ run.insertedNews }} {{ run.insertedNews === 1 ? 'nueva' : 'nuevas' }} · {{ run.duplicates }} {{ run.duplicates === 1 ? 'duplicada' : 'duplicadas' }}</template><template v-else>Todavía no hay ninguna recogida.</template></span>
      <span class="hidden sm:inline">Próxima: {{ next }}</span>
      <NuxtLink :to="adminPath('ingesta')" class="underline underline-offset-2 hover:text-adm-fg sm:ml-auto">Ver en Ingesta</NuxtLink>
    </div>
  </div>
</template>
