<script setup lang="ts">
import { Monitor } from 'lucide-vue-next'
import type { ImportBatchInfo } from '~/services/admin/import'
import type { ItemInfo } from '~/utils/item-spec'

/** Under 768 importing is not offered (README §13.8): explains why and leaves the quick tasks that do work on a phone. */
defineProps<{ info: ItemInfo; last?: ImportBatchInfo | null }>()
</script>

<template>
  <AdminStateBlock kind="empty" title="Importar se hace en un ordenador" description="Revisar decenas de filas y corregir el Excel pide una pantalla grande. Desde el móvil puedes asignar portadas y publicar las fichas que ya están listas." :icon="Monitor">
    <p v-if="last" class="w-full text-[13px] text-adm-meta">Última importación: <AdminTime :iso="last.createdAt" /> · {{ countOf(last.rowCount, 'fila', 'filas') }}.</p>
    <NuxtLink :to="`${adminPath(info.route)}?importacion=hoy`" :class="[admBtnPrimary, 'w-full']">Ver las fichas importadas</NuxtLink>
    <NuxtLink :to="`${adminPath(info.route)}?importacion=hoy&asignar=portadas`" :class="[admBtnGhost, 'w-full']">Asignar portadas</NuxtLink>
  </AdminStateBlock>
</template>
