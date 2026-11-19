<script setup lang="ts">
import { Check, EyeOff, Undo2 } from 'lucide-vue-next'
import { newsReasonLabel, scopeLabel, type AdminNews, type NewsView } from '~/utils/admin-news'
import { emptyAdminQuery } from '~/utils/admin-table'

/**
 * Publicadas, Rechazadas and Todas: `AdminDataTable` (cards under 768). The date is the publication (or the last change in
 * the other views); «Indexación» tells whether the card has a «Nota de Xavi» of enough length (D73/D79). The database already
 * filtered and ordered the rows.
 */
const props = defineProps<{ rows: readonly AdminNews[]; view: NewsView; loading: boolean; busy: boolean; labels: Record<string, string>; error?: string; errorCode?: string }>()
const emit = defineEmits<{ open: [news: AdminNews]; retire: [news: AdminNews]; recover: [news: AdminNews]; release: [news: AdminNews]; remove: [news: AdminNews]; retry: [] }>()

const query = ref<AdminTableQuery>(emptyAdminQuery(25))
const rejected = computed(() => props.view === 'rechazadas')
const dateOf = (n: AdminNews) => (n.status === 'published' ? n.publishedAt : n.updatedAt) ?? n.createdAt
const columns = computed<AdminColumn<AdminNews>[]>(() => [
  { key: 'date', label: rejected.value ? 'Rechazada' : props.view === 'todas' ? 'Fecha' : 'Publicada', sortable: true, searchable: false, card: true, minWidth: 'w-32', accessor: dateOf },
  { key: 'title', label: 'Noticia', pin: 'left', minWidth: 'min-w-72', accessor: (n) => `${n.titleEs} ${n.sourceName}` },
  ...(props.view === 'todas' ? [{ key: 'status', label: 'Estado', card: true, searchable: false, minWidth: 'w-32' }] : []),
  { key: 'category', label: 'Categoría', searchable: false, hideBelow: 'lg' as const, card: true, accessor: (n) => props.labels[n.categoryKey] ?? n.categoryKey },
  { key: 'scope', label: 'Alcance', searchable: false, hideBelow: 'lg' as const, accessor: (n) => scopeLabel(n.scope) },
  rejected.value
    ? { key: 'reason', label: 'Motivo', searchable: false, card: true, accessor: (n) => newsReasonLabel(n.rejectReason) }
    : { key: 'index', label: 'Indexación', searchable: false, card: true, accessor: (n) => n.indexable },
  { key: 'origin', label: 'Origen', searchable: false, hideBelow: 'xl' as const, accessor: (n) => n.source },
  { key: 'lang', label: 'EN', searchable: false, accessor: (n) => n.hasEn },
  { key: 'actions', label: 'Acciones', hideLabel: true, pin: 'right', searchable: false },
])
const caption = computed(() => ({ publicadas: 'Noticias publicadas, la más reciente primero', rechazadas: 'Noticias rechazadas', todas: 'Todas las noticias', revisar: 'Noticias por revisar' })[props.view])
const canRelease = (n: AdminNews) => n.status === 'rejected' && n.source === 'agent' && n.rejectReason === 'wrong_data'
</script>

<template>
  <AdminDataTable
    :key="view"
    v-model:query="query"
    :rows="rows"
    :columns="columns"
    :row-id="(n: AdminNews) => n.id"
    :row-label="(n: AdminNews) => `«${n.titleEs}»`"
    primary-key="title"
    clickable
    :caption="caption"
    :loading="loading"
    :error="error"
    :error-code="errorCode"
    @row-click="emit('open', $event)"
    @retry="emit('retry')"
  >
    <template #empty><slot name="empty" /></template>
    <template #cell-date="{ row }"><span class="tabular-nums">{{ adminDate(dateOf(row)) }}</span></template>
    <template #cell-title="{ row }">
      <span class="block max-w-full md:max-w-[36rem]">
        <span class="block truncate max-md:line-clamp-2 max-md:whitespace-normal">{{ row.titleEs }}</span>
        <span class="block truncate text-xs font-normal text-adm-meta">Fuente: {{ row.sourceName }}</span>
      </span>
    </template>
    <template #cell-status="{ row }"><AdminNewsChip :status="row.status" /></template>
    <template #cell-category="{ row }"><span class="text-adm-meta">{{ labels[row.categoryKey] ?? row.categoryKey }}</span></template>
    <template #cell-scope="{ row }"><span class="text-adm-meta">{{ scopeLabel(row.scope) }}</span></template>
    <template #cell-reason="{ row }"><span class="text-adm-meta">{{ newsReasonLabel(row.rejectReason) }}</span></template>
    <template #cell-index="{ row }">
      <span v-if="row.indexable" :class="[admChip, 'bg-adm-st-pub-bg text-adm-st-pub']"><Check aria-hidden="true" />Con aporte · indexable</span>
      <span v-else :class="[admChip, 'bg-adm-subtle text-adm-meta']"><EyeOff aria-hidden="true" />noindex</span>
    </template>
    <template #cell-origin="{ row }"><AdminNewsOrigin :source="row.source" short /></template>
    <template #cell-lang="{ row }"><AdminNewsLang :has="row.hasEn" /></template>
    <template #cell-actions="{ row }">
      <span class="inline-flex items-center gap-1">
        <button v-if="row.status === 'rejected'" type="button" :class="admBtnQuiet" :disabled="busy" :aria-label="`Recuperar «${row.titleEs}»`" @click="emit('recover', row)"><Undo2 aria-hidden="true" />Recuperar</button>
        <button v-if="canRelease(row)" type="button" :class="admBtnQuiet" :disabled="busy" :aria-label="`Liberar «${row.titleEs}» para el agente`" @click="emit('release', row)">Liberar</button>
        <AdminNewsRowMenu :news="row" @edit="emit('open', row)" @retire="emit('retire', row)" @recover="emit('recover', row)" @release="emit('release', row)" @remove="emit('remove', row)" />
      </span>
    </template>
  </AdminDataTable>
</template>
