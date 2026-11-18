<script setup lang="ts">
import { TRI_FIELDS, type GymForm } from '~/utils/gym-fields'
import type { ItemErrors } from '~/utils/item-patch'

/** Instalaciones: figures and the Sí / No / No lo sé list ("no lo sé" is not "no": it is not shown). */
const props = defineProps<{ errors: ItemErrors; changed: string[] }>()
const form = defineModel<GymForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const OPTIONS = [
  { value: true, label: 'Sí' },
  { value: false, label: 'No' },
  { value: null, label: 'No lo sé' },
] as const
const uid = useId()
</script>

<template>
  <div>
    <AdminItemsSection title="Cifras">
      <div class="grid grid-cols-2 gap-4 lg:grid-cols-5">
        <div :class="bar('surface_m2')"><AdminTextField v-model="form.surface_m2" label="Superficie" suffix="m²" inputmode="numeric" :error="errors.surface_m2" /></div>
        <div :class="bar('max_height_m')"><AdminTextField v-model="form.max_height_m" label="Altura máx." suffix="m" inputmode="decimal" :error="errors.max_height_m" /></div>
        <div :class="bar('routes_count')"><AdminTextField v-model="form.routes_count" label="Vías" inputmode="numeric" :error="errors.routes_count" /></div>
        <div :class="bar('autobelays_count')"><AdminTextField v-model="form.autobelays_count" label="Autobelays" inputmode="numeric" :error="errors.autobelays_count" /></div>
        <div :class="bar('kids_min_age')"><AdminTextField v-model="form.kids_min_age" label="Edad mín. niños" suffix="años" inputmode="numeric" :error="errors.kids_min_age" /></div>
      </div>
    </AdminItemsSection>
    <AdminItemsSection title="Qué tiene" description="Sí, No o No lo sé. Lo que no sabes no sale en la ficha (no es lo mismo que «No»).">
      <ul class="divide-y divide-adm-line rounded-lg border border-adm-line bg-adm-elev px-4">
        <li v-for="[id, label] in TRI_FIELDS" :key="id" :class="['flex min-h-11 flex-wrap items-center gap-x-3 gap-y-1 py-1.5', bar(id)]">
          <span :id="`${uid}-${id}`" class="flex-1 text-sm">{{ label }}<span v-if="changed.includes(id)" class="sr-only"> (cambiado)</span></span>
          <AdminSegmented v-model="form[id]" :options="OPTIONS" :labelledby="`${uid}-${id}`" />
        </li>
      </ul>
    </AdminItemsSection>
  </div>
</template>
