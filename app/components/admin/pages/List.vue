<script setup lang="ts">
import { ChevronRight, EyeOff, Info, TriangleAlert } from 'lucide-vue-next'
import { PAGE_GROUPS, pageChip, pageIndexing, pageNote, type AdminPageRow, type PageDef } from '~/utils/admin-pages'

/**
 * The five fixed pages in two groups (docs/design/admin/paginas.html#listado). Not a data table:
 * with five rows there is nothing to search, filter, page or select. A table from 768 px, cards below.
 */
const props = defineProps<{ rows: { def: PageDef; row: AdminPageRow }[]; unpublishedLegal: number }>()
const emit = defineEmits<{ discard: [def: PageDef, row: AdminPageRow]; unpublish: [def: PageDef, row: AdminPageRow] }>()

const groups = computed(() => PAGE_GROUPS.map((group) => ({ ...group, items: props.rows.filter((r) => r.def.group === group.id) })).filter((g) => g.items.length))
const grid = 'md:grid md:grid-cols-[minmax(0,1fr)_180px_92px_40px] lg:grid-cols-[minmax(0,1fr)_190px_92px_140px_40px] xl:grid-cols-[minmax(0,1fr)_190px_92px_150px_140px_40px]'
const rowClass = `${grid} items-center gap-3 border-b border-adm-line px-4 py-2 min-h-14 hover:bg-adm-subtle`
const headClass = `${grid} min-h-9 items-center gap-3 border-b border-adm-line bg-adm-side px-4 text-xs font-medium text-adm-meta`
const href = (def: PageDef) => adminPath(`paginas/${def.key}`)
</script>

<template>
  <div>
    <div v-if="unpublishedLegal" class="px-4 pt-4 md:px-6">
      <p class="flex gap-2.5 rounded-lg bg-adm-warn-soft px-3 py-2.5 text-sm" role="status">
        <TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />
        <span class="flex-1"><b>{{ unpublishedLegal === 1 ? '1 página legal sin publicar.' : `${unpublishedLegal} páginas legales sin publicar.` }}</b> Hasta que las publiques, el sitio muestra «Esta página aún no está publicada». Deben estar publicadas antes del lanzamiento.</span>
      </p>
    </div>

    <div class="max-w-[1440px] px-4 pt-4 md:px-6"><div class="hidden overflow-hidden rounded-lg border border-adm-line bg-adm-elev md:block" role="table" aria-label="Páginas del sitio">
      <div :class="headClass" role="row">
        <span role="columnheader">Página</span><span role="columnheader">Estado</span><span role="columnheader">Idiomas</span>
        <span role="columnheader" class="hidden xl:block">Buscadores</span><span role="columnheader" class="hidden lg:block">Actualizada</span>
        <span role="columnheader"><span class="sr-only">Acciones</span></span>
      </div>
      <div v-for="group in groups" :key="group.id" role="rowgroup">
        <div class="flex min-h-8 items-center border-b border-adm-line bg-adm-side px-4" role="row"><span role="cell" :class="admGroupLabel">{{ group.label }}</span></div>
        <div v-for="{ def, row } in group.items" :key="def.key" :class="rowClass" role="row">
          <span role="cell" class="min-w-0">
            <NuxtLink :to="href(def)" class="font-medium underline-offset-2 hover:underline">{{ row.title_es || def.label }}</NuxtLink>
            <span class="block truncate font-mono text-xs text-adm-meta">{{ def.routeEs }}<span class="text-adm-muted"> · {{ def.routeEn }}</span><template v-if="pageNote(row)"> · <span class="font-sans text-adm-warn">{{ pageNote(row) }}</span></template></span>
          </span>
          <span role="cell">
            <AdminStatusChip :status="pageChip(row).status" :label="pageChip(row).label" :changes="row.draft_changes" />
            <span v-if="!row.published" class="mt-1 block text-[11px] text-adm-meta">El sitio dice «aún no está publicada»</span>
          </span>
          <span role="cell"><AdminPagesLangs :has-en="row.published && row.has_en" /></span>
          <span role="cell" class="hidden text-sm xl:block" :class="pageIndexing(def, row).hidden && 'text-adm-meta'"><EyeOff v-if="pageIndexing(def, row).hidden" class="mr-1 -mt-0.5 inline size-3.5" aria-hidden="true" />{{ pageIndexing(def, row).text }}</span>
          <span role="cell" class="hidden text-sm text-adm-meta lg:block"><template v-if="row.empty && !row.published">—</template><AdminTime v-else :iso="row.updated_at" /></span>
          <span role="cell"><AdminPagesRowMenu :def="def" :row="row" @discard="emit('discard', def, row)" @unpublish="emit('unpublish', def, row)" /></span>
        </div>
      </div>
    </div>

    <div class="overflow-hidden rounded-lg border border-adm-line bg-adm-elev md:hidden">
      <template v-for="group in groups" :key="group.id">
        <p :class="[admGroupLabel, 'border-b border-adm-line bg-adm-side px-4 py-2 not-first:border-t']">{{ group.label }}</p>
        <ul class="divide-y divide-adm-line">
          <li v-for="{ def, row } in group.items" :key="def.key" class="flex items-center">
            <NuxtLink :to="href(def)" class="flex min-h-16 min-w-0 flex-1 items-center gap-3 px-4 py-3">
              <span class="min-w-0 flex-1">
                <span class="block font-medium">{{ row.title_es || def.label }}</span>
                <span class="block truncate font-mono text-xs text-adm-meta">{{ def.routeEs }}<template v-if="pageNote(row)"> · <span class="font-sans text-adm-warn">{{ pageNote(row) }}</span></template></span>
                <span class="mt-2 flex flex-wrap items-center gap-1.5"><AdminStatusChip :status="pageChip(row).status" :label="pageChip(row).label" :changes="row.draft_changes" /><AdminPagesLangs :has-en="row.published && row.has_en" /></span>
              </span>
              <ChevronRight class="size-4 flex-none text-adm-muted" aria-hidden="true" />
            </NuxtLink>
            <AdminPagesRowMenu :def="def" :row="row" class="mr-2" @discard="emit('discard', def, row)" @unpublish="emit('unpublish', def, row)" />
          </li>
        </ul>
      </template>
    </div>
    </div>

    <p class="flex gap-2 px-4 py-4 text-xs text-adm-meta md:px-6"><Info class="size-4 flex-none" aria-hidden="true" />Son rutas fijas del sitio: su URL no cambia y no se crean ni se borran desde aquí. Las legales nunca salen en buscadores.</p>
  </div>
</template>
