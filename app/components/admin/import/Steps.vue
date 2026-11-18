<script setup lang="ts">
import { Check } from 'lucide-vue-next'

/** Four steps of the importer (README §13.9): `ol` with `aria-current="step"` and "(hecho)" for screen readers. */
defineProps<{ current: 1 | 2 | 3 | 4 }>()
const STEPS = ['Archivo', 'Revisión', 'Importar', 'Resultado']
</script>

<template>
  <ol class="flex flex-wrap items-center gap-y-1 text-[13px] text-adm-muted" aria-label="Pasos de la importación">
    <li
      v-for="(label, i) in STEPS"
      :key="label"
      :aria-current="i + 1 === current ? 'step' : undefined"
      :class="['flex items-center gap-1.5', i > 0 && 'before:mx-2 before:h-px before:w-5 before:bg-adm-line-strong', i + 1 === current && 'font-medium text-adm-fg']"
    >
      <span
        :class="[
          'grid size-5 place-items-center rounded-full border text-[11px] font-semibold tabular-nums',
          i + 1 === current ? 'border-adm-primary bg-adm-primary text-adm-on-primary' : i + 1 < current ? 'border-transparent bg-adm-ok-soft text-adm-ok' : 'border-adm-line-strong',
        ]"
      >
        <Check v-if="i + 1 < current" class="size-3" aria-hidden="true" /><template v-else>{{ i + 1 }}</template>
      </span>
      {{ label }}<span v-if="i + 1 < current" class="sr-only"> (hecho)</span>
    </li>
  </ol>
</template>
