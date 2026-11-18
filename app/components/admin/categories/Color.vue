<script setup lang="ts">
import { RadioGroupItem, RadioGroupRoot } from 'reka-ui'
import { CATEGORY_COLORS } from '~/utils/admin-categories'

/** Colour of a category: the design's palette as a radio group (arrows move) plus a free `#rrggbb`. */
defineProps<{ error?: string }>()
const model = defineModel<string>({ default: '' })
const hexId = `hex-${useId()}`
const preset = computed({
  get: () => (CATEGORY_COLORS as readonly string[]).find((c) => c.toLowerCase() === model.value.toLowerCase()) ?? '',
  set: (value: string) => (model.value = value),
})
</script>

<template>
  <fieldset>
    <legend :class="admLabel">Color</legend>
    <div class="flex flex-wrap items-center gap-2">
      <RadioGroupRoot v-model="preset" aria-label="Color de la categoría" class="flex flex-wrap gap-2">
        <RadioGroupItem
          v-for="color in CATEGORY_COLORS"
          :key="color"
          :value="color"
          :aria-label="color"
          :style="{ backgroundColor: color }"
          class="size-8 cursor-pointer rounded-md outline-offset-2 focus-visible:outline-2 focus-visible:outline-adm-acc data-[state=checked]:ring-2 data-[state=checked]:ring-adm-acc data-[state=checked]:ring-offset-2 max-md:size-11"
        />
      </RadioGroupRoot>
      <label :for="hexId" class="sr-only">Color en hexadecimal</label>
      <input
        :id="hexId"
        v-model="model"
        :class="[admInput, 'w-28! font-mono text-[13px]', error && admInputInvalid]"
        :aria-invalid="!!error || undefined"
        :aria-describedby="error ? `${hexId}-e` : undefined"
        maxlength="7"
        placeholder="#81b29a"
        autocomplete="off"
        spellcheck="false"
      />
    </div>
    <p v-if="error" :id="`${hexId}-e`" class="mt-1.5 text-xs text-adm-danger" role="alert">{{ error }}</p>
    <p v-else class="mt-1.5 text-xs text-adm-meta">Se usa en el punto de la categoría (panel y sitio). No como fondo de texto.</p>
  </fieldset>
</template>
