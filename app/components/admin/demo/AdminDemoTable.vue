<script setup lang="ts">
import { DropdownMenuContent, DropdownMenuItem, DropdownMenuPortal, DropdownMenuRoot, DropdownMenuTrigger } from 'reka-ui'
import { Copy, MoreHorizontal, Pencil, Trash2 } from 'lucide-vue-next'

/** Showcase: data table in client mode with every state switchable. */
type Mode = 'ready' | 'loading' | 'empty' | 'error'
const mode = ref<Mode>('ready')
const rows = computed(() => (mode.value === 'empty' ? [] : DEMO_ARTICLES))
const clicked = ref('')
const { success } = useAdminToast()
const states: { value: Mode; label: string }[] = [
  { value: 'ready', label: 'Con datos' },
  { value: 'loading', label: 'Cargando' },
  { value: 'empty', label: 'Vacío' },
  { value: 'error', label: 'Error' },
]
</script>

<template>
  <div class="space-y-3">
    <div class="flex flex-wrap items-center gap-2" role="group" aria-label="Estado de la tabla de ejemplo">
      <button v-for="state in states" :key="state.value" type="button" :class="mode === state.value ? admBtnPrimary : admBtnGhost" :aria-pressed="mode === state.value" @click="mode = state.value">
        {{ state.label }}
      </button>
    </div>
    <AdminDataTable
      :rows="rows"
      :columns="DEMO_COLUMNS"
      :row-id="(row: DemoArticle) => row.id"
      :row-label="(row: DemoArticle) => row.title"
      caption="Artículos de ejemplo"
      selectable
      searchable
      clickable
      search-placeholder="Buscar por título"
      :loading="mode === 'loading'"
      :error="mode === 'error' ? 'No hemos podido conectar con el servidor.' : undefined"
      error-code="DEMO-500"
      empty-title="Aún no hay artículos"
      empty-description="Empieza por el que más te pregunten. Se guarda solo mientras escribes."
      @row-click="(row: DemoArticle) => (clicked = row.title)"
      @retry="mode = 'ready'"
    >
      <template #cell-status="{ row }"><AdminStatusChip :status="row.status" :changes="row.changes" /></template>
      <template #cell-updated="{ row }"><AdminTime :iso="row.updated" class="text-adm-meta" /></template>
      <template #cell-actions="{ row }">
        <DropdownMenuRoot>
          <DropdownMenuTrigger :class="admIconBtn" :aria-label="`Acciones de ${row.title}`"><MoreHorizontal aria-hidden="true" /></DropdownMenuTrigger>
          <DropdownMenuPortal>
            <DropdownMenuContent align="end" :side-offset="4" :class="[admPopover, 'admin font-sans']">
              <DropdownMenuItem :class="[admMenuItem, 'cursor-pointer']" @select="success(`Editar «${row.title}» (ejemplo)`)"><Pencil aria-hidden="true" />Editar</DropdownMenuItem>
              <DropdownMenuItem :class="[admMenuItem, 'cursor-pointer']" @select="success(`Duplicado «${row.title}» (ejemplo)`)"><Copy aria-hidden="true" />Duplicar</DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenuPortal>
        </DropdownMenuRoot>
      </template>
      <template #bulk="{ ids, clear }">
        <button type="button" :class="admBtnGhost" @click="success({ message: `${ids.length} elementos archivados (ejemplo)`, action: { label: 'Deshacer', run: () => {} } }); clear()">Archivar</button>
        <button type="button" :class="admBtnDangerGhost"><Trash2 aria-hidden="true" />Eliminar…</button>
      </template>
    </AdminDataTable>
    <p class="text-xs text-adm-meta" role="status">Última fila abierta: {{ clicked || 'ninguna' }}. Atajos: <kbd :class="admKbd">/</kbd> busca, Intro en el título abre la fila.</p>
  </div>
</template>
