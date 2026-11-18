<script setup lang="ts">
import { Check, CircleCheck, EyeOff, GitBranch, ImagePlus, Loader2, OctagonAlert, Plus, Send, Star, Trash2, Upload, X } from 'lucide-vue-next'
import { emptyAdminQuery } from '~/utils/admin-table'
import { needsVerification, type AdminItemRow } from '~/utils/admin-items'
import { blockerList } from '~/utils/admin-import-texts'
import { readinessOf, readyText } from '~/utils/admin-publish-batch'
import type { ItemInfo } from '~/utils/item-spec'

/**
 * Items list, shared by gyms (F6.7) and resolers (F6.8). Client-side table: the guide has dozens of
 * items. Published ones are never deleted here (they are hidden) and edits to them go through drafts in the editor.
 */
const props = defineProps<{ info: ItemInfo }>()
const items = useAdminItems(props.info)
const { view, featuredOnly, visible, counts } = items
const route = useRoute()
const batch = useAdminPublishBatch(props.info, items.rows, () => items.list.refresh())
const importFilter = useAdminImportFilter(props.info)
// Deep link `?estado=` (Inicio, README §14.2).
const ESTADOS = { cambios: 'changes', 'sin-publicar': 'draft', 'sin-verificar': 'stale' } as const
onMounted(() => {
  const estado = route.query.estado
  if (typeof estado === 'string' && estado in ESTADOS) view.value = ESTADOS[estado as keyof typeof ESTADOS]
  if (route.hash === '#cambios') view.value = 'changes'
  if (importFilter.active.value) view.value = 'draft'
})

/** "Para publicar" filter (README §13.7): acts on unpublished items only; published ones always pass. */
const readyFilter = ref<'all' | 'ready' | 'missing'>('all')
const filtered = computed(() => items.filtering.value || readyFilter.value !== 'all' || importFilter.active.value)
function clearFilters() {
  items.clearFilters()
  readyFilter.value = 'all'
  importFilter.clear()
}
const READY_OPTIONS = [{ value: 'all' as const, label: 'Todas' }, { value: 'ready' as const, label: 'Listas' }, { value: 'missing' as const, label: 'Les falta algo' }]
const stateOf = (row: AdminItemRow) => readinessOf(row, batch.blockers.value)
const shown = computed(() =>
  visible.value.filter((row) => {
    if (importFilter.active.value && !importFilter.ids.value.has(row.id)) return false
    if (readyFilter.value === 'all' || row.published) return true
    const kind = stateOf(row).kind
    return readyFilter.value === 'ready' ? kind === 'ready' : kind === 'blocked'
  }),
)

const query = ref<AdminTableQuery>({ ...emptyAdminQuery(25), search: typeof route.query.q === 'string' ? route.query.q : '', sort: { id: 'updated', desc: true } })
const columns: AdminColumn<AdminItemRow>[] = [
  { key: 'name', label: 'Nombre', sortable: true, pin: 'left', minWidth: props.info.category === 'shoe' ? 'min-w-48' : 'min-w-64', accessor: (r) => `${r.name} ${r.slug} ${r.district ?? ''}` },
  { key: 'status', label: 'Estado', sortable: true, card: true, searchable: false, accessor: (r) => chip(r) },
  { key: 'ready', label: 'Para publicar', card: true, searchable: false, accessor: (r) => stateOf(r).kind },
  { key: 'district', label: props.info.placeLabel, sortable: true, searchable: false, accessor: (r) => r.district ?? '' },
  // Shoes only: without a cover first when sorting ascending.
  ...(props.info.category === 'shoe' ? [{ key: 'cover', label: 'Foto', sortable: true, card: true, searchable: false, accessor: (r: AdminItemRow) => (r.has_cover ? 1 : 0) }] : []),
  { key: 'lang', label: 'Idiomas', card: true, searchable: false, accessor: (r) => r.has_en },
  { key: 'verified', label: 'Verificada', sortable: true, card: true, searchable: false, accessor: (r) => r.verified_at ?? '' },
  { key: 'reviews', label: 'Opiniones', sortable: true, searchable: false, accessor: (r) => r.reviews },
  { key: 'updated', label: 'Actualizada', sortable: true, searchable: false, accessor: (r) => r.updated_at },
  { key: 'actions', label: 'Acciones', hideLabel: true, pin: 'right', searchable: false },
]

/** Unpublished with a publication date = it was live once, so it is hidden, not a new draft. */
const chip = (row: AdminItemRow) => (row.published ? (row.changes ? 'revised' : 'published') : row.published_at ? 'hidden' : 'draft')

