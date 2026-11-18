<script setup lang="ts">
import { Check, Globe, Plus, X } from 'lucide-vue-next'
import type { EventSaveAction } from '~/composables/useAdminEventSave'
import { hasEventFilters, type AdminEvent, type EventView } from '~/utils/admin-events'
import { duplicateForm, emptyEventForm, type EventForm } from '~/utils/admin-events-form'

/**
 * Agenda (F6.12, docs/design/admin/agenda.html): Por aprobar is the inbox of Opiniones, Próximos / Pasados /
 * Descartados / Todos are `AdminDataTable`, Mes is the calendar of the Inicio and the editor is a drawer.
 * View and filters live in the URL (`?vista=&tipo=&q=&lugar=&desde=&hasta=&origen=&recogida=&cal=mes&mes=`).
 * Nothing the agent proposes is published without `approve_event` (rule 6).
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Agenda')

const route = useRoute()
const ev = useAdminEvents()
const actions = useAdminEventActions(ev.reload)
const saver = useAdminEventSave(ev.reload)
const { rows } = ev

const selectedId = ref<string>()
const checked = ref<string[]>([])
const viewModel = computed<EventView>({
  get: () => ev.view.value ?? 'proximos',
  set: (v) => {
    selectedId.value = undefined
    checked.value = []
    void ev.setQuery({ vista: v, cal: v === 'proximos' ? route.query.cal?.toString() : undefined })
  },
})
const calendarModel = computed({ get: () => ev.calendar.value, set: (v) => void ev.setQuery({ cal: v ? 'mes' : undefined, mes: undefined }) })
const filtering = computed(() => hasEventFilters(ev.filters.value))
// Until the counters pick the default view nothing is known: show the loading state, never a false "empty".
const waiting = computed(() => !ev.view.value || ev.list.status.value === 'pending')
const loading = computed(() => waiting.value && !rows.value.length)
const showSkeleton = useDelayedFlag(loading, 300)
const failed = computed(() => ev.list.status.value === 'error')
const errorCode = computed(() => (ev.list.error.value as { code?: string } | undefined)?.code)
const showDrafts = ref<boolean | 'indeterminate'>(true)
const total = computed(() => ev.summary.value?.total ?? 0)
const note = computed(() =>
  viewModel.value === 'proximos'
    ? 'Todos estos salen en el sitio: los próximos 60 días en /agenda y cada mes en /agenda/aaaa-mm.'
    : 'No salen en el sitio. Se guardan para que el agente no los vuelva a proponer; «Recuperar» los devuelve a Por aprobar.',
)

// Dialogs and editor ------------------------------------------------------------------------------
const editing = ref<{ event?: AdminEvent; initial?: EventForm }>()
const retiring = ref<AdminEvent>()
const removing = ref<AdminEvent>()

function create(date = '') {
  saver.error.value = undefined
  editing.value = { initial: emptyEventForm(date) }
}
function edit(event: AdminEvent) {
  saver.error.value = undefined
  editing.value = { event }
}
function duplicate(event: AdminEvent) {
  saver.error.value = undefined
  editing.value = { initial: duplicateForm(event) }
}
// "Nuevo → Evento" of the shell arrives as `?nuevo=1`.
watch(
  () => route.query.nuevo,
  (value) => {
    if (!value) return
    create()
    void ev.setQuery({ nuevo: undefined })
  },
  { immediate: true },
)

// Deep link `?evento=<id>` (⌘K): drafts open the inbox on them, the rest open the drawer.
const wantedEvent = useAdminEventLookup(() => (typeof route.query.evento === 'string' ? route.query.evento : undefined))
watch(wantedEvent, (event) => {
  if (!event) return
  void ev.setQuery({ evento: undefined })
  fromCalendar(event)
})

async function save(form: EventForm, action: EventSaveAction) {
  if (await saver.save(editing.value?.event, form, action)) editing.value = undefined
}
/** Runs a status change from the drawer and closes it when it worked. */
async function fromEditor(run: (event: AdminEvent) => Promise<boolean>) {
  const event = editing.value?.event
  if (event && (await run(event))) editing.value = undefined
}

