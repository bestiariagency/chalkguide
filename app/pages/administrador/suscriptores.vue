<script setup lang="ts">
import { Info, Plug } from 'lucide-vue-next'
import { canUnsubscribe, hasFilterChips, hasSubscriberFilters, SENDING_CONNECTED, viewNote, viewSlug, type Subscriber, type SubscriberView } from '~/utils/admin-subscribers'

/**
 * Suscriptores (F6.14, D35; docs/design/admin/README.md §11): read-only list of the newsletter audience with the proof
 * of consent of each one. No creating, reactivating or editing: the panel only unsubscribes (reason required, no undo,
 * also in bulk) and erases (RGPD, one by one, typing the email). View and filters live in the URL
 * (`?vista=activos|sin-confirmar|bajas|todos&origen=&idioma=&fecha=&desde=&hasta=&version=&estado=&afines=&q=`).
 * Exporting (F6.15) is the modal of the «Exportar» button, with the filters of this view.
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Suscriptores')

const subs = useAdminSubscribers()
const actions = useAdminSubscriberActions(subs.reload)
const { info } = useAdminToast()

const viewModel = computed<SubscriberView>({
  get: () => subs.view.value,
  set: (v) => {
    selectedId.value = undefined
    // "Estado" only exists in Todos: it must not stay hidden in the URL of another view.
    void subs.setQuery({ vista: viewSlug(v), estado: undefined })
  },
})
const selectedId = ref<string>()
const unsubscribing = ref<{ subscribers: Subscriber[]; skipped: number; clear?: () => void }>()
const erasing = ref<Subscriber>()
const withdrawing = ref<Subscriber>()
const detail = useTemplateRef<{ reload: () => Promise<void> }>('detail')

const result = computed(() => subs.result.value)
const failed = computed(() => subs.list.status.value === 'error')
const errorCode = computed(() => (subs.list.error.value as { code?: string } | undefined)?.code)
const loading = computed(() => subs.list.status.value === 'pending')
const filtering = computed(() => hasSubscriberFilters(subs.filters.value))
const note = computed(() => viewNote(subs.view.value))

function clearFilters() {
  subs.search.value = ''
  void subs.setQuery({ q: undefined, origen: undefined, idioma: undefined, fecha: undefined, desde: undefined, hasta: undefined, version: undefined, estado: undefined, afines: undefined })
}
function askUnsubscribe(subscribers: Subscriber[], clear?: () => void, skipped = 0) {
  actions.mismatch.value = false
  unsubscribing.value = { subscribers, skipped, clear }
}
function askBulk(ids: string[], clear: () => void) {
  const eligible = ids.map((id) => subs.known.get(id)).filter((s): s is Subscriber => !!s && canUnsubscribe(s))
  if (!eligible.length) return void info(ids.length === 1 ? 'El seleccionado no se puede dar de baja: ya está de baja o ha caducado.' : 'Ninguno de los seleccionados se puede dar de baja: ya están de baja o han caducado.')
  askUnsubscribe(eligible, clear, ids.length - eligible.length)
}
function askErase(subscriber: Subscriber) {
  actions.mismatch.value = false
  erasing.value = subscriber
}
async function confirmUnsubscribe(reason: string) {
  const ask = unsubscribing.value
  if (!ask) return
  const ids = ask.subscribers.map((s) => s.id)
  if (await actions.unsubscribe(ids, reason, ask.subscribers[0]?.email ?? '')) {
    ask.clear?.()
    unsubscribing.value = undefined
    if (selectedId.value && ids.includes(selectedId.value)) selectedId.value = undefined
  }
}
async function confirmWithdraw(reason: string) {
  const target = withdrawing.value
  if (!target) return
  const done = await actions.withdraw(target.id, reason, target.email)
  // The ficha stays open and shows the new state; a failed call keeps the dialog for "Reintentar".
  if (done) {
    withdrawing.value = undefined
    await detail.value?.reload()
  }
}
async function confirmErase(typed: string, reason: string) {
  const target = erasing.value
  if (target && (await actions.erase(target.id, typed, reason))) {
    subs.known.delete(target.id)
    erasing.value = undefined
    selectedId.value = undefined
  }
}
const copyEmail = (s: Subscriber) => actions.copy(s.email, 'Email copiado')
const copyProof = (text: string) => actions.copy(text, 'Prueba copiada como texto')
</script>

<template>
  <div>
    <AdminPageBar title="Suscriptores">
      <template #meta>
        <span :class="[admChip, 'ml-1 bg-adm-subtle text-adm-meta max-md:hidden']" title="El proveedor de email (Brevo) se conecta en F4.6"><Plug aria-hidden="true" />Envíos sin conectar</span>
      </template>
      <AdminExportsButton target="subscribers" :initial="subscribersExportInitial(subs.view.value, subs.filters.value)" />
    </AdminPageBar>

    <div v-if="!SENDING_CONNECTED" class="px-4 pt-4 md:px-6">
      <p :class="[admCard, 'flex items-start gap-2 bg-adm-subtle px-3 py-2 text-[13px] leading-5']" role="note">
        <Plug class="mt-0.5 size-4 flex-none" aria-hidden="true" />
        <span><b>Aún no se envían emails de confirmación.</b> Llegan cuando se conecte el proveedor (F4.6). Hasta entonces, todas las altas se quedan en «Sin confirmar» y ninguna caduca. Ya puedes ver la prueba de consentimiento y dar de baja.</span>
      </p>
    </div>

    <div class="px-4 pt-4 md:px-6"><AdminSubscribersSummary :summary="subs.summary.value" /></div>

    <div class="mt-4">
      <AdminSubscribersToolbar v-model:view="viewModel" v-model:search="subs.search.value" :result="result" :filters="subs.filters.value" @filter="subs.setQuery" @clear="clearFilters" />
    </div>

    <p class="flex gap-1.5 border-b border-adm-line bg-adm-side px-4 py-2 text-xs text-adm-meta md:px-6"><Info class="mt-0.5 size-3.5 flex-none" aria-hidden="true" />{{ note }}</p>

    <div class="max-w-[1440px] px-4 py-4 md:px-6">
      <AdminSubscribersTable
        v-model:query="subs.tableQuery.value"
        :rows="subs.rows.value"
        :view="viewModel"
        :total="result?.total ?? 0"
        :loading="loading"
        :error="failed ? 'Comprueba la conexión. Si sigue, puede ser Supabase: mira su estado.' : undefined"
        :error-code="errorCode"
        @open="selectedId = $event.id"
        @copy="copyEmail"
        @unsubscribe="askUnsubscribe([$event])"
        @withdraw="withdrawing = $event"
        @erase="askErase"
        @bulk="askBulk"
        @retry="subs.list.refresh()"
      >
        <template #empty>
          <AdminSubscribersEmpty :view="viewModel" :filtered="filtering" :search="subs.search.value" :has-chips="hasFilterChips(subs.filters.value)" :total="result?.tabCounts.all ?? 0" @goto="viewModel = $event" @clear="clearFilters" />
        </template>
      </AdminSubscribersTable>
    </div>

    <AdminSubscribersDetail :id="selectedId" ref="detail" @close="selectedId = undefined" @unsubscribe="askUnsubscribe([$event])" @withdraw="withdrawing = $event" @erase="askErase" @copy="copyProof" />
    <AdminSubscribersWithdrawRelated
      v-if="withdrawing"
      :open="true"
      :subscriber="withdrawing"
      :busy="actions.busy.value"
      @update:open="(v: boolean) => !v && (withdrawing = undefined)"
      @confirm="confirmWithdraw"
    />

    <AdminSubscribersUnsubscribe
      v-if="unsubscribing"
      :open="true"
      :subscribers="unsubscribing.subscribers"
      :skipped="unsubscribing.skipped"
      :busy="actions.busy.value"
      @update:open="(v: boolean) => !v && (unsubscribing = undefined)"
      @confirm="confirmUnsubscribe"
    />
    <AdminSubscribersErase
      v-if="erasing"
      :open="true"
      :subscriber="erasing"
      :busy="actions.busy.value"
      :mismatch="actions.mismatch.value"
      @update:open="(v: boolean) => !v && (erasing = undefined)"
      @confirm="confirmErase"
    />
  </div>
</template>