const selectedIds = ref<string[]>([])
const selected = computed(() => visible.value.filter((row) => selectedIds.value.includes(row.id)))
const errorText = computed(() => (items.list.error.value ? itemErrorMessage(items.list.error.value, undefined, props.info.noun) : undefined))

const publishTargets = ref<AdminItemRow[]>([])
const publishOpen = ref(false)
const coversOpen = ref(false)
const coverTargets = ref<AdminItemRow[]>([])
function openPublish(targets: AdminItemRow[]) {
  publishTargets.value = targets
  publishOpen.value = true
}
function openCovers(targets: AdminItemRow[]) {
  coverTargets.value = targets.filter((row) => !row.has_cover)
  coversOpen.value = true
}
async function confirmPublish() {
  if (await batch.publish(publishTargets.value)) publishOpen.value = false
}
// Arriving from the result of an import (`?importacion=hoy&asignar=portadas|publicar=1`): open the action once the data is in.
const arrival = ref(importFilter.active.value ? String(route.query.asignar ?? (route.query.publicar ? 'publicar' : '')) : '')
watch([() => items.rows.value.length, () => importFilter.ids.value.size, () => batch.loading.value], () => {
  if (!arrival.value || items.list.status.value !== 'success' || batch.loading.value || importFilter.loading.value) return
  const imported = items.rows.value.filter((row) => importFilter.ids.value.has(row.id))
  if (arrival.value === 'portadas') openCovers(imported)
  else if (arrival.value === 'publicar') openPublish(imported)
  arrival.value = ''
}, { immediate: true })
const selectedPlan = computed(() => batch.planOf(selected.value))
const canPublish = computed(() => selectedPlan.value.ready.length + selectedPlan.value.changes.length > 0)
const publishHint = 'Nada de lo seleccionado se puede publicar: ya está publicado sin cambios, oculto o bloqueado'
const plan = computed(() => batch.planOf(publishTargets.value))

type Dialog = { kind: 'remove'; targets: AdminItemRow[] } | { kind: 'discard' | 'hide'; row: AdminItemRow }
const dialog = ref<Dialog>()
const open = computed({ get: () => !!dialog.value, set: (value) => { if (!value) dialog.value = undefined } })
const removing = computed(() => (dialog.value?.kind === 'remove' ? dialog.value.targets : []))
const blockers = computed(() => removing.value.filter((row) => row.published || row.reviews > 0))
const removeText = computed(() => {
  if (blockers.value.length) return 'No se pueden eliminar las fichas publicadas (se ocultan) ni las que tienen opiniones de usuarios. Quítalas de la selección y vuelve a intentarlo.'
  const names = removing.value.slice(0, 3).map((row) => `«${row.name}»`).join(', ')
  return `${names}${removing.value.length > 3 ? ` y ${removing.value.length - 3} más` : ''}. ${removing.value.length === 1 ? 'No está publicada ni tiene opiniones. Queda' : 'No están publicadas ni tienen opiniones. Quedan'} en el registro de actividad.`
})

async function confirmRemove() {
  if (await items.remove(removing.value)) {
    dialog.value = undefined
    selectedIds.value = []
  }
}
async function confirmDiscard() {
  if (dialog.value?.kind === 'discard' && (await items.discardChanges(dialog.value.row))) dialog.value = undefined
}
async function confirmHide() {
  if (dialog.value?.kind === 'hide' && (await items.hide(dialog.value.row))) dialog.value = undefined
}
const shortDate = adminDate
</script>

