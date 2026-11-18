<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuSeparator, DropdownMenuTrigger } from 'reka-ui'
import { ExternalLink, Link, MoreHorizontal, Pencil, RotateCcw, Trash2, Undo2 } from 'lucide-vue-next'
import type { AdminNews } from '~/utils/admin-news'

/**
 * Row actions: Editar, Ver en el sitio (published), Abrir la fuente, Retirar (published → borrador), Recuperar (rejected),
 * Liberar para el agente (rejected by `wrong_data`), Eliminar… (not published; for an item of the agent the dialog offers «Rechazar en su lugar»:
 * it is never deleted, so the agent remembers it).
 */
const props = defineProps<{ news: AdminNews }>()
const emit = defineEmits<{ edit: []; retire: []; recover: []; release: []; remove: [] }>()
const item = `${admMenuItem} cursor-pointer`
const published = computed(() => props.news.status === 'published')
const href = computed(() => safeHref(props.news.sourceUrl))
const canRemove = computed(() => !published.value && (props.news.source === 'manual' || props.news.status === 'draft'))
const canRelease = computed(() => props.news.status === 'rejected' && props.news.source === 'agent' && props.news.rejectReason === 'wrong_data')
</script>

<template>
  <DropdownMenuRoot>
    <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de «${news.titleEs}»`"><MoreHorizontal aria-hidden="true" /></DropdownMenuTrigger>
    <DropdownMenuPortal>
      <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
        <DropdownMenuItem :class="item" @select="emit('edit')"><Pencil aria-hidden="true" />Editar</DropdownMenuItem>
        <DropdownMenuItem v-if="published" as-child :class="item">
          <a :href="`/noticias/${news.slug}`" target="_blank" rel="noopener"><ExternalLink aria-hidden="true" />Ver en el sitio<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </DropdownMenuItem>
        <DropdownMenuItem v-if="href" as-child :class="item">
          <a :href="href" target="_blank" :rel="SOURCE_LINK_REL"><Link aria-hidden="true" />Abrir la fuente · {{ sourceDomain(news.sourceUrl) }}<span class="sr-only"> (se abre en otra pestaña)</span></a>
        </DropdownMenuItem>
        <DropdownMenuSeparator class="my-1 h-px bg-adm-line" />
        <DropdownMenuItem v-if="published" :class="item" @select="emit('retire')"><Undo2 aria-hidden="true" />Retirar</DropdownMenuItem>
        <DropdownMenuItem v-if="news.status === 'rejected'" :class="item" @select="emit('recover')"><Undo2 aria-hidden="true" />Recuperar</DropdownMenuItem>
        <DropdownMenuItem v-if="canRelease" :class="item" @select="emit('release')"><RotateCcw aria-hidden="true" />Liberar para el agente</DropdownMenuItem>
        <DropdownMenuItem v-if="canRemove" :class="[item, 'text-adm-danger! [&_svg]:text-adm-danger!']" @select="emit('remove')"><Trash2 aria-hidden="true" />Eliminar…</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenuPortal>
  </DropdownMenuRoot>
</template>
