<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuLabel, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { CalendarX, CircleOff, Copy, Lock, MapPinOff, X } from 'lucide-vue-next'
import { EVENT_REJECT_REASONS } from '~/utils/admin-events'

/**
 * "Descartar ▾": choosing a reason discards at once (the toast offers "Deshacer"). The trigger is the slot's
 * button. `expired` is not offered: the nightly job sets it.
 */
defineProps<{ agent?: boolean; align?: 'start' | 'end' }>()
const open = defineModel<boolean>('open', { default: false })
const emit = defineEmits<{ select: [reason: string | null] }>()
const icons = { copy: Copy, 'circle-off': CircleOff, lock: Lock, 'map-pin-off': MapPinOff, 'calendar-x': CalendarX }
</script>

<template>
  <DropdownMenuRoot v-model:open="open">
    <DropdownMenuTrigger as-child><slot /></DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent :align="align ?? 'start'" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuLabel class="px-2 pt-1.5 pb-1 text-xs text-adm-meta">{{ agent ? 'Motivo · ayuda al agente' : 'Motivo' }}</DropdownMenuLabel>
        <DropdownMenuItem v-for="reason in EVENT_REJECT_REASONS" :key="reason.value" :class="[admMenuItem, 'cursor-pointer']" @select="emit('select', reason.value)">
          <component :is="icons[reason.icon]" aria-hidden="true" />{{ reason.label }}
        </DropdownMenuItem>
        <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
        <DropdownMenuItem :class="[admMenuItem, 'cursor-pointer']" @select="emit('select', null)"><X aria-hidden="true" />Descartar sin motivo</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
