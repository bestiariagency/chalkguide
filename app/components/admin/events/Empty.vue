<script setup lang="ts">
import { CalendarPlus, CircleCheck, History, Inbox, Plus, SearchX } from 'lucide-vue-next'
import type { EventView } from '~/utils/admin-events'

/** Empty states of the Agenda: first time per view, or "nothing with these filters" with the way out. */
defineProps<{ view: EventView; filtered: boolean; search: string; total: number }>()
const emit = defineEmits<{ create: []; goto: [view: EventView]; clear: [] }>()
const next = runLabel(nextRunAt())
</script>

<template>
  <AdminStateBlock
    v-if="filtered"
    kind="no-results"
    :icon="SearchX"
    :title="search.trim() ? `Nada con «${search.trim()}» en esta vista` : 'Nada con estos filtros en esta vista'"
    :description="total ? `Hay ${total} ${total === 1 ? 'evento' : 'eventos'} en total.` : undefined"
  >
    <button v-if="view !== 'todos'" type="button" :class="admBtnGhost" @click="emit('goto', 'todos')">Buscar en todos</button>
    <button type="button" :class="admBtnGhost" @click="emit('clear')">Quitar filtros</button>
  </AdminStateBlock>
  <AdminStateBlock v-else-if="view === 'revisar'" kind="empty" :icon="Inbox" title="Nada por aprobar" :description="`Cuando el agente de novedades encuentre actividades en las webs de los rocódromos, llegarán aquí como borradores. La próxima recogida es el ${next}.`">
    <button type="button" :class="admBtnGhost" @click="emit('goto', 'proximos')">Ver próximos</button>
  </AdminStateBlock>
  <AdminStateBlock v-else-if="view === 'proximos'" kind="empty" :icon="CalendarPlus" title="No hay eventos próximos" description="La agenda del sitio muestra «Pizarra limpia» mientras no haya nada aprobado.">
    <button type="button" :class="admBtnPrimary" @click="emit('create')"><Plus aria-hidden="true" />Nuevo evento</button>
  </AdminStateBlock>
  <AdminStateBlock v-else-if="view === 'pasados'" kind="empty" :icon="History" title="Aún no hay eventos pasados" />
  <AdminStateBlock v-else-if="view === 'descartados'" kind="empty" :icon="CircleCheck" title="No has descartado nada" description="Los descartados se guardan para que el agente no los vuelva a proponer." />
  <AdminStateBlock v-else kind="empty" :icon="CalendarPlus" title="La agenda está vacía" description="Crea el primer evento o espera a las propuestas del agente.">
    <button type="button" :class="admBtnPrimary" @click="emit('create')"><Plus aria-hidden="true" />Nuevo evento</button>
  </AdminStateBlock>
</template>
