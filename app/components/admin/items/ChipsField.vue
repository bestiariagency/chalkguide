<script setup lang="ts">
import { X } from 'lucide-vue-next'

/** Free-text chips (metro stops, rubber brands): Intro or comma adds, Backspace on an empty box removes the last. */
defineProps<{ label: string; help?: string }>()
const stops = defineModel<string[]>({ required: true })
const draft = ref('')
const id = useId()

function add() {
  const value = draft.value.trim().replace(/,$/, '').trim()
  draft.value = ''
  if (value && !stops.value.includes(value)) stops.value = [...stops.value, value]
}
function onKey(event: KeyboardEvent) {
  if (event.key === 'Enter' || event.key === ',') {
    event.preventDefault()
    add()
  } else if (event.key === 'Backspace' && !draft.value && stops.value.length) stops.value = stops.value.slice(0, -1)
}
const remove = (stop: string) => (stops.value = stops.value.filter((s) => s !== stop))
</script>

<template>
  <div>
    <label :for="id" class="mb-1.5 flex text-xs font-medium">{{ label }}</label>
    <div :class="[admInput, 'flex h-auto min-h-8 flex-wrap items-center gap-1.5 py-1 focus-within:border-adm-acc focus-within:ring-[3px] focus-within:ring-adm-acc/20']">
      <span v-for="stop in stops" :key="stop" class="inline-flex items-center gap-1 rounded bg-adm-subtle py-0.5 pr-0.5 pl-2 text-xs">
        {{ stop }}
        <button type="button" class="relative grid size-5 place-items-center rounded text-adm-muted hover:text-adm-fg max-md:after:absolute max-md:after:-inset-3" :aria-label="`Quitar ${stop}`" @click="remove(stop)"><X class="size-3" aria-hidden="true" /></button>
      </span>
      <input :id="id" v-model="draft" type="text" class="min-w-[120px] flex-1 bg-transparent text-[13px] outline-none max-md:text-base" placeholder="Añadir y pulsar Intro" :aria-describedby="help ? `${id}-h` : undefined" @keydown="onKey" @blur="add" />
    </div>
    <p v-if="help" :id="`${id}-h`" class="mt-1.5 text-xs text-adm-meta">{{ help }}</p>
  </div>
</template>
