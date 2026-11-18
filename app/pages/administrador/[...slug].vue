<script setup lang="ts">
import { Hammer, MapPinOff } from 'lucide-vue-next'

/**
 * Catch-all of the panel. A menu destination that is not built yet (Estadísticas) shows an honest "todavía no existe" screen with the normal shell; any other path is a
 * 404 INSIDE the panel (not the public one) with the way back to Inicio. Nested paths such as
 * /administrador/articulos/x/y are 404 too: only exact menu slugs count.
 */
definePageMeta({ layout: 'admin', i18n: false })

const route = useRoute()
const segments = computed(() => {
  const param = route.params.slug
  return (Array.isArray(param) ? param : [param ?? '']).filter(Boolean)
})
const label = computed(() => (segments.value.length === 1 ? adminLabelFor(segments.value[0]!) : undefined))

const WHAT: Record<string, string> = {
  estadisticas: 'Aquí verás visitas, altas y lectura de los artículos. No hay fecha prevista. Mientras tanto, Inicio resume los últimos 30 días.',
}

useAdminHead(() => label.value ?? 'Página no encontrada')
</script>

<template>
  <div>
    <AdminPageBar title="Panel" desktop-only />
    <div class="px-4 py-6 md:px-6">
      <h1 class="text-xl leading-7 font-semibold tracking-tight">{{ label ?? 'Página no encontrada' }}</h1>
      <AdminStateBlock
        v-if="label"
        class="mt-6"
        kind="empty"
        :icon="Hammer"
        title="Todavía no existe"
        :description="WHAT[segments[0]!] ?? 'Esta sección todavía no está construida.'"
      >
        <NuxtLink :to="adminPath('')" :class="admBtnGhost">Volver a Inicio</NuxtLink>
      </AdminStateBlock>
      <AdminStateBlock
        v-else
        class="mt-6"
        kind="empty"
        :icon="MapPinOff"
        title="Esta dirección no existe"
        description="Puede que el enlace esté mal escrito o que la página se haya movido."
      >
        <NuxtLink :to="adminPath('')" :class="admBtnPrimary">Ir a Inicio</NuxtLink>
      </AdminStateBlock>
    </div>
  </div>
</template>
