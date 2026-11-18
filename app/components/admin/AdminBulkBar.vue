<script setup lang="ts">
import { X } from 'lucide-vue-next'

/**
 * Floating bar with the actions for the selected rows. The count is announced politely; put the
 * actions (buttons) in the default slot. Above the bottom bar on mobile.
 */
defineProps<{ count: number; feminine?: boolean }>()
defineEmits<{ clear: [] }>()
</script>

<template>
  <Transition
    enter-active-class="transition duration-200 motion-reduce:transition-none"
    enter-from-class="translate-y-2 opacity-0"
    leave-active-class="transition duration-150 motion-reduce:transition-none"
    leave-to-class="opacity-0"
  >
    <section
      v-if="count > 0"
      aria-label="Acciones en lote"
      class="fixed bottom-6 left-1/2 z-40 flex max-w-[calc(100vw-1.5rem)] -translate-x-1/2 flex-nowrap items-center overflow-x-auto gap-2 rounded-xl border border-adm-line bg-adm-elev p-2 pl-4 shadow-adm-pop max-md:bottom-[76px]"
    >
      <p class="whitespace-nowrap text-[13px] font-medium" role="status" aria-live="polite">
        {{ count }} {{ feminine ? (count === 1 ? 'seleccionada' : 'seleccionadas') : (count === 1 ? 'seleccionado' : 'seleccionados') }}
      </p>
      <span class="mx-1 h-5 w-px bg-adm-line" aria-hidden="true" />
      <slot />
      <button type="button" :class="[admIconBtn, 'shrink-0 max-md:order-first']" aria-label="Quitar la selección" @click="$emit('clear')">
        <X aria-hidden="true" />
      </button>
    </section>
  </Transition>
</template>
