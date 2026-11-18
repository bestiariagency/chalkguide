<script setup lang="ts">
import { CircleAlert, Minus, Plus } from 'lucide-vue-next'
import { stepSize } from '~/utils/shoe-fields'

/** A size in EU with half-size buttons (the box is also typeable: comma or dot). */
defineProps<{ label: string; error?: string; describedby?: string }>()
const model = defineModel<string>({ required: true })
const id = useId()
</script>

<template>
  <div>
    <label :for="id" class="mb-1.5 flex items-center gap-1.5 text-xs font-medium">{{ label }}<span class="rounded bg-adm-subtle px-1 text-[11px] font-semibold text-adm-meta">EU</span></label>
    <div class="flex items-center gap-1">
      <button type="button" :class="[admIconBtn, 'border border-adm-line-strong bg-adm-elev']" aria-label="Media talla menos" @click="model = stepSize(model, -1)"><Minus aria-hidden="true" /></button>
      <input :id="id" v-model="model" type="text" inputmode="decimal" autocomplete="off" :aria-invalid="error ? true : undefined" :aria-describedby="[error ? `${id}-err` : '', describedby].filter(Boolean).join(' ') || undefined" :class="[admInput, 'w-16! text-center tabular-nums', error && 'border-adm-danger']" />
      <button type="button" :class="[admIconBtn, 'border border-adm-line-strong bg-adm-elev']" aria-label="Media talla más" @click="model = stepSize(model, 1)"><Plus aria-hidden="true" /></button>
    </div>
    <p v-if="error" :id="`${id}-err`" class="mt-1.5 flex items-start gap-1.5 text-xs leading-4 text-adm-danger"><CircleAlert class="mt-px size-3.5 flex-none" aria-hidden="true" /><span>{{ error }}</span></p>
  </div>
</template>