// Decisions of the inbox: the selection and the focus pass to the next event ------------------------
function focusRow(id?: string) {
  if (id) void nextTick(() => document.querySelector<HTMLElement>(`[data-event="${id}"]`)?.focus())
}
async function approve(event: AdminEvent, next?: string) {
  if (await actions.approve(event)) {
    selectedId.value = next
    focusRow(next)
  }
}
async function reject(event: AdminEvent, reason: string | null, next?: string) {
  if (await actions.reject(event, reason)) {
    selectedId.value = next
    focusRow(next)
  }
}
async function batch(kind: 'approve' | 'reject', reason: string | null = null) {
  if (await actions.batch(checked.value, kind, reason)) checked.value = []
}
async function confirmRemove() {
  if (removing.value && (await actions.remove(removing.value))) {
    removing.value = undefined
    editing.value = undefined
  }
}
async function discardInstead() {
  if (removing.value && (await actions.reject(removing.value, null))) {
    removing.value = undefined
    editing.value = undefined
  }
}
async function confirmRetire() {
  if (retiring.value && (await actions.retire(retiring.value))) retiring.value = undefined
}

/** Calendar: approved ones open the editor, drafts open the inbox on them. */
function fromCalendar(event: AdminEvent) {
  if (event.status !== 'draft') return edit(event)
  selectedId.value = event.id
  void ev.setQuery({ vista: 'revisar', cal: undefined, mes: undefined })
}
function openExisting(id: string) {
  void ev.setQuery({ vista: 'todos', cal: undefined, q: undefined })
  void nextTick(() => (selectedId.value = id))
}
function clearFilters() {
  ev.search.value = ''
  void ev.setQuery({ q: undefined, tipo: undefined, lugar: undefined, desde: undefined, hasta: undefined, origen: undefined, recogida: undefined })
}
</script>

