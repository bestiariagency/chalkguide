<script setup lang="ts">
import { CheckboxIndicator, CheckboxRoot } from 'reka-ui'
import { Check, Minus } from 'lucide-vue-next'

/** Checkbox (Reka): `indeterminate` for partial selections. 44 px hit area on touch. */
defineProps<{ label: string; disabled?: boolean; describedby?: string }>()
const model = defineModel<boolean | 'indeterminate'>({ default: false })
</script>

<template>
  <CheckboxRoot
    v-model="model"
    :aria-label="label"
    :aria-describedby="describedby"
    :disabled="disabled"
    class="relative grid size-4 flex-none cursor-pointer place-items-center rounded border border-adm-control bg-adm-elev text-white before:absolute before:-inset-3.5 before:content-[''] hover:border-adm-meta data-[state=checked]:border-adm-acc data-[state=checked]:bg-adm-acc data-[state=indeterminate]:border-adm-acc data-[state=indeterminate]:bg-adm-acc disabled:cursor-not-allowed disabled:opacity-45 md:before:-inset-2"
  >
    <CheckboxIndicator>
      <Minus v-if="model === 'indeterminate'" class="size-3" stroke-width="3" aria-hidden="true" />
      <Check v-else class="size-3" stroke-width="3" aria-hidden="true" />
    </CheckboxIndicator>
  </CheckboxRoot>
</template>
