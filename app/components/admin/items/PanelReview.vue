<script setup lang="ts">
import { Gift } from 'lucide-vue-next'
import type { ItemCriterion } from '~/services/admin/item-editor'
import type { GymIndices } from '~/services/admin/gym-editor'
import type { ItemInfo } from '~/utils/item-spec'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemForm } from '~/utils/item-fields'
import type { ItemErrors } from '~/utils/item-patch'

/** Reseña y notas: visit type (invited is always marked), verdict, rich text and scores per criterion. */
const props = defineProps<{ errors: ItemErrors; changed: string[]; criteria: ItemCriterion[]; info: ItemInfo; indices?: GymIndices | null; familyComplete?: boolean }>()
defineEmits<{ media: [media: AdminMedia] }>()
const form = defineModel<ItemForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const VISIT = [
  { value: 'paid' as const, label: 'Pagada' },
  { value: 'invited' as const, label: 'Invitada' },
]
const uid = useId()
</script>

<template>
  <div>
    <AdminItemsSection title="Visita" description="Tu reseña es lo central de la ficha. Si la visita fue invitada, se marca siempre.">
      <div class="grid items-end gap-4 sm:grid-cols-[auto_1fr]">
        <div :class="bar('visit_type')">
          <p :id="`${uid}-visit`" class="mb-1.5 text-xs font-medium">Tipo de visita</p>
          <AdminSegmented v-model="form.visit_type" :options="VISIT" :labelledby="`${uid}-visit`" />
        </div>
        <div :class="['sm:w-44', bar('visit_date')]"><AdminTextField v-model="form.visit_date" label="Fecha de visita" type="date" /></div>
      </div>
      <div v-if="form.visit_type === 'invited'" class="space-y-3 rounded-lg border border-adm-line bg-adm-side p-4">
        <p class="flex items-center gap-2 text-sm"><span :class="[admChip, 'bg-adm-acc-soft text-adm-acc']"><Gift aria-hidden="true" />Visita invitada</span><span class="text-xs text-adm-meta">Se marca en la tarjeta y en la ficha. La nota en español es obligatoria para publicar: cuenta quién te invitó y qué te ofrecieron.</span></p>
        <div class="grid gap-4 lg:grid-cols-2">
          <div :class="bar('disclosure_note_es')"><AdminTextArea v-model="form.disclosure_note_es" label="Nota de transparencia" lang="ES" required :rows="2" :max="500" :error="errors.disclosure_note_es" /></div>
          <div :class="bar('disclosure_note_en')"><AdminTextArea v-model="form.disclosure_note_en" label="Nota de transparencia" lang="EN" :rows="2" :max="500" :error="errors.disclosure_note_en" /></div>
        </div>
      </div>
    </AdminItemsSection>

    <AdminItemsSection title="Tu reseña">
      <div class="grid gap-4 lg:grid-cols-2">
        <div :class="bar('headline_es')"><AdminTextField v-model="form.headline_es" label="Veredicto" lang="ES" :max="120" :error="errors.headline_es" /></div>
        <div :class="bar('headline_en')"><AdminTextField v-model="form.headline_en" label="Veredicto" lang="EN" :max="120" :error="errors.headline_en" /></div>
      </div>
      <AdminItemsReviewBody v-model:form="form" :changed="changed" @media="$emit('media', $event)" />
    </AdminItemsSection>

    <AdminItemsSection>
      <AdminItemsScores v-model="form.scores" :criteria="criteria" :nouns="info.nouns" :indices="indices" :family-complete="familyComplete" :show-indices="info.category === 'gym'" :changed="changed.includes('scores')" />
    </AdminItemsSection>
  </div>
</template>
