<script setup lang="ts">
import { Search } from 'lucide-vue-next'
import type { Editor } from '@tiptap/vue-3'
import type { ItemChoice } from '~/services/admin/article-items'
import { ITEM_KIND_LABEL, type ItemKind } from '~/utils/article-embeds'

/** Picks an item (guide.items) by name and inserts its card at the cursor. */
const props = defineProps<{ editor: Editor | null }>()
const open = defineModel<boolean>('open', { default: false })

const { query, kind, items, pending, failed, reload } = useItemPicker(open)

function pick(item: ItemChoice) {
  props.editor?.chain().focus().insertContent({ type: 'itemCard', attrs: { kind: item.kind, slug: item.slug, name: item.name } }).run()
  open.value = false
}
const KINDS: { value: ItemKind | null; label: string }[] = [
  { value: null, label: 'Todos' },
  { value: 'gym', label: 'Rocódromos' },
  { value: 'resoler', label: 'Resoladores' },
  { value: 'shoe', label: 'Pies de gato' },
]
const count = useDebouncedValue(() => (pending.value ? '' : (items.value.length === 1 ? '1 resultado' : `${items.value.length} resultados`)), 500)
</script>

<template>
  <AdminModal v-model:open="open" title="Tarjeta de ficha" size="md" description="Elige el rocódromo, resolador o pie de gato que quieres enseñar dentro del texto.">
    <div class="relative mb-4">
      <Search class="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-adm-muted max-md:hidden" aria-hidden="true" />
      <input v-model="query" type="search" aria-label="Buscar ficha por nombre" placeholder="Buscar por nombre" :class="[admInput, 'md:pl-8']" data-autofocus />
    </div>
    <div class="mb-4 flex flex-wrap gap-1.5" role="group" aria-label="Filtrar por tipo">
      <button
        v-for="k in KINDS"
        :key="k.label"
        type="button"
        :aria-pressed="kind === k.value"
        class="min-h-8 rounded-full border px-3 text-xs font-medium focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-adm-acc max-md:min-h-11"
        :class="kind === k.value ? 'border-adm-primary bg-adm-primary text-adm-on-primary' : 'border-adm-line-strong bg-adm-elev text-adm-fg hover:bg-adm-subtle'"
        @click="kind = k.value"
      >{{ k.label }}</button>
    </div>
    <p class="sr-only" role="status">{{ count }}</p>
    <AdminStateBlock v-if="failed" kind="error" title="No se han podido cargar las fichas" @retry="reload" />
    <p v-else-if="pending && !items.length" class="py-8 text-center text-sm text-adm-meta" role="status">Cargando fichas…</p>
    <AdminStateBlock v-else-if="!items.length && !query && kind" kind="empty" title="No hay fichas de este tipo">
      <button type="button" :class="admBtnGhost" @click="kind = null">Ver todos</button>
    </AdminStateBlock>
    <AdminStateBlock v-else-if="!items.length" kind="empty" :title="query ? 'Sin resultados' : 'Todavía no hay fichas'" :description="query ? 'Prueba con otro nombre.' : 'Crea una ficha y vuelve aquí.'" />
    <ul v-else class="divide-y divide-adm-line rounded-lg border border-adm-line" :aria-busy="pending">
      <li v-for="item in items" :key="item.id">
        <button type="button" class="flex min-h-11 w-full items-center gap-3 px-3 py-2 text-left hover:bg-adm-subtle focus-visible:outline-2 focus-visible:-outline-offset-2 focus-visible:outline-adm-acc" @click="pick(item)">
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-medium">{{ item.name }}</span>
            <span v-if="!item.published" class="block truncate text-xs text-adm-warn">Sin publicar · el enlace no funcionará hasta publicarla</span>
            <span v-else-if="item.summary" class="block truncate text-xs text-adm-meta">{{ item.summary }}</span>
          </span>
          <span class="flex-none rounded bg-adm-subtle px-1.5 py-0.5 text-xs text-adm-fg">{{ ITEM_KIND_LABEL[item.kind] }}</span>
        </button>
      </li>
    </ul>
    <template #footer>
      <button type="button" :class="admBtnGhost" @click="open = false">Cancelar</button>
    </template>
  </AdminModal>
</template>
