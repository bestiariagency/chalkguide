<script setup lang="ts">
import { Mail, SearchX, UserCheck, UserX } from 'lucide-vue-next'
import type { SubscriberView } from '~/utils/admin-subscribers'

/** Empty states: first time (all views empty), "nobody matches" with the way out, or an empty view. */
defineProps<{ view: SubscriberView; filtered: boolean; search: string; hasChips: boolean; total: number }>()
const emit = defineEmits<{ goto: [view: SubscriberView]; clear: [] }>()
</script>

<template>
  <AdminStateBlock
    v-if="filtered"
    kind="no-results"
    :icon="SearchX"
    :title="search.trim() ? `Nadie coincide con «${search.trim()}»` : 'Nadie coincide con estos filtros'"
    :description="view === 'all' ? 'Puede que ya no exista (supresión RGPD).' : 'Puede que esté en otra vista o que ya no exista (supresión RGPD).'"
  >
    <button v-if="view !== 'all'" type="button" :class="admBtnGhost" @click="emit('goto', 'all')">Buscar en Todos</button>
    <button v-if="hasChips || search.trim()" type="button" :class="admBtnGhost" @click="emit('clear')">Quitar filtros</button>
  </AdminStateBlock>
  <AdminStateBlock v-else-if="view === 'pending' && total" kind="empty" :icon="UserCheck" title="Nadie pendiente de confirmar" />
  <AdminStateBlock v-else-if="view === 'unsubscribed' && total" kind="empty" :icon="UserX" title="Nadie se ha dado de baja" />
  <AdminStateBlock v-else-if="view === 'active' && total" kind="empty" :icon="Mail" title="Aún no hay suscriptores activos" description="Aparecen aquí cuando confirman su email (doble opt-in)." />
  <AdminStateBlock v-else kind="empty" :icon="Mail" title="Aún no hay suscriptores" description="Las altas llegan desde el pie, el inicio, las fichas y los artículos. Cada una guarda su prueba de consentimiento.">
    <NuxtLink to="/" external target="_blank" rel="noopener" :class="admBtnGhost">Ver el formulario en el sitio<span class="sr-only"> (se abre en otra pestaña)</span></NuxtLink>
  </AdminStateBlock>
</template>
