<script setup lang="ts">
import { BadgeCheck, Link2 } from 'lucide-vue-next'
import type { ItemErrors } from '~/utils/item-patch'
import type { ShoeForm } from '~/utils/shoe-fields'

/** Precio y afiliado: price range and the date it was looked at, affiliate link and program. A link always marks the sheet as affiliate (rule 7). */
const props = defineProps<{ errors: ItemErrors; changed: string[]; live: boolean; busy?: boolean }>()
defineEmits<{ verify: [date: string] }>()
const form = defineModel<ShoeForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const uid = useId()
const today = () => new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Madrid' })
const affiliate = computed(() => form.value.affiliate_url.trim().length > 0)
</script>

<template>
  <div>
    <AdminItemsSection title="Precio" description="En euros con IVA. Vacío = sin dato (la ficha no muestra precio).">
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-3">
        <div :class="bar('price_min_eur')"><AdminTextField v-model="form.price_min_eur" label="Precio desde" suffix="€" inputmode="decimal" :error="errors.price_min_eur" /></div>
        <div :class="bar('price_max_eur')"><AdminTextField v-model="form.price_max_eur" label="Hasta" suffix="€" inputmode="decimal" :error="errors.price_max_eur" /></div>
      </div>
      <div class="flex flex-wrap items-start gap-3">
        <div :class="['w-44', bar('price_checked_at')]"><AdminTextField v-model="form.price_checked_at" label="Precio verificado el" type="date" :error="errors.price_checked_at" help="Obligatoria si hay precio." /></div>
        <button type="button" :class="[admBtnGhost, 'mt-6']" :disabled="busy" :aria-describedby="live ? `${uid}-verify-help` : undefined" @click="$emit('verify', today())"><BadgeCheck aria-hidden="true" />Verificar hoy</button>
      </div>
      <p v-if="live" :id="`${uid}-verify-help`" class="-mt-1 text-xs text-adm-meta">En fichas publicadas se guarda al momento, sin pasar por el borrador.</p>
    </AdminItemsSection>

    <AdminItemsSection title="Enlace de afiliado" description="Por independencia editorial, el enlace nunca cambia la opinión ni el orden del comparador.">
      <div class="grid gap-4 sm:grid-cols-2">
        <div :class="bar('affiliate_url')"><AdminTextField v-model="form.affiliate_url" label="Enlace de afiliado" type="url" inputmode="url" :error="errors.affiliate_url" placeholder="https://…" help="Con https://, sin espacios. Vacío = sin enlace." /></div>
        <div :class="bar('affiliate_program')"><AdminTextField v-model="form.affiliate_program" label="Programa" :max="80" :error="errors.affiliate_program" placeholder="Deporvillage" help="Solo con enlace: si quitas el enlace, quita también el programa." /></div>
      </div>
      <p class="flex flex-wrap items-center gap-2 text-sm" aria-live="polite">
        <span class="text-adm-meta">Así sale:</span>
        <span v-if="affiliate" :class="[admChip, 'bg-adm-acc-soft text-adm-acc']"><Link2 aria-hidden="true" />Enlace de afiliado</span>
        <span v-else class="text-xs text-adm-meta">Sin enlace, sin marca de afiliado.</span>
        <span v-if="affiliate" class="text-xs text-adm-meta">La marca «afiliado» sale sola en cuanto hay enlace y no se puede quitar: el lector siempre lo ve.</span>
      </p>
    </AdminItemsSection>
  </div>
</template>
