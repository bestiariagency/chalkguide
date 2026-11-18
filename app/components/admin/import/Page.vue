<script setup lang="ts">
import { ChevronRight } from 'lucide-vue-next'
import type { ItemInfo } from '~/utils/item-spec'

/**
 * `/administrador/{tipo}/importar` (F6.15b, D50; README §13): file -> review -> import -> result. Own page, not a modal:
 * the review is a table of up to 500 rows. Not offered under 768 px.
 */
const props = defineProps<{ info: ItemInfo }>()
const flow = useAdminImport(props.info)
const { file, phase } = flow

const step = computed<1 | 2 | 3 | 4>(() => ({ upload: 1, reading: 1, review: 2, applying: 3, result: 4 } as const)[phase.value])
const confirm = reactive({ open: false, clean: false })
function ask(clean: boolean) {
  confirm.clean = clean
  confirm.open = true
}
async function go() {
  confirm.open = false
  await flow.startApply(confirm.clean)
}
// The trigger button unmounts when the step changes: move focus to the new step's title so it is announced.
const stepTitle = ref<HTMLElement>()
watch(phase, async () => {
  await nextTick()
  const target = phase.value === 'result' ? document.getElementById('import-result') : stepTitle.value?.querySelector<HTMLElement>('[data-step-title]')
  target?.focus({ preventScroll: true })
})
const fileRows = computed(() => file.parsed.value?.rows.length ?? 0)
</script>

<template>
  <div>
    <header class="flex h-12 items-center gap-2 border-b border-adm-line px-4 text-sm md:px-6">
      <nav aria-label="Migas" class="flex min-w-0 items-center gap-1.5">
        <NuxtLink :to="adminPath(info.route)" class="text-adm-meta hover:text-adm-fg">{{ info.title }}</NuxtLink>
        <ChevronRight class="size-3.5 flex-none text-adm-muted" aria-hidden="true" />
        <h1 class="font-medium">Importar<span class="sr-only"> {{ info.nouns }}</span></h1>
      </nav>
    </header>

    <div class="md:hidden"><AdminImportMobile :info="info" :last="flow.lastImport.data.value" /></div>

    <div ref="stepTitle" class="max-w-[1440px] px-4 py-5 max-md:hidden md:px-6">
      <AdminImportSteps :current="step" class="mb-5" />

      <div v-if="phase === 'upload'" class="grid items-start gap-6 lg:grid-cols-[1fr_360px]">
        <div class="grid gap-4">
          <div>
            <h2 class="text-lg font-semibold focus:outline-none" tabindex="-1" data-step-title>Importar {{ info.nouns }}</h2>
            <p class="mt-1 text-[13px] text-adm-meta">Sube la plantilla rellena. Antes de escribir nada, la revisas fila por fila.</p>
          </div>
          <p v-if="flow.failure.value" class="rounded-lg border border-adm-danger/30 bg-adm-danger-soft p-3 text-[13px]" role="alert">{{ flow.failure.value }}</p>
          <AdminImportFileProblem v-if="file.error.value" :error="file.error.value" :file-name="file.fileName.value" :info="info" />
          <AdminImportSheets v-if="file.sheets.value" :sheets="file.sheets.value" :file-name="file.fileName.value" :type="info.title" @choose="flow.chooseSheet" @other="file.reset()" />
          <AdminImportColumns v-else-if="file.parsed.value && !file.ready.value" :columns="file.parsed.value.unknown" :ignored="file.parsed.value.ignored" @accept="flow.acceptUnknown()" @other="file.reset()" />
          <AdminImportDropzone v-else @file="flow.open" />
        </div>
        <AdminImportHelp :info="info" :last="flow.lastImport.data.value" :loaded="flow.lastImport.status.value !== 'pending' && flow.lastImport.status.value !== 'idle'" />
      </div>

      <AdminImportProgress v-else-if="phase === 'reading'" kind="reading" :file-name="file.fileName.value" :type="info.nouns" :chunks="flow.progress.chunks" :chunk="flow.progress.chunk" @cancel="flow.reset()" />

      <template v-else-if="phase === 'review' && file.parsed.value && file.meta.value">
        <h2 class="sr-only" tabindex="-1" data-step-title>Revisar {{ info.nouns }}</h2>
        <p v-if="flow.changedRows.value.length || flow.failure.value" class="mb-4 rounded-lg border border-adm-danger/30 bg-adm-danger-soft p-3 text-[13px]" role="alert">
          <template v-if="flow.failure.value">{{ flow.failure.value }}</template>
          <template v-else>No se ha importado nada. Al comprobarlo otra vez, {{ flow.changedRows.value.length }} {{ flow.changedRows.value.length === 1 ? 'fila ha cambiado' : 'filas han cambiado' }} desde la revisión (están marcadas). Revísalas y vuelve a importar.</template>
        </p>
        <AdminImportReview
          :rows="flow.reviewRows.value"
          :counts="flow.counts.value"
          :parsed="file.parsed.value"
          :meta="file.meta.value"
          :file-name="file.fileName.value"
          :changed="flow.changedRows.value"
          @again="flow.reset()"
          @check="flow.check()"
          @separator="flow.setSeparator"
          @download="flow.downloadErrors()"
        />
        <AdminImportActionBar :counts="flow.counts.value" :nouns="info.nouns" @import="ask(false)" @import-clean="ask(true)" @again="flow.reset()" />
        <AdminImportConfirm v-model:open="confirm.open" :counts="flow.counts.value" :nouns="info.nouns" :without-errors="confirm.clean" @confirm="go" />
      </template>

      <AdminImportProgress v-else-if="phase === 'applying'" kind="applying" :file-name="file.fileName.value" :type="info.nouns" :chunks="flow.progress.chunks" :chunk="flow.progress.chunk" :stopping="flow.stopRequested.value" @stop="flow.stopRequested.value = true" />

      <AdminImportResult
        v-else-if="phase === 'result'"
        :info="info"
        :totals="flow.totals.value"
        :outcome="flow.outcome.value"
        :excluded="flow.excluded.value"
        :file-rows="fileRows"
        :chunks="flow.progress.chunks"
        :failure="flow.failure.value"
        :undone="flow.undone.value"
        :undoing="flow.undoing.value"
        :can-undo="!!flow.batchId.value"
        @undo="flow.undo()"
        @again="flow.reset()"
        @errors="flow.downloadErrors()"
      />
    </div>
  </div>
</template>
