<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItemIndicator, DropdownMenuPortal, DropdownMenuRadioGroup, DropdownMenuRadioItem, DropdownMenuRoot, DropdownMenuTrigger, ToolbarButton } from 'reka-ui'
import type { Editor } from '@tiptap/vue-3'
import { Check, ChevronDown } from 'lucide-vue-next'
import { TURN_INTO, applyBlock, currentBlock } from '~/utils/article-blocks'

/** "Párrafo ▾": turns the current block into paragraph, heading 2/3 or quote (radio menu, inside the toolbar's roving focus). */
const props = defineProps<{ editor: Editor | null; tick: number; disabled?: boolean }>()

const current = computed(() => currentBlock((name, attrs) => (props.tick >= 0 ? !!props.editor?.isActive(name, attrs) : false)))

function turn(key: unknown) {
  const block = TURN_INTO.find((b) => b.key === key)
  if (props.editor && block) applyBlock(props.editor.chain().focus(), block.key as 'paragraph').run()
}
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger as-child>
      <ToolbarButton :class="[admBtnQuiet, 'flex-none !px-2']" :aria-label="`Tipo de bloque: ${current.label}`" :disabled="disabled">
        {{ current.label }}<ChevronDown class="!size-3.5" aria-hidden="true" />
      </ToolbarButton>
    </DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="start" :side-offset="4" :class="[admPopover, 'admin w-56 font-sans']">
        <DropdownMenuRadioGroup :model-value="current.value" @update:model-value="turn">
          <DropdownMenuRadioItem v-for="block in TURN_INTO" :key="block.key" :value="block.key" :class="[admMenuItem, 'cursor-pointer']">
            <component :is="block.icon" aria-hidden="true" />
            <span class="min-w-0 flex-1"><span class="block">{{ block.label }}</span></span>
            <DropdownMenuItemIndicator><Check class="!text-adm-fg" aria-hidden="true" /></DropdownMenuItemIndicator>
          </DropdownMenuRadioItem>
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
