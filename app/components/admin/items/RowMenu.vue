<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { EyeOff, ExternalLink, GitCompareArrows, MoreHorizontal, Pencil, Trash2, Undo2 } from 'lucide-vue-next'
import type { AdminItemRow } from '~/utils/admin-items'
import type { ItemInfo } from '~/utils/item-spec'

/**
 * Row actions of the items list. A published item is never deleted (it is hidden); one with opinions
 * is never deleted either (the database refuses it), so "Eliminar" only exists for unpublished ones.
 */
const props = defineProps<{ row: AdminItemRow; info: ItemInfo }>()
const emit = defineEmits<{ discard: []; hide: []; remove: [] }>()
const item = `${admMenuItem} cursor-pointer data-[disabled]:opacity-45`
const editHref = computed(() => adminPath(`${props.info.route}/${props.row.id}`))
const blocked = computed(() => props.row.published || props.row.reviews > 0)
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de ${row.name}`"><MoreHorizontal aria-hidden="true" /></DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuItem as-child :class="item"><NuxtLink :to="editHref"><Pencil aria-hidden="true" />Editar</NuxtLink></DropdownMenuItem>
        <DropdownMenuItem v-if="row.published" as-child :class="item">
          <a :href="`${info.publicPath}/${row.slug}`" target="_blank" rel="noopener"><ExternalLink aria-hidden="true" />Ver en el sitio<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </DropdownMenuItem>
        <template v-if="row.changes > 0">
          <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          <DropdownMenuItem as-child :class="item"><NuxtLink :to="`${editHref}#cambios`"><GitCompareArrows class="!text-adm-st-rev" aria-hidden="true" />Ver cambios sin publicar</NuxtLink></DropdownMenuItem>
          <DropdownMenuItem :class="item" @select="emit('discard')"><Undo2 aria-hidden="true" />Descartar cambios…</DropdownMenuItem>
        </template>
        <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
        <DropdownMenuItem v-if="row.published" :class="item" @select="emit('hide')"><EyeOff aria-hidden="true" />Ocultar ficha…</DropdownMenuItem>
        <DropdownMenuItem :class="[item, '!text-adm-danger [&_svg]:!text-adm-danger']" :disabled="blocked" @select="emit('remove')">
          <Trash2 aria-hidden="true" />Eliminar…<span v-if="blocked" class="sr-only"> (no disponible: {{ row.published ? 'está publicada' : 'tiene opiniones' }})</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
