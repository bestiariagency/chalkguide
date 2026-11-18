<script setup lang="ts">
import { Pencil, Plus, Trash2 } from 'lucide-vue-next'
import type { NewsCategory } from '~/utils/admin-news'

/**
 * Categories of news (README §19.2): sortable list with Spanish and English names and the count. They are not the blog's. Deleting
 * one that has news asks where to move them (`delete_news_category`). The key is the stable slug the agent uses: it is made
 * when the category is created and does not change when renamed.
 */
const props = defineProps<{ items: NewsCategory[]; counts: Record<string, number>; busy: boolean; error?: string }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{
  'update:items': [items: NewsCategory[]]
  reorder: [items: NewsCategory[]]
  create: [es: string, en: string]
  rename: [category: NewsCategory, es: string, en: string]
  remove: [category: NewsCategory, reassignTo: string | undefined]
}>()
const list = computed({ get: () => props.items, set: (v) => emit('update:items', v) })

const editing = ref<NewsCategory | 'new'>()
const es = ref('')
const en = ref('')
const removing = ref<NewsCategory>()
const count = (c: NewsCategory) => props.counts[c.id] ?? 0

function start(category: NewsCategory | 'new') {
  editing.value = category
  es.value = category === 'new' ? '' : category.labelEs
  en.value = category === 'new' ? '' : category.labelEn
}
function submit() {
  if (!es.value.trim() || props.busy) return
  if (editing.value === 'new') emit('create', es.value, en.value)
  else if (editing.value) emit('rename', editing.value, es.value, en.value)
  editing.value = undefined
}
const targets = computed(() => props.items.filter((c) => c.id !== removing.value?.id).map((c) => ({ value: c.id, label: c.labelEs })))
function confirmRemove(to?: string) {
  if (removing.value) emit('remove', removing.value, to)
  removing.value = undefined
}
</script>

<template>
  <AdminModal v-model:open="open" placement="right" title="Categorías de noticias" :busy="busy">
    <div class="space-y-3">
      <p class="text-xs text-adm-meta">Son distintas de las del blog. Arrastra para cambiar el orden de los filtros de /noticias. El agente solo puede usar estas.</p>
      <p v-if="error" class="rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] text-adm-danger" role="alert">{{ error }}</p>
      <AdminSortableList v-model:items="list" label="Categorías de noticias, ordenables" :item-key="(c: NewsCategory) => c.id" :item-label="(c: NewsCategory) => c.labelEs" @reorder="(next) => emit('reorder', next)">
        <template #item="{ item }">
          <div class="flex min-w-0 items-center gap-2">
            <span class="min-w-0 flex-1 truncate text-sm">{{ item.labelEs }} <span class="text-xs text-adm-meta" lang="en">· {{ item.labelEn }}</span></span>
            <span class="text-xs text-adm-meta tabular-nums">{{ count(item) }}</span>
            <button type="button" :class="admIconBtn" :aria-label="`Editar ${item.labelEs}`" @click="start(item)"><Pencil aria-hidden="true" /></button>
            <button type="button" :class="admIconBtn" :disabled="items.length <= 1" :aria-label="`Eliminar ${item.labelEs}`" @click="removing = item"><Trash2 aria-hidden="true" /></button>
          </div>
        </template>
      </AdminSortableList>
      <form v-if="editing" class="space-y-3 rounded-lg border border-adm-line p-3" @submit.prevent="submit">
        <AdminTextField v-model="es" label="Nombre en español" lang="ES" required :max="40" data-autofocus />
        <AdminTextField v-model="en" label="Nombre en inglés" lang="EN" :max="40" help="Vacío: se usa el español." />
        <div class="flex justify-end gap-2">
          <button type="button" :class="admBtnGhost" @click="editing = undefined">Cancelar</button>
          <button type="submit" :class="admBtnPrimary" :disabled="busy || !es.trim()">Guardar</button>
        </div>
      </form>
      <p class="text-xs text-adm-meta">Nombres provisionales: los cierra la revisión de textos. Borrar una categoría con noticias pide reasignarlas.</p>
    </div>
    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="busy || !!editing" @click="start('new')"><Plus aria-hidden="true" />Nueva categoría</button>
      <button type="button" :class="admBtnPrimary" @click="open = false">Hecho</button>
    </template>
  </AdminModal>

  <AdminConfirmDelete
    v-if="removing"
    :open="true"
    stacked
    :level="count(removing) ? 'reassign' : 'simple'"
    :title="`¿Eliminar la categoría «${removing.labelEs}»?`"
    :description="count(removing) ? `Tiene ${count(removing)} ${count(removing) === 1 ? 'noticia' : 'noticias'}. Elige a qué categoría moverlas.` : 'No tiene noticias. Se elimina sin más.'"
    :confirm-label="count(removing) ? 'Mover y eliminar' : 'Eliminar categoría'"
    :targets="targets"
    target-label="Mover las noticias a"
    :busy="busy"
    @update:open="(v: boolean) => !v && (removing = undefined)"
    @confirm="confirmRemove"
  />
</template>
