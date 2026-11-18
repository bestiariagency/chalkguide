<script setup lang="ts">
import type { ItemErrors } from '~/utils/item-patch'
import { SHOE_ASYMMETRY, SHOE_CLOSURE, SHOE_FIT, SHOE_LEVEL, SHOE_PROFILE, SHOE_STIFFNESS, SHOE_USE, shoeOptions, type ShoeForm } from '~/utils/shoe-fields'

/** Technical sheet: brand and model (required to publish), fit, profile, asymmetry, closure, rubber, stiffness, use and level. */
const props = defineProps<{ errors: ItemErrors; changed: string[] }>()
const form = defineModel<ShoeForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const uid = useId()
const clearLink = 'mt-1.5 block min-h-6 rounded text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11'
const UNSET = '__unset'
const STIFFNESS = SHOE_STIFFNESS.map(([value, sub]) => ({ value: value as number | null, label: String(value), sub }))
const ASYMMETRY = [...shoeOptions(SHOE_ASYMMETRY), { value: UNSET, label: 'Sin dato' }]
/** The select has no empty value: «Sin dato» stands for the empty column. */
const asymmetry = computed({
  get: () => form.value.asymmetry || UNSET,
  set: (value: string | undefined) => (form.value.asymmetry = !value || value === UNSET ? '' : value),
})
</script>

<template>
  <div>
    <AdminItemsSection title="Modelo" description="La marca y el modelo identifican el pie de gato: no puede haber dos iguales. Son obligatorios para publicar.">
      <div class="grid gap-4 sm:grid-cols-2">
        <div :class="bar('brand')"><AdminTextField v-model="form.brand" label="Marca" required :max="60" :error="errors.brand" autocomplete="off" /></div>
        <div :class="bar('model')"><AdminTextField v-model="form.model" label="Modelo" required :max="80" :error="errors.model" autocomplete="off" /></div>
      </div>
      <div :class="bar('fit')">
        <p :id="`${uid}-fit`" class="mb-1.5 text-xs font-medium">Horma</p>
        <AdminSegmented v-model="form.fit" :options="shoeOptions(SHOE_FIT)" :labelledby="`${uid}-fit`" />
      </div>
    </AdminItemsSection>

    <AdminItemsSection title="Forma y cierre" description="Lo que dejes sin dato no se muestra en la ficha ni filtra en el comparador.">
      <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <div :class="bar('profile')">
          <p :id="`${uid}-profile`" class="mb-1.5 text-xs font-medium">Perfil</p>
          <AdminSegmented v-model="form.profile" :options="shoeOptions(SHOE_PROFILE)" :labelledby="`${uid}-profile`" />
          <button v-if="form.profile" type="button" :class="clearLink" @click="form.profile = ''">Quitar (sin dato)</button>
        </div>
        <div :class="bar('asymmetry')"><AdminSelect v-model="asymmetry" label="Asimetría" :options="ASYMMETRY" /></div>
        <div :class="bar('closure')">
          <p :id="`${uid}-closure`" class="mb-1.5 text-xs font-medium">Cierre</p>
          <AdminSegmented v-model="form.closure" :options="shoeOptions(SHOE_CLOSURE)" :labelledby="`${uid}-closure`" />
          <button v-if="form.closure" type="button" :class="clearLink" @click="form.closure = ''">Quitar (sin dato)</button>
        </div>
      </div>
    </AdminItemsSection>

    <AdminItemsSection title="Goma y rigidez">
      <div class="grid gap-4 sm:grid-cols-[1fr_140px]">
        <div :class="bar('rubber')"><AdminTextField v-model="form.rubber" label="Goma" :max="80" :error="errors.rubber" placeholder="FriXion RS" /></div>
        <div :class="bar('rubber_thickness_mm')"><AdminTextField v-model="form.rubber_thickness_mm" label="Grosor" suffix="mm" inputmode="decimal" :error="errors.rubber_thickness_mm" /></div>
      </div>
      <div :class="bar('stiffness')">
        <p :id="`${uid}-stiffness`" class="mb-1.5 text-xs font-medium">Rigidez</p>
        <AdminSegmented v-model="form.stiffness" :options="STIFFNESS" stacked :labelledby="`${uid}-stiffness`" />
        <button v-if="form.stiffness !== null" type="button" class="mt-1.5 min-h-6 rounded text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11" @click="form.stiffness = null">Quitar la rigidez (sin dato)</button>
      </div>
    </AdminItemsSection>

    <AdminItemsSection title="Para quién" description="Filtran en el comparador. Marca solo lo que de verdad recomiendas.">
      <div :class="bar('recommended_use')"><AdminShoesChecksField v-model="form.recommended_use" label="Uso recomendado" :options="SHOE_USE" /></div>
      <div :class="bar('levels')"><AdminShoesChecksField v-model="form.levels" label="Nivel" :options="SHOE_LEVEL" /></div>
    </AdminItemsSection>
  </div>
</template>