<template>
  <div :class="viewModel === 'revisar' && 'lg:flex lg:h-dvh lg:flex-col'">
    <AdminPageBar title="Agenda">
      <template #meta>
        <span :class="[admChip, 'ml-1 hidden bg-adm-subtle text-adm-meta md:inline-flex']" title="Lo que ve el sitio en /agenda"><Globe aria-hidden="true" />El sitio muestra los próximos 60 días</span>
      </template>
      <AdminExportsButton target="events" :initial="eventsExportInitial(ev.view.value ?? 'proximos', ev.filters.value, dayKey(new Date()))" />
      <button type="button" :class="admBtnPrimary" @click="create()"><Plus aria-hidden="true" /><span class="max-sm:hidden">Nuevo evento</span><span class="sm:hidden">Nuevo</span></button>
    </AdminPageBar>

    <AdminEventsToolbar
      v-model:view="viewModel"
      v-model:search="ev.search.value"
      v-model:calendar="calendarModel"
      :counts="ev.counts.value"
      :type-counts="ev.summary.value?.byType ?? {}"
      :gyms="ev.gyms.value"
      :filters="ev.filters.value"
      :runs="ev.runOptions.value"
      @filter="ev.setQuery"
    />

    <p v-if="viewModel === 'proximos' || viewModel === 'descartados'" class="flex gap-2 border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta md:px-6">
      <Globe v-if="viewModel === 'proximos'" class="mt-0.5 size-3.5 flex-none" aria-hidden="true" />{{ note }}
    </p>

    <AdminStateBlock v-if="failed" kind="error" title="No se han podido cargar los eventos" description="Comprueba la conexión. Si sigue, puede ser Supabase: mira su estado." :code="errorCode" @retry="ev.list.refresh()" />
    <div v-else-if="loading && viewModel === 'revisar'" :aria-busy="true" :class="['lg:grid lg:grid-cols-[420px_1fr]', showSkeleton ? 'opacity-100' : 'opacity-0']">
      <span class="sr-only" role="status">Cargando eventos…</span>
      <div class="divide-y divide-adm-line lg:border-r lg:border-adm-line">
        <div v-for="n in 5" :key="n" class="flex gap-3 px-4 py-3">
          <span class="h-12 w-11 flex-none animate-pulse rounded bg-adm-subtle" />
          <span class="flex-1 space-y-2 pt-1"><span class="block h-3 animate-pulse rounded bg-adm-subtle" :style="{ width: `${55 + ((n * 17) % 35)}%` }" /><span class="block h-3 w-1/2 animate-pulse rounded bg-adm-subtle" /></span>
        </div>
      </div>
      <div class="hidden space-y-4 p-6 lg:block"><span class="block h-5 w-72 animate-pulse rounded bg-adm-subtle" /><span class="block h-24 max-w-[640px] animate-pulse rounded bg-adm-subtle" /></div>
    </div>

    <template v-else-if="viewModel === 'revisar'">
      <AdminEventsEmpty v-if="!rows.length" view="revisar" :filtered="filtering" :search="ev.search.value" :total="total" @goto="viewModel = $event" @create="create()" @clear="clearFilters" />
      <AdminEventsInbox
        v-else
        v-model:selected-id="selectedId"
        v-model:checked="checked"
        :events="rows"
        :busy="actions.busy.value"
        @approve="approve"
        @reject="reject"
        @edit="edit"
        @duplicate="duplicate"
        @remove="removing = $event"
        @open-event="openExisting"
      />
    </template>

    <AdminEventsCalendar
      v-else-if="ev.calendar.value"
      v-model:show-drafts="showDrafts"
      :month="ev.month.value"
      :events="rows"
      :loading="waiting"
      @prev="ev.setQuery({ mes: shiftMonth(ev.month.value, -1) })"
      @next="ev.setQuery({ mes: shiftMonth(ev.month.value, 1) })"
      @today="ev.setQuery({ mes: undefined })"
      @open="fromCalendar"
      @add="create"
    />

    <div v-else class="max-w-[1440px] px-4 py-4 md:px-6">
      <AdminEventsTable
        :events="rows"
        :view="viewModel"
        :loading="waiting"
        :busy="actions.busy.value"
        @open="edit"
        @duplicate="duplicate"
        @retire="retiring = $event"
        @cancel="actions.cancel"
        @uncancel="actions.uncancel"
        @remove="removing = $event"
        @recover="actions.recover"
        @retry="ev.list.refresh()"
      >
        <template #empty>
          <AdminEventsEmpty :view="viewModel" :filtered="filtering" :search="ev.search.value" :total="total" @goto="viewModel = $event" @create="create()" @clear="clearFilters" />
        </template>
      </AdminEventsTable>
    </div>

    <AdminBulkBar :count="viewModel === 'revisar' ? checked.length : 0" @clear="checked = []">
      <button type="button" :class="admBtnQuiet" :disabled="actions.busy.value" @click="batch('approve')"><Check aria-hidden="true" />Aprobar</button>
      <AdminEventsRejectMenu agent @select="(reason) => batch('reject', reason)">
        <button type="button" :class="admBtnQuiet" :disabled="actions.busy.value" aria-haspopup="menu"><X aria-hidden="true" />Descartar</button>
      </AdminEventsRejectMenu>
    </AdminBulkBar>

    <AdminEventsEditor
      v-if="editing"
      :key="editing.event?.id ?? 'new'"
      :open="true"
      :event="editing.event"
      :initial="editing.initial"
      :gyms="ev.gyms.value"
      :busy="saver.busy.value || actions.busy.value"
      :server-error="saver.error.value"
      @update:open="(v: boolean) => { if (!v) editing = undefined }"
      @save="save"
      @reject="(reason) => fromEditor((e) => actions.reject(e, reason))"
      @recover="fromEditor(actions.recover)"
      @cancel="fromEditor(actions.cancel)"
      @uncancel="fromEditor(actions.uncancel)"
      @remove="removing = editing.event"
    />
    <AdminEventsRetire v-if="retiring" :open="true" :event="retiring" :busy="actions.busy.value" @update:open="(v: boolean) => !v && (retiring = undefined)" @confirm="confirmRetire" />
    <AdminEventsDelete v-if="removing" :open="true" :event="removing" :busy="actions.busy.value" @update:open="(v: boolean) => !v && (removing = undefined)" @confirm="confirmRemove" @discard="discardInstead" />
  </div>
</template>
