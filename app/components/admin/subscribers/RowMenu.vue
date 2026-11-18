<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { Copy, FileSearch, MegaphoneOff, MoreHorizontal, Trash2, UserX } from 'lucide-vue-next'
import { canUnsubscribe, type Subscriber } from '~/utils/admin-subscribers'
import { canWithdrawRelated } from '~/utils/admin-subscribers-related'

/** Row actions: Ver prueba de consentimiento, Copiar email, Dar de baja… and Retirar afines… (each only when possible), and Suprimir datos (RGPD)…. */
const props = defineProps<{ subscriber: Subscriber }>()
const emit = defineEmits<{ open: []; copy: []; unsubscribe: []; withdraw: []; erase: [] }>()
const item = `${admMenuItem} cursor-pointer`
const unsubscribable = computed(() => canUnsubscribe(props.subscriber))
const withdrawable = computed(() => canWithdrawRelated(props.subscriber))
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de ${subscriber.email}`"><MoreHorizontal aria-hidden="true" /></DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuItem :class="item" @select="emit('open')"><FileSearch aria-hidden="true" />Ver prueba de consentimiento</DropdownMenuItem>
        <DropdownMenuItem :class="item" @select="emit('copy')"><Copy aria-hidden="true" />Copiar email</DropdownMenuItem>
        <template v-if="unsubscribable || withdrawable">
          <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          <DropdownMenuItem v-if="unsubscribable" :class="item" @select="emit('unsubscribe')"><UserX aria-hidden="true" />Dar de baja…</DropdownMenuItem>
          <DropdownMenuItem v-if="withdrawable" :class="item" @select="emit('withdraw')"><MegaphoneOff aria-hidden="true" />Retirar afines…</DropdownMenuItem>
        </template>
        <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
        <DropdownMenuItem :class="[item, 'text-adm-danger! [&_svg]:text-adm-danger!']" @select="emit('erase')"><Trash2 aria-hidden="true" />Suprimir datos (RGPD)…</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
