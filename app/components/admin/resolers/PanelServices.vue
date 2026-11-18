<script setup lang="ts">
import { BadgeCheck, CircleAlert } from 'lucide-vue-next'
import type { ItemErrors } from '~/utils/item-patch'
import { RESOLER_SERVICE_HELP, type ResolerForm } from '~/utils/resoler-fields'

/** Servicios y precios: services of the DB CHECK, prices and turnaround, rubber brands and mail-in shipping (three states). */
const props = defineProps<{ errors: ItemErrors; changed: string[]; live: boolean; busy?: boolean }>()
defineEmits<{ verify: [date: string] }>()
const form = defineModel<ResolerForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const MAIL = [
  { value: true, label: 'Sí' },
  { value: false, label: 'No' },
  { value: null, label: 'No lo sé' },
] as const
const uid = useId()
const today = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Madrid' })

/** Ticks or unticks a service keeping the canonical order of the list. */
function toggle(key: string, on: boolean) {
  const next = new Set(form.value.services)
  if (on) next.add(key)
  else next.delete(key)
  form.value.services = RESOLER_SERVICE_HELP.map(([k]) => k).filter((k) => next.has(k))
}
</script>

<template>
  <div>
    <AdminItemsSection title="Servicios" :title-id="`${uid}-services`" description="Lo que hace el taller. Sirve para filtrar en /resolar-pies-de-gato («hace rand»).">
      <div role="group" :aria-labelledby="`${uid}-services`" :aria-describedby="errors.services ? `${uid}-services-err` : undefined" :class="['grid gap-2 sm:grid-cols-2', bar('services'), errors.services && 'rounded-lg outline outline-1 outline-offset-4 outline-adm-danger']">
        <label v-for="[key, label, help] in RESOLER_SERVICE_HELP" :key="key" class="flex min-h-11 cursor-pointer items-start gap-2.5 rounded-lg border border-adm-line-strong bg-adm-elev px-3 py-2.5 has-[button[data-state=checked]]:border-adm-fg has-[button[data-state=checked]]:bg-adm-subtle has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-adm-acc">
          <AdminCheckbox class="mt-0.5" :label="label" :describedby="`${uid}-svc-${key}`" :model-value="form.services.includes(key)" @update:model-value="toggle(key, $event === true)" />
          <span><span class="block text-sm font-medium">{{ label }}</span><span :id="`${uid}-svc-${key}`" class="block text-xs text-adm-meta">{{ help }}</span></span>
        </label>
      </div>
      <p :id="`${uid}-services-err`" aria-live="polite" :class="errors.services ? 'mt-1.5 flex items-start gap-1.5 text-xs leading-4 text-adm-danger' : 'sr-only'">
        <template v-if="errors.services">
          <CircleAlert class="mt-px size-3.5 flex-none" aria-hidden="true" /><span>{{ errors.services }}</span>
        </template>
      </p>
    </AdminItemsSection>

    <AdminItemsSection title="Precios y plazo" description="En euros con IVA. Vacío = sin dato (no se muestra).">
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div :class="bar('price_per_pair_eur')"><AdminTextField v-model="form.price_per_pair_eur" label="Por par" suffix="€" inputmode="decimal" :error="errors.price_per_pair_eur" help="Media suela" /></div>
        <div :class="bar('price_rand_eur')"><AdminTextField v-model="form.price_rand_eur" label="Rand" suffix="€" inputmode="decimal" :error="errors.price_rand_eur" help="Rehacer rand" /></div>
        <div :class="bar('turnaround_days_min')"><AdminTextField v-model="form.turnaround_days_min" label="Plazo mínimo" suffix="días" inputmode="numeric" :error="errors.turnaround_days_min" /></div>
        <div :class="bar('turnaround_days_max')"><AdminTextField v-model="form.turnaround_days_max" label="Plazo máximo" suffix="días" inputmode="numeric" :error="errors.turnaround_days_max" /></div>
      </div>
      <div :class="bar('rubber_brands')"><AdminItemsChipsField v-model="form.rubber_brands" label="Marcas de goma" help="Vibram, Stealth… Una por chip." /></div>
      <div class="flex flex-wrap items-end gap-3">
        <div :class="['w-44', bar('prices_verified_at')]"><AdminTextField v-model="form.prices_verified_at" label="Precios verificados el" type="date" /></div>
        <button type="button" :class="admBtnGhost" :disabled="busy" :aria-describedby="live ? `${uid}-verify-help` : undefined" @click="$emit('verify', today())"><BadgeCheck aria-hidden="true" />Verificar hoy</button>
      </div>
      <p v-if="live" :id="`${uid}-verify-help`" class="-mt-1 text-xs text-adm-meta">En fichas publicadas se guarda al momento, sin pasar por el borrador.</p>
    </AdminItemsSection>

    <AdminItemsSection title="Envíos por correo">
      <div :class="bar('accepts_mail')">
        <p :id="`${uid}-mail`" class="mb-1.5 text-xs font-medium">¿Acepta envíos?</p>
        <AdminSegmented v-model="form.accepts_mail" :options="MAIL" :labelledby="`${uid}-mail`" />
        <p class="mt-1.5 text-xs text-adm-meta">«No lo sé» no es «No»: en ese caso la ficha no dice nada de envíos.</p>
      </div>
      <div class="grid gap-4 lg:grid-cols-2">
        <div :class="bar('mail_notes_es')"><AdminTextArea v-model="form.mail_notes_es" label="Notas de envío" lang="ES" :rows="2" placeholder="Precio de la vuelta, cómo empaquetar…" /></div>
        <div :class="bar('mail_notes_en')"><AdminTextArea v-model="form.mail_notes_en" label="Notas de envío" lang="EN" :rows="2" placeholder="Opcional" /></div>
      </div>
    </AdminItemsSection>
  </div>
</template>
