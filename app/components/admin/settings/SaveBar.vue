<script setup lang="ts">
/** Floating "cambios sin guardar" bar (settings are saved at once, there is no draft). */
defineProps<{ count: number; busy: boolean }>()
defineEmits<{ save: []; discard: [] }>()
</script>

<template>
  <div
    role="region"
    aria-label="Cambios sin guardar"
    class="fixed bottom-20 left-1/2 z-40 flex w-[calc(100vw-24px)] -translate-x-1/2 items-center gap-3 rounded-lg border border-adm-line-strong bg-adm-elev py-2 pr-2 pl-4 text-sm shadow-adm-pop sm:w-auto md:right-6 md:bottom-6 md:left-auto md:translate-x-0"
  >
    <span class="flex flex-1 items-center gap-2" role="status">
      <span class="size-2 flex-none rounded-full bg-adm-warn-icon" aria-hidden="true" />{{ count }} {{ count === 1 ? 'cambio sin guardar' : 'cambios sin guardar' }}
    </span>
    <button type="button" :class="admBtnQuiet" :disabled="busy" @click="$emit('discard')">Descartar</button>
    <button type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy" @click="$emit('save')">{{ busy ? 'Guardando…' : 'Guardar' }}</button>
  </div>
</template>