<template>
  <div>
    <AdminPageBar :title="info.title" :count="items.list.status.value === 'pending' ? undefined : items.rows.value.length">
      <NuxtLink :to="adminPath(`${info.route}/importar`)" :class="[admBtnGhost, 'max-md:hidden']"><Upload aria-hidden="true" />Importar</NuxtLink>
      <AdminExportsButton :target="info.category" :initial="itemsExportInitial(view)" />
      <button type="button" :class="admBtnPrimary" :disabled="items.busy.value" :aria-busy="items.busy.value || undefined" @click="items.create()">
        <Loader2 v-if="items.busy.value" class="animate-adm-spin" aria-hidden="true" /><Plus v-else aria-hidden="true" />
        <span class="max-sm:hidden">{{ info.newLabel }}</span><span class="sm:hidden">Nuevo</span>
      </button>
    </AdminPageBar>

    <AdminItemsViewTabs v-model="view" :counts="counts" />

    <div class="max-w-[1440px] px-4 py-4 md:px-6">
      <AdminDataTable
        v-model:query="query"
        :rows="shown"
        :columns="columns"
        :row-id="(row: AdminItemRow) => row.id"
        :row-label="(row: AdminItemRow) => `«${row.name}»`"
        :row-href="(row: AdminItemRow) => adminPath(`${info.route}/${row.id}`)"
        :caption="`${info.title}, ordenados por última actualización`"
        selectable
        feminine
        searchable
        :search-placeholder="`Buscar nombre, URL o ${info.placeLabel.toLowerCase()}`"
        :loading="items.list.status.value === 'pending'"
        :error="errorText"
        :error-code="(items.list.error.value as { code?: string } | undefined)?.code"
        :filtered="filtered"
        :no-results-title="`Ningún ${info.noun} con estos filtros`"
        @update:selection="selectedIds = $event"
        @clear-filters="clearFilters"
        @retry="items.list.refresh()"
      >
        <template #filters>
          <span v-if="importFilter.active.value" class="inline-flex h-6 items-center gap-1 rounded bg-adm-subtle pr-1 pl-2 text-xs">
            {{ importFilter.label.value }}
            <button type="button" :class="[admIconBtn, 'relative size-5! max-md:after:absolute max-md:after:-inset-3']" aria-label="Quitar el filtro de la importación" @click="importFilter.clear()"><X class="size-3" aria-hidden="true" /></button>
          </span>
          <AdminSegmented v-if="view === 'draft' || view === 'all'" v-model="readyFilter" :options="READY_OPTIONS" label="Para publicar" />
          <button type="button" :class="admBtnPressed" :aria-pressed="featuredOnly" @click="featuredOnly = !featuredOnly"><Star aria-hidden="true" />Destacados</button>
        </template>
        <template #empty>
          <AdminStateBlock
            kind="empty"
            :title="`Todavía no hay ${info.nouns}`"
            description="Crea la primera ficha: se guarda sola mientras escribes y no se publica hasta que tú lo decidas."
          >
            <button type="button" :class="admBtnPrimary" @click="items.create()"><Plus aria-hidden="true" />{{ info.newLabel }}</button>
          </AdminStateBlock>
        </template>

        <template #cell-name="{ row }">
          <span class="inline-flex max-w-full items-center gap-2 align-middle md:max-w-[30rem]">
            <span :class="['truncate max-md:line-clamp-2 max-md:whitespace-normal', !row.name && 'italic text-adm-muted']">{{ row.name || 'Sin nombre' }}</span>
            <Star v-if="row.is_featured" class="size-3.5 flex-none text-adm-acc" role="img" aria-label="Destacado" />
          </span>
        </template>
        <template #cell-status="{ row }"><AdminStatusChip :status="chip(row)" :changes="row.changes" :label="itemChipLabel(chip(row))" /></template>
        <template #cell-ready="{ row }">
          <template v-for="state in [stateOf(row)]" :key="state.kind">
            <span v-if="state.kind === 'ready'" class="inline-flex items-center gap-1.5 text-[13px] text-adm-ok"><CircleCheck class="size-3.5" aria-hidden="true" />Lista</span>
            <span v-else-if="state.kind === 'blocked'" class="inline-flex items-center gap-1.5 text-[13px] text-adm-danger" :title="blockerList(state.blockers).join('; ')"><OctagonAlert class="size-3.5 flex-none" aria-hidden="true" />{{ readyText(state.blockers) }}<span v-if="state.blockers.length > 1" class="tabular-nums"> +{{ state.blockers.length - 1 }}</span></span>
            <span v-else-if="state.kind === 'hidden'" class="inline-flex items-center gap-1.5 text-[13px] text-adm-meta"><EyeOff class="size-3.5 flex-none" aria-hidden="true" />Oculta: publícala desde su ficha</span>
            <NuxtLink v-else-if="state.kind === 'changes'" :to="adminPath(`${info.route}/${row.id}`)" class="inline-flex items-center gap-1.5 text-[13px] text-adm-st-rev hover:underline"><GitBranch class="size-3.5" aria-hidden="true" />Ver cambios</NuxtLink>
            <span v-else class="text-adm-muted">—</span>
          </template>
        </template>
        <template #cell-district="{ row }"><span v-if="row.district || row.city" class="text-adm-meta">{{ row.district || row.city }}</span>
          <span v-else-if="info.category === 'shoe'" class="italic text-adm-muted">Sin marca</span></template>
        <template #cell-cover="{ row }">
          <span v-if="row.has_cover" class="inline-grid size-5 place-items-center rounded-full bg-adm-st-pub-bg text-adm-st-pub" role="img" aria-label="Con foto"><Check class="size-3.5" aria-hidden="true" /></span>
          <X v-else class="size-4 text-adm-warn" role="img" aria-label="Sin foto" />
        </template>
        <template #cell-lang="{ row }">
          <span class="inline-flex items-center gap-1 text-xs font-medium">
            <span class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg">ES</span>
            <span v-if="row.has_en" class="rounded bg-adm-subtle px-1 py-0.5 text-adm-fg">EN</span>
            <span v-else class="rounded px-1 py-0.5 text-adm-muted outline-1 -outline-offset-1 outline-dashed outline-adm-line-strong">EN<span class="sr-only"> pendiente</span></span>
          </span>
        </template>
        <template #cell-verified="{ row }">
          <span v-if="row.verified_at" :class="['tabular-nums', needsVerification(row) ? 'text-adm-warn' : 'text-adm-meta']">{{ shortDate(row.verified_at) }}<span v-if="needsVerification(row)" class="sr-only"> (hace más de 6 meses)</span></span>
          <span v-else class="text-adm-warn">Sin verificar</span>
        </template>
        <template #cell-reviews="{ row }"><span class="tabular-nums text-adm-meta">{{ row.reviews }}</span></template>
        <template #cell-updated="{ row }"><AdminTime :iso="row.updated_at" class="text-adm-meta" /></template>
        <template #cell-actions="{ row }">
          <AdminItemsRowMenu :row="row" :info="info" @discard="dialog = { kind: 'discard', row }" @hide="dialog = { kind: 'hide', row }" @remove="dialog = { kind: 'remove', targets: [row] }" />
        </template>
        <template #bulk>
          <button type="button" :class="admBtnGhost" :disabled="!selected.some((row) => !row.has_cover)" @click="openCovers(selected)"><ImagePlus aria-hidden="true" />Asignar portadas…</button>
          <button type="button" :class="admBtnPrimary" :disabled="!canPublish" :title="canPublish ? undefined : publishHint" @click="openPublish(selected)"><Send aria-hidden="true" />Publicar…</button>
          <button type="button" :class="admBtnDangerGhost" @click="dialog = { kind: 'remove', targets: selected }"><Trash2 aria-hidden="true" />Eliminar…</button>
        </template>
      </AdminDataTable>
    </div>

    <AdminItemsPublishBatch v-model:open="publishOpen" :info="info" :plan="plan" :selected="publishTargets.length" :busy="batch.busy.value" @confirm="confirmPublish" />
    <AdminItemsAssignCovers v-model:open="coversOpen" :info="info" :items="coverTargets" @done="items.list.refresh()" />
    <AdminConfirmDelete
      :open="dialog?.kind === 'remove'"
      :level="blockers.length ? 'in-use' : 'simple'"
      :title="blockers.length ? 'Hay fichas que no se pueden eliminar' : removing.length === 1 ? `¿Eliminar «${removing[0]?.name || 'Sin nombre'}»?` : `¿Eliminar ${removing.length} ${info.nouns}?`"
      :description="removeText"
      :usages="blockers.map((row) => ({ label: row.name, where: row.published ? 'Publicada' : `${row.reviews} ${row.reviews === 1 ? 'opinión' : 'opiniones'}`, href: adminPath(`${info.route}/${row.id}`) }))"
      :confirm-label="removing.length === 1 ? 'Eliminar ficha' : `Eliminar ${removing.length} ${info.nouns}`"
      :busy="items.busy.value"
      @update:open="open = $event"
      @confirm="confirmRemove"
    />
    <AdminConfirmDelete
      :open="dialog?.kind === 'discard'"
      level="simple"
      :title="dialog?.kind === 'discard' ? `¿Descartar ${dialog.row.changes === 1 ? 'el cambio' : `los ${dialog.row.changes} cambios`} sin publicar?` : ''"
      :description="dialog?.kind === 'discard' ? `«${dialog.row.name}» vuelve a la versión publicada. Lo publicado no cambia.` : ''"
      confirm-label="Descartar cambios"
      :busy="items.busy.value"
      @update:open="open = $event"
      @confirm="confirmDiscard"
    />
    <AdminConfirmDelete
      :open="dialog?.kind === 'hide'"
      level="simple"
      :title="dialog?.kind === 'hide' ? `¿Ocultar «${dialog.row.name}»?` : ''"
      :description="dialog?.kind === 'hide' ? `Deja de verse en el sitio.${dialog.row.reviews === 0 ? ' Tu reseña se conserva.' : dialog.row.reviews === 1 ? ' Su opinión y tu reseña se conservan.' : ` Sus ${dialog.row.reviews} opiniones y tu reseña se conservan.`}${dialog.row.changes ? ' Los cambios sin publicar se aplican a la ficha antes de ocultarla.' : ''} Puedes volver a publicarla cuando quieras.` : ''"
      confirm-label="Ocultar ficha"
      :busy="items.busy.value"
      @update:open="open = $event"
      @confirm="confirmHide"
    />
  </div>
</template>
