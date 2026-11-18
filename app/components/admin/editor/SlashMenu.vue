<script setup lang="ts">
import type { BlockDef } from '~/utils/article-blocks'

/**
 * `/` menu list (state in `useSlashMenu`). Focus stays in the editor: options are announced through
 * `aria-activedescendant` on it; the status line reads the count. Mouse picks do not steal focus.
 */
defineProps<{
  open: boolean
  listboxId: string
  optionId: (key: string) => string
  blocks: BlockDef[]
  active: number
  position: { left: number; top?: number; bottom?: number }
}>()
defineEmits<{ choose: [block: BlockDef]; hover: [index: number] }>()
</script>

<template>
  <p class="sr-only" role="status">{{ !open ? '' : blocks.length ? `${blocks.length === 1 ? '1 bloque' : `${blocks.length} bloques`}. Usa las flechas arriba y abajo y Intro para elegir.` : 'Ningún bloque coincide.' }}</p>
  <div v-if="open" class="admin fixed z-[70] font-sans" :style="{ left: `${position.left}px`, top: position.top !== undefined ? `${position.top}px` : undefined, bottom: position.bottom !== undefined ? `${position.bottom}px` : undefined }">
    <ul v-if="blocks.length" :id="listboxId" role="listbox" aria-label="Insertar bloque" :class="[admPopover, 'max-h-72 w-80 max-w-[calc(100vw-1rem)] overflow-y-auto']">
      <li
        v-for="(block, index) in blocks"
        :id="optionId(block.key)"
        :key="block.key"
        role="option"
        :aria-selected="index === active"
        class="flex min-h-9 cursor-pointer items-center gap-3 rounded px-2 py-1.5 max-md:min-h-11 aria-selected:bg-adm-subtle"
        @mousedown.prevent
        @mouseenter="$emit('hover', index)"
        @click="$emit('choose', block)"
      >
        <component :is="block.icon" class="size-4 flex-none text-adm-meta" aria-hidden="true" />
        <span class="min-w-0"><span class="block text-[13px] text-adm-fg">{{ block.label }}</span><span class="block truncate text-xs text-adm-meta">{{ block.hint }}</span></span>
      </li>
    </ul>
    <p v-else :class="[admPopover, 'w-80 px-3 py-2 text-adm-meta']">Ningún bloque coincide.</p>
  </div>
</template>
