<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuTrigger } from 'reka-ui'
import { ChevronDown } from 'lucide-vue-next'
import { PHOTO_REJECT_REASONS } from '~/utils/admin-reviews'

/** "Rechazar ▾" / "Retirar ▾": choosing a reason acts at once (the toast offers "Deshacer" when it can). */
defineProps<{ label: string; photoLabel: string; disabled?: boolean; quiet?: boolean; hint?: string }>()
const emit = defineEmits<{ select: [reason: string] }>()
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="[quiet ? admBtnQuiet : admBtnGhost, 'h-8 max-lg:h-11']" :disabled="disabled" :aria-label="`${label} ${photoLabel}`">
      {{ label }}<ChevronDown aria-hidden="true" />
    </DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="start" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuLabel v-if="hint" class="px-3 py-1.5 text-xs text-adm-meta">{{ hint }}</DropdownMenuLabel>
        <DropdownMenuItem v-for="reason in PHOTO_REJECT_REASONS" :key="reason.value" :class="[admMenuItem, 'cursor-pointer']" @select="emit('select', reason.value)">
          {{ reason.label }}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
