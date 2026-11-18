<script setup lang="ts">
import { Inbox } from 'lucide-vue-next'
import type { NewsView } from '~/utils/admin-news'

/** Empty states of Noticias: al día (Por revisar), nothing yet, and no results with filters. */
defineProps<{ view: NewsView; filtered: boolean; search: string; total: number }>()
const emit = defineEmits<{ goto: [view: NewsView]; create: []; clear: [] }>()
const next = runLabel(nextRunAt())
</script>

<template>
  <AdminStateBlock v-if="filtered" kind="no-results" :description="search ? `Nada coincide con «${search}». Prueba con otra palabra o quita filtros.` : 'Ninguna noticia cumple los filtros. Quítalos para ver el resto.'">
    <button type="button" :class="admBtnGhost" @click="emit('clear')">Quitar filtros</button>
  </AdminStateBlock>
  <AdminStateBlock v-else-if="view === 'revisar' && total > 0" kind="empty" :icon="Inbox" title="Nada por revisar" :description="`Has revisado todo lo que trajo el agente. La próxima recogida es el ${next}.`">
    <button type="button" :class="admBtnGhost" @click="emit('goto', 'publicadas')">Ver publicadas</button>
    <NuxtLink :to="adminPath('ingesta')" :class="admBtnQuiet">Ingesta</NuxtLink>
  </AdminStateBlock>
  <AdminStateBlock v-else kind="empty" title="Todavía no hay noticias" description="Las propone el agente en cada recogida y tú decides cuáles salen. También puedes escribir una a mano.">
    <button type="button" :class="admBtnPrimary" @click="emit('create')">Nueva noticia</button>
  </AdminStateBlock>
</template>
