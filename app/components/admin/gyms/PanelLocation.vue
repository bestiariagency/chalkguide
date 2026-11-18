<script setup lang="ts">
import type { GymForm } from '~/utils/gym-fields'
import type { ItemErrors } from '~/utils/item-patch'

/** Ubicación y horarios: the shared address and contact, plus metro stops and the weekly schedule. */
const props = defineProps<{ errors: ItemErrors; changed: string[] }>()
const form = defineModel<GymForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
</script>

<template>
  <div>
    <AdminItemsAddress v-model:form="form" :errors="errors" :changed="changed" district-help="Sale en la tarjeta: «Cuerda · Gràcia».">
      <template #address>
        <div :class="bar('metro_stations')"><AdminItemsChipsField v-model="form.metro_stations" label="Paradas de metro" help="Formato «Estación (línea)». La primera sale en la tarjeta." /></div>
      </template>
    </AdminItemsAddress>

    <AdminItemsSection>
      <div :class="bar('opening_hours')"><AdminGymsHoursEditor v-model="form.opening_hours" :errors="errors" /></div>
      <div class="grid gap-4 lg:grid-cols-2">
        <div :class="bar('opening_hours_note_es')"><AdminTextField v-model="form.opening_hours_note_es" label="Nota de horario" lang="ES" placeholder="En agosto cierra a las 21:00…" /></div>
        <div :class="bar('opening_hours_note_en')"><AdminTextField v-model="form.opening_hours_note_en" label="Nota de horario" lang="EN" placeholder="Opcional" /></div>
      </div>
    </AdminItemsSection>
  </div>
</template>
