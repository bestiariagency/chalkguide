<script setup lang="ts">
import { SwitchRoot, SwitchThumb } from 'reka-ui'

/** On/off switch with its label (clickable) and optional help. Row is ≥ 44 px on touch. */
defineProps<{ label: string; help?: string; changed?: boolean; disabled?: boolean; name?: string }>()
const model = defineModel<boolean>({ default: false })
const uid = useId()
</script>

<template>
  <div class="flex items-start gap-3 py-1 max-md:min-h-11">
    <SwitchRoot
      :id="`sw-${uid}`"
      v-model="model"
      :disabled="disabled"
      :name="name"
      :aria-describedby="help ? `sw-${uid}-h` : undefined"
      class="relative mt-0.5 inline-flex h-[18px] w-8 flex-none cursor-pointer items-center rounded-full bg-adm-control transition-colors duration-150 motion-reduce:transition-none data-[state=checked]:bg-adm-acc disabled:cursor-not-allowed disabled:opacity-45 max-md:mt-1.5 max-md:before:absolute max-md:before:-inset-3 max-md:before:content-['']"
    >
      <SwitchThumb class="block size-3.5 translate-x-0.5 rounded-full bg-white transition-transform duration-150 motion-reduce:transition-none data-[state=checked]:translate-x-[16px]" />
    </SwitchRoot>
    <div>
      <label :for="`sw-${uid}`" class="cursor-pointer text-[13px] leading-5 text-adm-fg">{{ label }}</label>
      <span v-if="changed" class="ml-2 text-[11px] font-medium text-adm-st-rev">Sin guardar</span>
      <p v-if="help" :id="`sw-${uid}-h`" class="text-xs leading-4 text-adm-meta">{{ help }}</p>
    </div>
  </div>
</template>
