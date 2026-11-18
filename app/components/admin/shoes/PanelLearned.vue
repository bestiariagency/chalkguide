<script setup lang="ts">
import { Gift } from 'lucide-vue-next'
import type { ItemCriterion } from '~/services/admin/item-editor'
import type { AdminMedia } from '~/utils/admin-media'
import type { ItemErrors } from '~/utils/item-patch'
import type { ShoeForm } from '~/utils/shoe-fields'

/** Lo que aprendí: whether he owns and has used the model, how he got them, his sizes, verdict, review and scores. */
const props = defineProps<{ errors: ItemErrors; changed: string[]; criteria: ItemCriterion[] }>()
defineEmits<{ media: [media: AdminMedia] }>()
const form = defineModel<ShoeForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const HOW = [
  { value: 'paid' as const, label: 'Comprados' },
  { value: 'invited' as const, label: 'Cedidos por la marca' },
]
const uid = useId()
</script>

<template>
  <div>
    <AdminItemsSection>
      <div :class="bar('owned_by_author')"><AdminSwitch v-model="form.owned_by_author" label="Los tengo y los he usado" help="Activa «Lo que aprendí», la reseña y tus tallas. Si está apagado, la ficha es solo técnica." /></div>
    </AdminItemsSection>

    <div :inert="!form.owned_by_author || undefined" :class="['mt-6 space-y-6', !form.owned_by_author && 'opacity-45']">
      <AdminItemsSection>
        <div class="grid items-end gap-4 sm:grid-cols-[auto_1fr]">
          <div :class="bar('visit_type')">
            <p :id="`${uid}-how`" class="mb-1.5 text-xs font-medium">Cómo los conseguí</p>
            <AdminSegmented v-model="form.visit_type" :options="HOW" :labelledby="`${uid}-how`" />
          </div>
          <div :class="['sm:w-44', bar('visit_date')]"><AdminTextField v-model="form.visit_date" label="Usándolos desde" type="date" /></div>
        </div>
        <div v-if="form.visit_type === 'invited'" class="space-y-3 rounded-lg border border-adm-line bg-adm-side p-4">
          <p class="flex items-center gap-2 text-sm"><span :class="[admChip, 'bg-adm-acc-soft text-adm-acc']"><Gift aria-hidden="true" />Cedidos por la marca</span><span class="text-xs text-adm-meta">Se marca siempre en la ficha. La nota en español es obligatoria para publicar: cuenta quién te los dio y qué te pidieron a cambio.</span></p>
          <div class="grid gap-4 lg:grid-cols-2">
            <div :class="bar('disclosure_note_es')"><AdminTextArea v-model="form.disclosure_note_es" label="Nota de transparencia" lang="ES" required :rows="2" :max="500" :error="errors.disclosure_note_es" /></div>
            <div :class="bar('disclosure_note_en')"><AdminTextArea v-model="form.disclosure_note_en" label="Nota de transparencia" lang="EN" :rows="2" :max="500" :error="errors.disclosure_note_en" /></div>
          </div>
        </div>
        <AdminShoesSizes v-model:form="form" :errors="errors" :changed="changed" />
      </AdminItemsSection>

      <AdminItemsSection title="Lo que aprendí" description="Tu reseña es lo central de la ficha.">
        <div class="grid gap-4 lg:grid-cols-2">
          <div :class="bar('headline_es')"><AdminTextField v-model="form.headline_es" label="Veredicto" lang="ES" :max="120" :error="errors.headline_es" /></div>
          <div :class="bar('headline_en')"><AdminTextField v-model="form.headline_en" label="Veredicto" lang="EN" :max="120" :error="errors.headline_en" /></div>
        </div>
        <AdminItemsReviewBody v-model:form="form" :changed="changed" @media="$emit('media', $event)" />
      </AdminItemsSection>

      <AdminItemsSection>
        <AdminItemsScores v-model="form.scores" :criteria="criteria" nouns="pies de gato" :changed="changed.includes('scores')" />
      </AdminItemsSection>
    </div>
  </div>
</template>
