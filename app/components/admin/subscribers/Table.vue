<script setup lang="ts">
import { UserRound, UserX } from 'lucide-vue-next'
import { lastChangeOf, sourceLabel, viaLabel, reasonShort, waitingOf, type Subscriber, type SubscriberView } from '~/utils/admin-subscribers'
import { fullDay, shortDay } from '~/utils/admin-madrid'

/**
 * Activos, Sin confirmar, Bajas and Todos: `AdminDataTable` in server mode (cards under 768). Columns change with the
 * view (docs/design/admin/README.md §11.2). The server filters, sorts and pages; here only Alta can be re-sorted.
 * The «Afines» column (D66) is on every view. Selection serves the bulk unsubscribe (never the erasure) and survives paging.
 */
const props = defineProps<{ rows: readonly Subscriber[]; view: SubscriberView; total: number; loading: boolean; error?: string; errorCode?: string }>()
const emit = defineEmits<{ open: [row: Subscriber]; copy: [row: Subscriber]; unsubscribe: [row: Subscriber]; withdraw: [row: Subscriber]; erase: [row: Subscriber]; bulk: [ids: string[], clear: () => void]; retry: [] }>()
const query = defineModel<AdminTableQuery>('query', { required: true })

const cell = (key: string, label: string, extra: Partial<AdminColumn<Subscriber>> = {}): AdminColumn<Subscriber> => ({ key, label, searchable: false, ...extra })
const columns = computed<AdminColumn<Subscriber>[]>(() => {
  const v = props.view
  return [
    cell('email', 'Email', { pin: 'left', minWidth: 'min-w-64' }),
    ...(v !== 'active' ? [cell('status', 'Estado', { card: true })] : []),
    cell('locale', 'Idioma', { card: true }),
    cell('source', 'Origen', { card: true }),
    cell('consent', 'Alta', { sortable: true, card: v !== 'pending' && v !== 'unsubscribed', accessor: (r) => r.consentAt }),
    ...(v === 'active' ? [cell('confirmed', 'Confirmado'), cell('version', 'Texto'), cell('account', 'Cuenta')] : []),
    ...(v === 'pending' ? [cell('waiting', 'Esperando', { card: true })] : []),
    ...(v === 'unsubscribed' ? [cell('unsubscribed', 'Baja', { card: true }), cell('via', 'Vía')] : []),
    ...(v === 'all' ? [cell('last', 'Último cambio')] : []),
    cell('related', 'Afines', { card: true, title: 'Avisos de Chalk app y productos afines' }),
    cell('actions', 'Acciones', { hideLabel: true, pin: 'right' }),
  ]
})
const caption = computed(() => ({ active: 'Suscriptores activos, el alta más reciente primero', pending: 'Suscriptores sin confirmar, el alta más reciente primero', unsubscribed: 'Suscriptores de baja, el alta más reciente primero', all: 'Todos los suscriptores, el alta más reciente primero' })[props.view])
</script>

<template>
  <AdminDataTable
    :key="view"
    v-model:query="query"
    mode="server"
    :rows="rows"
    :columns="columns"
    :row-count="total"
    :row-id="(r: Subscriber) => r.id"
    :row-label="(r: Subscriber) => r.email"
    primary-key="email"
    :selectable="view !== 'unsubscribed'"
    clickable
    :caption="caption"
    :loading="loading"
    :error="error"
    :error-code="errorCode"
    @row-click="emit('open', $event)"
    @retry="emit('retry')"
  >
    <template #empty><slot name="empty" /></template>
    <template #cell-email="{ row }"><span class="block max-w-full truncate font-mono text-[13px] md:max-w-[22rem]">{{ row.email }}</span></template>
    <template #cell-status="{ row }"><AdminSubscribersChip :status="row.status" /></template>
    <template #cell-locale="{ row }"><span class="font-mono text-xs uppercase text-adm-meta">{{ row.locale }}</span></template>
    <template #cell-source="{ row }"><span class="text-adm-meta">{{ sourceLabel(row.source) }}</span></template>
    <template #cell-consent="{ row }"><span class="tabular-nums text-adm-meta">{{ shortDay(row.consentAt) }}</span></template>
    <template #cell-confirmed="{ row }"><span class="tabular-nums text-adm-meta">{{ row.confirmedAt ? shortDay(row.confirmedAt) : '—' }}</span></template>
    <template #cell-version="{ row }">
      <span class="font-mono text-xs text-adm-meta">v{{ row.version }}</span><span v-if="row.version < 3" class="sr-only"> (texto anterior)</span>
    </template>
    <template #cell-account="{ row }">
      <span v-if="row.hasAccount" class="inline-flex items-center gap-1 text-xs text-adm-meta"><UserRound class="size-3.5" aria-hidden="true" />Sí</span>
      <span v-else class="text-adm-muted">—</span>
    </template>
    <template #cell-waiting="{ row }">
      <span class="text-adm-meta">{{ waitingOf(row).main }}<span v-if="waitingOf(row).note" class="block text-xs text-adm-muted">{{ waitingOf(row).note }}</span></span>
    </template>
    <template #cell-unsubscribed="{ row }"><span class="tabular-nums text-adm-meta">{{ row.unsubscribedAt ? fullDay(row.unsubscribedAt) : '—' }}</span></template>
    <template #cell-via="{ row }">
      <span class="text-adm-meta">{{ viaLabel(row.unsubscribeSource) }}<span v-if="row.unsubscribeReason" class="block text-xs text-adm-muted">«{{ reasonShort(row.unsubscribeReason) }}»</span></span>
    </template>
    <template #cell-last="{ row }"><span class="tabular-nums text-adm-meta">{{ lastChangeOf(row) }}</span></template>
    <template #cell-related="{ row }"><AdminSubscribersRelatedChip :status="row.related.status" /></template>
    <template #cell-actions="{ row }">
      <AdminSubscribersRowMenu :subscriber="row" @open="emit('open', row)" @copy="emit('copy', row)" @unsubscribe="emit('unsubscribe', row)" @withdraw="emit('withdraw', row)" @erase="emit('erase', row)" />
    </template>
    <template #bulk="{ ids, clear }">
      <button type="button" :class="admBtnQuiet" @click="emit('bulk', ids, clear)"><UserX aria-hidden="true" />Dar de baja…</button>
    </template>
  </AdminDataTable>
</template>
