<script setup lang="ts">
import { Bot } from 'lucide-vue-next'
import type { AdminSource, AdminToken } from '~/utils/admin-ingest'
import type { SourceForm } from '~/utils/admin-ingest-form'

/**
 * Ingesta (F8, docs/design/admin/ingesta.html): health of the routine on top, then Recogidas, Fuentes and Tokens (`#fuentes`,
 * `#tokens`, `?recogida=<id>` opens that one). Everything the routine wrote is interpolated (F1). The token is shown once,
 * in the creation dialog, and kept nowhere else (F-token of 8.9).
 */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Ingesta')

const route = useRoute()
const ingest = useAdminIngest()
const src = useAdminIngestSources()
const tok = useAdminIngestTokens()
const badge = useAdminNewsBadge()

type Tab = 'recogidas' | 'fuentes' | 'tokens'
const TABS: { value: Tab; label: string }[] = [{ value: 'recogidas', label: 'Recogidas' }, { value: 'fuentes', label: 'Fuentes' }, { value: 'tokens', label: 'Tokens' }]
const HASHES: Record<string, Tab> = { '#fuentes': 'fuentes', '#tokens': 'tokens' }
const tab = ref<Tab>(HASHES[route.hash] ?? 'recogidas')
watch(() => route.hash, (hash) => HASHES[hash] && (tab.value = HASHES[hash]))
const count = (t: Tab) => (t === 'fuentes' ? src.sources.value.length : t === 'tokens' ? tok.active.value.length : undefined)
function move(event: KeyboardEvent, index: number) {
  const step = event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0
  if (!step) return
  event.preventDefault()
  const next = TABS[(index + step + TABS.length) % TABS.length]
  if (!next) return
  tab.value = next.value
  void nextTick(() => document.getElementById(`ing-tab-${next.value}`)?.focus())
}

// Dialogs ---------------------------------------------------------------------------------------------------
const editing = ref<{ source?: AdminSource }>()
const removing = ref<AdminSource>()
const creating = ref(false)
const revoking = ref<AdminToken>()

async function saveSource(form: SourceForm) {
  if (await src.save(editing.value?.source, form)) editing.value = undefined
}
async function confirmRemoveSource() {
  if (removing.value && (await src.remove(removing.value))) {
    removing.value = undefined
    editing.value = undefined
  }
}
async function confirmRevoke() {
  if (revoking.value && (await tok.revoke(revoking.value.id))) {
    revoking.value = undefined
    void ingest.reload()
    void badge.refresh()
  }
}
function newToken() {
  tab.value = 'tokens'
  creating.value = true
}
// A created token changes the health (no active token, expiry): re-read it once the dialog is gone.
watch(creating, (is) => {
  if (is) return
  void ingest.reload()
  void badge.refresh()
})
const failed = computed(() => ingest.failed.value || src.failed.value || tok.failed.value)
const runId = computed(() => (typeof route.query.recogida === 'string' ? route.query.recogida : undefined))
watch(runId, (id) => id && (tab.value = 'recogidas'))
</script>

<template>
  <div>
    <AdminPageBar title="Ingesta">
      <template #meta><span :class="[admChip, 'ml-1 hidden bg-adm-subtle text-adm-meta md:inline-flex']"><Bot aria-hidden="true" />Rutina en la nube · lunes y jueves, 06:00</span></template>
    </AdminPageBar>

    <AdminIngestHealth
      :health="ingest.health.value"
      :runs="ingest.runs.value"
      :window-until="ingest.windowUntil.value"
      :window-open="ingest.windowOpen.value"
      :busy="ingest.busy.value"
      @new-token="newToken"
      @open-window="ingest.openWindow"
      @close-window="ingest.closeWindow"
    />

    <div class="mt-4 overflow-x-auto border-b border-adm-line px-4 md:px-6">
      <div role="tablist" aria-label="Ingesta" class="flex min-w-max gap-5">
        <button
          v-for="(t, i) in TABS"
          :id="`ing-tab-${t.value}`"
          :key="t.value"
          type="button"
          role="tab"
          :aria-selected="tab === t.value"
          :aria-controls="`ing-panel-${t.value}`"
          :tabindex="tab === t.value ? 0 : -1"
          :class="['relative inline-flex h-10 items-center gap-1.5 rounded text-[13px] max-md:h-11', tab === t.value ? 'font-medium text-adm-fg after:absolute after:inset-x-0 after:bottom-0 after:h-0.5 after:bg-adm-acc' : 'text-adm-meta hover:text-adm-fg']"
          @click="tab = t.value"
          @keydown="move($event, i)"
        >{{ t.label }}<span v-if="count(t.value) !== undefined" class="text-adm-muted tabular-nums">{{ count(t.value) }}</span></button>
      </div>
    </div>

    <AdminStateBlock v-if="failed" kind="error" title="No se han podido cargar los datos de la ingesta" description="Comprueba la conexión y vuelve a intentarlo." @retry="() => { ingest.reload(); src.reload(); tok.reload() }" />
    <template v-else>
      <div v-show="tab === 'recogidas'" id="ing-panel-recogidas" role="tabpanel" aria-labelledby="ing-tab-recogidas">
        <div v-if="ingest.pending.value" class="space-y-3 p-6" role="status" aria-label="Cargando las recogidas"><span v-for="n in 4" :key="n" class="block h-10 animate-pulse rounded bg-adm-subtle" /></div>
        <AdminIngestRuns v-else :runs="ingest.runs.value" :kpis="ingest.kpis.value" :open="runId" />
      </div>
      <div v-show="tab === 'fuentes'" id="ing-panel-fuentes" role="tabpanel" aria-labelledby="ing-tab-fuentes">
        <div v-if="src.pending.value" class="space-y-3 p-6" role="status" aria-label="Cargando las fuentes"><span v-for="n in 4" :key="n" class="block h-10 animate-pulse rounded bg-adm-subtle" /></div>
        <AdminIngestSources v-else :sources="src.sources.value" :busy="src.busy.value" @create="editing = {}" @edit="(s) => (editing = { source: s })" @toggle="src.toggle" @remove="removing = $event" />
      </div>
      <div v-show="tab === 'tokens'" id="ing-panel-tokens" role="tabpanel" aria-labelledby="ing-tab-tokens">
        <AdminIngestTokens :tokens="tok.tokens.value" :can-create="tok.canCreate.value" :busy="tok.busy.value" @create="creating = true" @revoke="revoking = $event" />
      </div>
    </template>

    <AdminIngestSourceDrawer v-if="editing" :key="editing.source?.id ?? 'new'" :open="true" :source="editing.source" :busy="src.busy.value" :error="src.error.value" @update:open="(v: boolean) => !v && (editing = undefined)" @save="saveSource" @remove="removing = editing.source" />
    <AdminConfirmDelete v-if="removing" :open="true" stacked level="simple" :title="`¿Eliminar la fuente «${removing.name}»?`" description="Se borra para siempre. La rutina dejará de recogerla. Solo se puede porque no tiene noticias ni eventos." :busy="src.busy.value" @update:open="(v: boolean) => !v && (removing = undefined)" @confirm="confirmRemoveSource" />
    <AdminIngestTokenCreate v-if="creating" v-model:open="creating" :busy="tok.busy.value" :error="tok.error.value" :create="tok.create" />
    <AdminIngestTokenRevoke v-if="revoking" :open="true" :token="revoking" :only-active="tok.active.value.length === 1" :busy="tok.busy.value" @update:open="(v: boolean) => !v && (revoking = undefined)" @confirm="confirmRevoke" />
  </div>
</template>
