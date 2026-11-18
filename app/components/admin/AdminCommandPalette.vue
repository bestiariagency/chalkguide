<script setup lang="ts">
import { DialogClose, DialogContent, DialogDescription, DialogOverlay, DialogPortal, DialogRoot, DialogTitle } from 'reka-ui'
import { Loader2, Search, TriangleAlert } from 'lucide-vue-next'
import { SCOPES } from '~/utils/admin-search'

/**
 * ⌘K palette (README §15): sections («Ir a»), create shortcuts and content search (articles, fichas, pages, agenda, media).
 * Combobox pattern: focus stays in the input, `aria-activedescendant` points at the active option. All text from the
 * server (titles, snippets, keys) is painted with interpolation, never as HTML.
 */
const { paletteOpen } = useAdminPalette()
const pal = useAdminPaletteCombobox()
const { query, scope, search, groups, activeId } = pal
const input = ref<HTMLInputElement>()
const listId = 'admin-palette-list'
const busy = computed(() => search.status.value === 'loading')

function focusInput(event: Event) {
  event.preventDefault()
  input.value?.focus()
}
function pickScope(value: (typeof SCOPES)[number]['value']) {
  scope.value = value
  input.value?.focus()
}
const activeDom = computed(() => (activeId.value ? `pal-${activeId.value}` : undefined))
const scopeCount = (value: (typeof SCOPES)[number]['value']) => (pal.searching.value ? search.counts.value[value] : undefined)
</script>

<template>
  <DialogRoot v-model:open="paletteOpen">
    <DialogPortal>
      <DialogOverlay class="admin fixed inset-0 z-[60] animate-adm-fade bg-adm-scrim motion-reduce:animate-none" />
      <DialogContent
        class="admin fixed z-[60] flex flex-col overflow-hidden border border-adm-line bg-adm-elev font-sans text-[14px] leading-[22px] text-adm-fg shadow-adm-pop outline-none max-md:inset-0 max-md:h-dvh md:top-[12vh] md:left-1/2 md:max-h-[min(640px,76vh)] md:w-[640px] md:max-w-[calc(100%-2rem)] md:-translate-x-1/2 md:animate-adm-rise md:rounded-xl motion-reduce:animate-none"
        aria-describedby="admin-palette-desc"
        @open-auto-focus="focusInput"
        @escape-key-down="pal.onEscape"
      >
        <DialogTitle class="sr-only">Buscar o ir a…</DialogTitle>
        <DialogDescription id="admin-palette-desc" class="sr-only">Escribe para buscar contenido o filtrar las secciones del panel. Flechas para moverte, Intro para abrir.</DialogDescription>

        <div class="flex h-14 flex-none items-center gap-2 border-b border-adm-line px-4 md:h-[52px]">
          <Loader2 v-if="busy" class="size-4 flex-none animate-adm-spin text-adm-muted" aria-hidden="true" />
          <Search v-else class="size-4 flex-none text-adm-muted" aria-hidden="true" />
          <input
            ref="input"
            v-model="query"
            type="text"
            role="combobox"
            autocomplete="off"
            spellcheck="false"
            maxlength="100"
            aria-label="Buscar o ir a"
            aria-expanded="true"
            aria-autocomplete="list"
            :aria-controls="listId"
            :aria-activedescendant="activeDom"
            placeholder="Busca artículos, fichas, eventos, fotos o ve a una sección…"
            class="h-full min-w-0 flex-1 bg-transparent text-base outline-none placeholder:text-adm-muted md:text-sm"
            @keydown="pal.onKeydown"
          />
          <kbd :class="[admKbd, 'max-md:hidden']">esc</kbd>
          <DialogClose :class="[admBtnQuiet, 'md:hidden']">Cancelar</DialogClose>
        </div>

        <div role="group" aria-label="Ámbito de la búsqueda" class="flex flex-none gap-1.5 overflow-x-auto border-b border-adm-line px-3 py-2">
          <button
            v-for="s in SCOPES"
            :key="s.value"
            type="button"
            :aria-pressed="scope === s.value"
            :class="[admBtnPressed, 'flex-none px-2.5 text-xs md:h-7']"
            @click="pickScope(s.value)"
          >
            {{ s.label }}<span v-if="scopeCount(s.value) !== undefined" class="tabular-nums opacity-70">{{ scopeCount(s.value) }}</span>
          </button>
        </div>

        <div class="min-h-0 flex-1 overflow-y-auto">
          <div v-if="search.status.value === 'error'" role="alert" class="m-3 flex items-center gap-3 rounded-lg bg-adm-danger-soft p-3 text-[13px] text-adm-danger">
            <TriangleAlert class="size-4 flex-none" aria-hidden="true" />
            <p class="flex-1">No se ha podido buscar el contenido. Las secciones siguen funcionando.</p>
            <button type="button" :class="admBtnGhost" @click="search.retry()">Reintentar</button>
          </div>
          <div v-else-if="search.slow.value" class="space-y-1 p-3" aria-hidden="true">
            <span v-for="n in 3" :key="n" class="block h-10 rounded-md bg-adm-subtle" />
          </div>
          <div v-if="pal.noResults.value" class="px-4 py-4">
            <p class="text-[13px] font-medium">Nada coincide con «{{ pal.term.value }}»</p>
            <p class="text-xs text-adm-meta">Se busca en títulos, URLs, entradillas, textos de artículos, lugares, marcas y textos de fotos, en español y en inglés.</p>
          </div>

          <div :id="listId" role="listbox" aria-label="Resultados" :aria-busy="busy" :class="['pb-2', busy && search.groups.value.length && 'opacity-55']">
            <div v-for="group in groups" :key="group.id" role="group" :aria-labelledby="`pal-g-${group.id}`">
              <p :id="`pal-g-${group.id}`" class="px-4 pt-3 pb-1 text-xs font-semibold text-adm-meta">
                {{ group.label }}<span v-if="group.count !== undefined" class="ml-1.5 font-normal text-adm-muted tabular-nums">{{ group.count }}</span>
              </p>
              <AdminPaletteOption
                v-for="option in group.options"
                :key="option.id"
                :option="option"
                :active="option.id === activeId"
                @hover="activeId = option.id"
                @pick="pal.open(option)"
              />
            </div>
          </div>
        </div>

        <footer class="flex h-10 flex-none items-center gap-4 border-t border-adm-line bg-adm-side px-4 text-xs text-adm-meta max-md:hidden">
          <span><kbd :class="admKbd">↑↓</kbd> moverse</span>
          <span><kbd :class="admKbd">↵</kbd> abrir</span>
          <span><kbd :class="admKbd">⌘↵</kbd> en pestaña nueva</span>
          <span v-if="scope !== 'all'"><kbd :class="admKbd">⌫</kbd> volver a Todo</span>
        </footer>
        <p class="sr-only" aria-live="polite">{{ pal.announcement.value }}</p>
      </DialogContent>
    </DialogPortal>
  </DialogRoot>
</template>
