<script setup lang="ts">
import { parseNumber } from '~/utils/item-fields'
import type { GymForm } from '~/utils/gym-fields'
import type { ItemErrors } from '~/utils/item-patch'

/** Precios: four amounts in euros, discounts and the date they were checked. Empty = no data (not shown); 0 = free. */
const props = defineProps<{ errors: ItemErrors; changed: string[]; published: GymForm | null }>()
const form = defineModel<GymForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const money = (n: number) => `${n.toFixed(2).replace('.', ',')} €`

const FIELDS = [
  ['price_registration_eur', 'Matrícula'],
  ['price_day_eur', 'Entrada de día'],
  ['price_10_pass_eur', 'Bono 10'],
  ['price_monthly_eur', 'Cuota mensual'],
] as const
/** Help line: the value before the change, or the price per session of the 10-pass. */
function help(id: (typeof FIELDS)[number][0]): string | undefined {
  if (props.changed.includes(id) && props.published) {
    const before = parseNumber(props.published[id])
    return `Publicado: ${before === null ? 'sin dato' : money(before)}`
  }
  const pass = parseNumber(form.value.price_10_pass_eur)
  return id === 'price_10_pass_eur' && pass !== null && pass > 0 ? `${money(pass / 10)} por sesión` : undefined
}
</script>

<template>
  <AdminItemsSection title="Precios" description="En euros con IVA. Vacío = sin dato (no se muestra). 0 = gratis.">
    <div class="grid grid-cols-2 gap-4 lg:grid-cols-4">
      <div v-for="[id, label] in FIELDS" :key="id" :class="bar(id)">
        <AdminTextField v-model="form[id]" :label="label" suffix="€" inputmode="decimal" :error="errors[id]" :help="help(id)" />
      </div>
    </div>
    <div class="grid gap-4 lg:grid-cols-2">
      <div :class="bar('discounts_es')"><AdminTextArea v-model="form.discounts_es" label="Descuentos" lang="ES" :rows="2" placeholder="Cuota de mañanas (7–15 h) 49 €." /></div>
      <div :class="bar('discounts_en')"><AdminTextArea v-model="form.discounts_en" label="Descuentos" lang="EN" :rows="2" placeholder="Opcional" /></div>
    </div>
    <div :class="['w-44', bar('prices_verified_at')]"><AdminTextField v-model="form.prices_verified_at" label="Precios verificados el" type="date" :help="changed.includes('prices_verified_at') && published?.prices_verified_at ? `Publicado: ${adminDate(published.prices_verified_at)}` : undefined" /></div>
  </AdminItemsSection>
</template>
