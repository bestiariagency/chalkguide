<script setup lang="ts">
import { DropdownMenuCheckboxItem, DropdownMenuContent, DropdownMenuItemIndicator, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuTrigger } from 'reka-ui'
import { Check, ChevronDown } from 'lucide-vue-next'
import type { Component } from 'vue'

/** Multiple choice filter (Origen, Texto aceptado, Estado): checkboxes with a count each; the menu stays open while ticking. */
defineProps<{ label: string; icon: Component; options: readonly { value: string; label: string; count?: number }[]; selected: readonly string[] }>()
const emit = defineEmits<{ toggle: [value: string, on: boolean] }>()
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="admBtnGhost" :aria-label="selected.length ? `${label}, ${selected.length} seleccionados` : label">
      <component :is="icon" aria-hidden="true" />{{ label }}<span v-if="selected.length" class="rounded-full bg-adm-acc-soft px-1.5 text-adm-acc tabular-nums">{{ selected.length }}</span><ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" />
    </DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="start" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuCheckboxItem
          v-for="option in options"
          :key="option.value"
          :model-value="selected.includes(option.value)"
          :class="[admMenuItem, 'cursor-pointer']"
          @select.prevent
          @update:model-value="(on: boolean) => emit('toggle', option.value, on)"
        >
          <span class="grid size-4 place-items-center rounded border border-adm-control"><DropdownMenuItemIndicator><Check class="size-3! text-adm-acc!" aria-hidden="true" /></DropdownMenuItemIndicator></span>
          <span class="flex-1">{{ option.label }}</span><span v-if="option.count != null" class="text-adm-muted tabular-nums">{{ option.count }}</span>
        </DropdownMenuCheckboxItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
