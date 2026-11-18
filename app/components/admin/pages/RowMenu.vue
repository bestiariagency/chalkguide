<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { ExternalLink, Eye, FileMinus, GitCompareArrows, MoreHorizontal, Pencil, Undo2 } from 'lucide-vue-next'
import { LEGAL_NO_UNPUBLISH, type AdminPageRow, type PageDef } from '~/utils/admin-pages'

/**
 * Row actions of the pages list. There is no duplicate or delete (fixed keys, D34). "Despublicar…" is
 * offered only for published pages and shows disabled, with its reason, on the legal ones.
 */
const props = defineProps<{ def: PageDef; row: AdminPageRow }>()
const emit = defineEmits<{ discard: []; unpublish: [] }>()
const item = `${admMenuItem} cursor-pointer data-[disabled]:opacity-55`
const edit = computed(() => adminPath(`paginas/${props.def.key}`))
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de ${def.label}`"><MoreHorizontal aria-hidden="true" /></DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin w-64 font-sans']">
        <DropdownMenuItem as-child :class="item"><NuxtLink :to="edit"><Pencil aria-hidden="true" />Editar</NuxtLink></DropdownMenuItem>
        <DropdownMenuItem as-child :class="item"><NuxtLink :to="`${edit}/vista-previa`"><Eye aria-hidden="true" />Vista previa</NuxtLink></DropdownMenuItem>
        <DropdownMenuItem as-child :class="item">
          <a :href="def.routeEs" target="_blank" rel="noopener"><ExternalLink aria-hidden="true" />Ver en el sitio ({{ def.routeEs }})<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </DropdownMenuItem>
        <template v-if="row.draft_changes > 0">
          <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          <DropdownMenuItem as-child :class="item"><NuxtLink :to="`${edit}#cambios`"><GitCompareArrows class="!text-adm-st-rev" aria-hidden="true" />Ver cambios sin publicar</NuxtLink></DropdownMenuItem>
          <DropdownMenuItem :class="item" @select="emit('discard')"><Undo2 aria-hidden="true" />Descartar cambios…</DropdownMenuItem>
        </template>
        <template v-if="row.published">
          <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
          <DropdownMenuItem v-if="def.legal" :class="[item, 'h-auto! items-start py-2']" disabled>
            <FileMinus class="mt-0.5" aria-hidden="true" /><span>Despublicar<span class="block text-xs text-adm-meta">{{ LEGAL_NO_UNPUBLISH }}</span></span>
          </DropdownMenuItem>
          <DropdownMenuItem v-else :class="item" @select="emit('unpublish')"><FileMinus aria-hidden="true" />Despublicar…</DropdownMenuItem>
        </template>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
