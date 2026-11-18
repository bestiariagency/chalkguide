<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { Copy, ExternalLink, GitCompareArrows, MoreHorizontal, Pencil, Trash2, Undo2, FileMinus } from 'lucide-vue-next'
import type { AdminArticleRow } from '~/utils/admin-articles'

/**
 * Row actions of the articles list. Live articles are never deleted here (they change through drafts
 * in the editor; "Despublicar…" takes them off the site); "Ver cambios" and "Descartar" only appear
 * when there are unpublished changes.
 */
const props = defineProps<{ row: AdminArticleRow; live: boolean }>()
const emit = defineEmits<{ duplicate: []; discard: []; remove: []; unpublish: [] }>()
const item = `${admMenuItem} cursor-pointer data-[disabled]:opacity-45`
const editHref = computed(() => adminPath(`articulos/${props.row.id}`))
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de ${row.title_es}`">
      <MoreHorizontal aria-hidden="true" />
    </DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuItem as-child :class="item">
          <NuxtLink :to="editHref"><Pencil aria-hidden="true" />Editar</NuxtLink>
        </DropdownMenuItem>
        <DropdownMenuItem v-if="live" as-child :class="item">
          <a :href="`/blog/${row.slug_es}`" target="_blank" rel="noopener"><ExternalLink aria-hidden="true" />Ver en el sitio<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </DropdownMenuItem>
        <template v-if="row.changes > 0">
          <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          <DropdownMenuItem as-child :class="item">
            <NuxtLink :to="`${editHref}#cambios`"><GitCompareArrows class="!text-adm-st-rev" aria-hidden="true" />Ver cambios sin publicar</NuxtLink>
          </DropdownMenuItem>
          <DropdownMenuItem :class="item" @select="emit('discard')"><Undo2 aria-hidden="true" />Descartar cambios…</DropdownMenuItem>
        </template>
        <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
        <DropdownMenuItem :class="item" @select="emit('duplicate')"><Copy aria-hidden="true" />Duplicar</DropdownMenuItem>
        <DropdownMenuItem v-if="live" :class="item" @select="emit('unpublish')"><FileMinus aria-hidden="true" />Despublicar…</DropdownMenuItem>
        <DropdownMenuItem :class="[item, '!text-adm-danger [&_svg]:!text-adm-danger']" :disabled="live" @select="emit('remove')">
          <Trash2 aria-hidden="true" />Eliminar…<span v-if="live" class="sr-only"> (no disponible: está publicado)</span>
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
