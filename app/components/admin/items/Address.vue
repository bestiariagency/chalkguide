<script setup lang="ts">
import { MapPin } from 'lucide-vue-next'
import { mapUrlOf, type ItemForm } from '~/utils/item-fields'
import type { ItemErrors } from '~/utils/item-patch'

/** Address, coordinates and contact (web, Instagram, phone) shared by gyms and resolers. The `address` slot adds fields under the coordinates. */
const props = defineProps<{ errors: ItemErrors; changed: string[]; districtHelp?: string }>()
const form = defineModel<ItemForm>('form', { required: true })
const mapUrl = computed(() => mapUrlOf(form.value.lat, form.value.lng))
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
</script>

<template>
  <div>
    <AdminItemsSection title="Dirección">
      <div class="grid gap-4 sm:grid-cols-[1fr_120px]">
        <div :class="bar('address')"><AdminTextField v-model="form.address" label="Dirección" autocomplete="off" /></div>
        <div :class="bar('postal_code')"><AdminTextField v-model="form.postal_code" label="Código postal" inputmode="numeric" :maxlength="5" :error="errors.postal_code" /></div>
      </div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div :class="bar('city')"><AdminTextField v-model="form.city" label="Ciudad" required :error="errors.city" /></div>
        <div :class="bar('district')"><AdminTextField v-model="form.district" label="Barrio o municipio" :help="districtHelp" /></div>
      </div>
      <div class="grid gap-4 sm:grid-cols-2">
        <div :class="bar('lat')"><AdminTextField v-model="form.lat" label="Latitud" inputmode="decimal" mono :error="errors.lat" placeholder="41,404000" /></div>
        <div :class="bar('lng')"><AdminTextField v-model="form.lng" label="Longitud" inputmode="decimal" mono :error="errors.lng" placeholder="2,157000" /></div>
      </div>
      <a v-if="mapUrl" :href="mapUrl" target="_blank" rel="noopener" class="inline-flex min-h-6 items-center gap-1.5 text-[13px] underline underline-offset-2 max-md:min-h-11"><MapPin class="size-3.5" aria-hidden="true" />Ver en el mapa<span class="sr-only"> (OpenStreetMap, se abre en otra pestaña)</span></a>
      <slot name="address" />
    </AdminItemsSection>

    <AdminItemsSection title="Contacto">
      <div class="grid gap-4 sm:grid-cols-3">
        <div :class="bar('website_url')"><AdminTextField v-model="form.website_url" label="Web" type="url" inputmode="url" :error="errors.website_url" placeholder="https://…" /></div>
        <div :class="bar('instagram_url')"><AdminTextField v-model="form.instagram_url" label="Instagram" type="url" inputmode="url" :error="errors.instagram_url" placeholder="https://instagram.com/…" /></div>
        <div :class="bar('phone')"><AdminTextField v-model="form.phone" label="Teléfono" type="tel" inputmode="tel" :maxlength="30" :error="errors.phone" placeholder="+34 …" /></div>
      </div>
    </AdminItemsSection>
  </div>
</template>
