<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { Ban, CopyPlus, ExternalLink, Link, MoreHorizontal, Pencil, Trash2, Undo2 } from 'lucide-vue-next'
import { isPublished, type AdminEvent } from '~/utils/admin-events'
import { monthPath } from '~/utils/admin-madrid'

/**
 * Row actions: Editar, Duplicar (otra fecha), Ver en el sitio, Abrir la web del organizador, Retirar de la
 * agenda (published, not past), Marcar como cancelado / Volver a la agenda (published), Eliminar.
 * A published event is not deleted from here: it is withdrawn (or cancelled) first.
 */
const props = defineProps<{ event: AdminEvent }>()
const emit = defineEmits<{ edit: []; duplicate: []; retire: []; cancel: []; uncancel: []; remove: [] }>()
const item = `${admMenuItem} cursor-pointer data-[disabled]:[&_svg]:opacity-45`
const published = computed(() => isPublished(props.event))
const canRetire = computed(() => published.value && !props.event.isPast)
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de «${event.titleEs}»`"><MoreHorizontal aria-hidden="true" /></DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuItem :class="item" @select="emit('edit')"><Pencil aria-hidden="true" />Editar</DropdownMenuItem>
        <DropdownMenuItem :class="item" @select="emit('duplicate')"><CopyPlus aria-hidden="true" />Duplicar (otra fecha)</DropdownMenuItem>
        <DropdownMenuItem v-if="published && !event.isPast" as-child :class="item">
          <a :href="monthPath(event.startsAt)" target="_blank" rel="noopener"><ExternalLink aria-hidden="true" />Ver en el sitio<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </DropdownMenuItem>
        <DropdownMenuItem v-if="event.url" as-child :class="item">
          <a :href="event.url" target="_blank" :rel="event.source === 'agent' ? SOURCE_LINK_REL : 'noopener noreferrer'"><Link aria-hidden="true" />Abrir web del organizador<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </DropdownMenuItem>
        <template v-if="published && !event.isPast">
          <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          <DropdownMenuItem v-if="event.status === 'cancelled'" :class="item" @select="emit('uncancel')"><Undo2 aria-hidden="true" />Volver a la agenda</DropdownMenuItem>
          <DropdownMenuItem v-else-if="!event.isPast" :class="item" @select="emit('cancel')"><Ban aria-hidden="true" />Marcar como cancelado</DropdownMenuItem>
          <DropdownMenuItem v-if="canRetire" :class="item" @select="emit('retire')"><Undo2 aria-hidden="true" />Retirar de la agenda</DropdownMenuItem>
        </template>
        <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
        <DropdownMenuItem :class="[item, 'text-adm-danger! [&_svg]:text-adm-danger!']" :disabled="published" @select="emit('remove')">
          <Trash2 aria-hidden="true" />
          <span class="flex flex-col"><span :class="published && 'opacity-45'">Eliminar…</span><span v-if="published" class="text-xs text-adm-meta">{{ event.isPast ? 'Los pasados se quedan como historial' : 'Retíralo antes' }}</span></span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
