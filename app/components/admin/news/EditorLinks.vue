<script setup lang="ts">
import { Plus, X } from 'lucide-vue-next'
import type { Database } from '~/types/database.types'
import { searchRelated } from '~/services/admin/news'
import { MAX_LINKS, type NewsForm, type RelatedKind, type RelatedLink } from '~/utils/admin-news-form'

/** «Enlaces relacionados» (up to 3): fichas, articles and events of the guide that the card points to. Searches published ones only. */
const form = defineModel<NewsForm>('form', { required: true })
const client = useSupabaseClient<Database>()
const kind = ref<RelatedKind>('item')
const term = ref('')
const debounced = useDebouncedValue(term, 250)
const results = ref<RelatedLink[]>([])
const searching = ref(false)
const failed = ref(false)
const KINDS = [{ value: 'item' as const, label: 'Ficha' }, { value: 'article' as const, label: 'Artículo' }, { value: 'event' as const, label: 'Evento' }]
const kindLabel = (k: RelatedKind) => KINDS.find((x) => x.value === k)?.label ?? k
const full = computed(() => form.value.links.length >= MAX_LINKS)

watch([debounced, kind], async () => {
  failed.value = false
  if (debounced.value.trim().length < 2) {
    results.value = []
    return
  }
  searching.value = true
  try {
    results.value = (await searchRelated(client, kind.value, debounced.value)).filter((r) => !form.value.links.some((l) => l.kind === r.kind && l.id === r.id))
  } catch {
    results.value = []
    failed.value = true
  } finally {
    searching.value = false
  }
})
function add(link: RelatedLink) {
  if (full.value) return
  form.value.links = [...form.value.links, link]
  results.value = results.value.filter((r) => r !== link)
}
const uid = useId()
</script>

<template>
  <section class="space-y-3" :aria-labelledby="`${uid}-h`">
    <h3 :id="`${uid}-h`" class="text-sm font-semibold">Enlaces relacionados <span class="font-normal text-adm-meta">· hasta {{ MAX_LINKS }}</span></h3>
    <ul v-if="form.links.length" class="divide-y divide-adm-line rounded-lg border border-adm-line">
      <li v-for="(l, i) in form.links" :key="`${l.kind}-${l.id}`" class="flex items-center gap-2 px-3 py-1.5 text-sm">
        <span :class="[admChip, 'bg-adm-subtle text-adm-meta']">{{ kindLabel(l.kind) }}</span>
        <span class="min-w-0 flex-1 truncate">{{ l.label }}</span>
        <button type="button" :class="admIconBtn" :aria-label="`Quitar «${l.label}»`" @click="form.links = form.links.filter((_, n) => n !== i)"><X aria-hidden="true" /></button>
      </li>
    </ul>
    <div v-if="!full" class="space-y-2">
      <div class="flex gap-2">
        <div class="w-36 flex-none"><AdminSelect :model-value="kind" label="Tipo de enlace" hide-label :options="KINDS" @update:model-value="(v) => (kind = (v as RelatedKind) ?? 'item')" /></div>
        <div class="min-w-0 flex-1"><AdminTextField v-model="term" label="Buscar" type="search" placeholder="Buscar por nombre o título" autocomplete="off" /></div>
      </div>
      <p v-if="searching" class="text-xs text-adm-meta" role="status">Buscando…</p>
      <p v-else-if="failed" class="text-xs text-adm-danger" role="alert">No se ha podido buscar. Inténtalo de nuevo.</p>
      <ul v-else-if="results.length" class="divide-y divide-adm-line rounded-lg border border-adm-line">
        <li v-for="r in results" :key="r.id"><button type="button" :class="[admMenuItem, 'h-auto min-h-8 py-1']" @click="add(r)"><Plus aria-hidden="true" /><span class="min-w-0 flex-1 truncate">{{ r.label }}</span></button></li>
      </ul>
      <p v-else-if="term.trim().length >= 2" class="text-xs text-adm-meta">Nada publicado coincide.</p>
    </div>
    <p v-else class="text-xs text-adm-meta">Ya hay {{ MAX_LINKS }} enlaces. Quita uno para añadir otro.</p>
  </section>
</template>
