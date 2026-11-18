<script setup lang="ts">
import { sizeDelta, type ShoeForm } from '~/utils/shoe-fields'
import type { ItemErrors } from '~/utils/item-patch'

/** "Mis tallas": the size he wears in the model, his street size and the fit notes; shows how the comparator will read them. */
const props = defineProps<{ errors: ItemErrors; changed: string[] }>()
const form = defineModel<ShoeForm>('form', { required: true })
const bar = (...ids: string[]) => changedBar(ids.some((id) => props.changed.includes(id)))
const comma = (size: string) => size.trim().replace('.', ',')
const delta = computed(() => (props.errors.author_size_eu || props.errors.author_street_size_eu ? null : sizeDelta(form.value.author_size_eu, form.value.author_street_size_eu)))
const uid = useId()
</script>

<template>
  <div class="space-y-4 rounded-lg border border-adm-line bg-adm-side p-4">
    <h3 class="text-sm font-semibold">Mis tallas</h3>
    <div class="grid items-start gap-4 sm:grid-cols-[170px_170px_1fr]">
      <div :class="bar('author_size_eu')"><AdminShoesSizeStepper v-model="form.author_size_eu" label="Talla que uso" :describedby="`${uid}-sizes-help`" :error="errors.author_size_eu" /></div>
      <div :class="bar('author_street_size_eu')"><AdminShoesSizeStepper v-model="form.author_street_size_eu" label="Talla de calle" :describedby="`${uid}-sizes-help`" :error="errors.author_street_size_eu" /></div>
      <div class="text-sm" aria-live="polite">
        <p class="mb-1.5 text-xs font-medium">En el comparador</p>
        <template v-if="delta !== null">
          <p class="text-sm font-medium tabular-nums">{{ comma(form.author_size_eu) }}</p>
          <p class="text-xs text-adm-meta">calzo {{ comma(form.author_street_size_eu) }} de calle · <span class="tabular-nums">{{ delta }}</span></p>
        </template>
        <p v-else class="text-xs text-adm-meta">Rellena las dos tallas para verlo.</p>
      </div>
    </div>
    <p :id="`${uid}-sizes-help`" class="text-xs text-adm-meta">De 30 a 50, de media en media. Las dos o ninguna.</p>
    <div class="grid gap-4 lg:grid-cols-2">
      <div :class="bar('author_size_note_es')"><AdminTextArea v-model="form.author_size_note_es" label="Nota de ajuste" lang="ES" :rows="2" :max="140" :error="errors.author_size_note_es" /></div>
      <div :class="bar('author_size_note_en')"><AdminTextArea v-model="form.author_size_note_en" label="Nota de ajuste" lang="EN" :rows="2" :max="140" :error="errors.author_size_note_en" placeholder="Opcional; necesita la nota en español" /></div>
    </div>
  </div>
</template>
