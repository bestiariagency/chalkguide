<script setup lang="ts">
/** Dominant colour: swatch, editable #rrggbb and "Recalcular" (reads the uploaded file again). */
defineProps<{ error?: string; busy?: boolean }>()
const model = defineModel<string>({ default: '' })
defineEmits<{ recalc: [] }>()
const id = `color-${useId()}`
</script>

<template>
  <div>
    <div class="flex flex-wrap items-center gap-2">
      <label :for="id" class="text-xs text-adm-meta">Color dominante</label>
      <span class="size-5 rounded ring-1 ring-black/10" :style="{ backgroundColor: /^#[0-9a-f]{6}$/i.test(model) ? model : undefined }" aria-hidden="true" />
      <input :id="id" v-model="model" :class="[admInput, 'w-28! font-mono', error && admInputInvalid]" :aria-invalid="!!error || undefined" :aria-describedby="`${id}-h`" spellcheck="false" autocomplete="off" />
      <button type="button" class="text-xs text-adm-meta underline underline-offset-2 hover:text-adm-fg max-md:min-h-11" :disabled="busy" @click="$emit('recalc')">{{ busy ? 'Calculando…' : 'Recalcular' }}</button>
    </div>
    <p v-if="error" class="mt-1 text-xs text-adm-danger" role="alert">{{ error }}</p>
    <p :id="`${id}-h`" class="mt-1 text-xs text-adm-meta">Tiñe el hero de la home cuando esta imagen es la portada del destacado.</p>
  </div>
</template>
