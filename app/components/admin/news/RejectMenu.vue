<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { X } from 'lucide-vue-next'
import { NEWS_REJECT_REASONS } from '~/utils/admin-news'

/** «Rechazar ▾»: choosing a reason rejects at once (the toast offers «Deshacer»). The trigger is the slot's button. */
defineProps<{ agent?: boolean; align?: 'start' | 'end'; side?: 'top' | 'bottom' }>()
const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ select: [reason: string | null] }>()
</script>

<template>
  <DropdownMenuRoot v-model:open="open">
    <DropdownMenuTrigger as-child><slot /></DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent :align="align ?? 'start'" :side="side ?? 'bottom'" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuLabel class="px-2 pt-1.5 pb-1 text-xs text-adm-meta">{{ agent ? 'Motivo · ayuda al agente' : 'Motivo' }}</DropdownMenuLabel>
        <DropdownMenuItem v-for="reason in NEWS_REJECT_REASONS" :key="reason.value" :class="[admMenuItem, 'cursor-pointer']" @select="emit('select', reason.value)">{{ reason.label }}</DropdownMenuItem>
        <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
        <DropdownMenuItem :class="[admMenuItem, 'cursor-pointer']" @select="emit('select', null)"><X aria-hidden="true" />Sin motivo</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
