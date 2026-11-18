<script setup lang="ts">
import { CircleCheck, KeyRound, Siren, Timer } from 'lucide-vue-next'
import { alertText, daysSince, RUNBOOK_PATH, runbookHref, runErrorLines, type AdminRun, type IngestHealth } from '~/utils/admin-ingest'

/**
 * Health of the routine (`job_health` of `ingest`, README §19.4), always on top: green when all is well, red `role="alert"`
 * with the days without a good collection, the last error (plain text, interpolated) and the way out: a new token. Also the manual
 * window of R1 («abrir ventana 2 h»), which lets the routine collect outside Monday and Thursday.
 */
const props = defineProps<{ health: IngestHealth | null; runs: readonly AdminRun[]; windowUntil: string | null; windowOpen: boolean; busy: boolean }>()
const emit = defineEmits<{ 'new-token': []; 'open-window': []; 'close-window': [] }>()

const next = computed(() => runLabel(nextRunAt()))
const lastOk = computed(() => props.health?.lastOkAt ?? props.runs.find((r) => r.status === 'ok' && !r.dryRun)?.startedAt ?? null)
const days = computed(() => (lastOk.value ? daysSince(lastOk.value) : null))
const stale = computed(() => !!props.health?.alerts.includes('no_ok_run_4d'))
const others = computed(() => (props.health?.alerts ?? []).filter((a) => a !== 'no_ok_run_4d'))
/** The most recent failure the routine reported: its first line. */
const lastError = computed(() => {
  const failed = props.runs.find((r) => r.status === 'error' || r.errors)
  return failed ? (runErrorLines(failed)[0] ?? null) : null
})
const runbook = runbookHref(useRuntimeConfig().public.repoUrl)
</script>

<template>
  <div class="space-y-2 px-4 pt-4 md:px-6">
    <AdminBanner v-if="!health" :icon="Timer">Todavía no hay datos de salud: se calculan cada hora. Hasta la primera recogida correcta, la rutina saldrá como «sin recoger».</AdminBanner>
    <AdminBanner v-else-if="health.ok" class="[&_svg]:text-adm-ok!" :icon="CircleCheck">
      <b class="font-medium">Todo en marcha.</b>
      <template v-if="lastOk"> Última recogida correcta: {{ runLabel(lastOk) }} (hace {{ days }} {{ days === 1 ? 'día' : 'días' }}).</template>
      Próxima: {{ next }}.
    </AdminBanner>
    <AdminBanner v-else kind="err" :icon="Siren">
      <p>
        <b class="font-medium">
          <template v-if="stale || !lastOk">{{ lastOk ? `Sin una recogida correcta desde hace ${days} días` : 'Todavía no hay ninguna recogida correcta' }}</template>
          <template v-else>La rutina tiene avisos</template>
        </b>
        <template v-if="lastOk && (stale || days)"> (última: {{ runLabel(lastOk) }}). El aviso salta a los 4 días.</template>
      </p>
      <ul v-if="others.length" class="mt-1 list-disc pl-4"><li v-for="a in others" :key="a">{{ alertText(a) }}</li></ul>
      <p v-if="lastError" class="mt-1">Último error: <span class="font-mono text-xs">{{ lastError }}</span></p>
      <p class="mt-1 text-adm-meta">
        Para rotar el token: crea uno nuevo, pégalo en la rutina y revoca el anterior.
        <a v-if="runbook" :href="runbook" target="_blank" rel="noopener noreferrer" class="underline underline-offset-2">Runbook: rotar el token<span class="sr-only"> (se abre en otra pestaña)</span></a>
        <template v-else>Runbook: rotar el token, en <span class="font-mono text-xs">{{ RUNBOOK_PATH }}</span>.</template>
      </p>
      <template #actions><button type="button" :class="[admBtnGhost, 'h-8']" @click="emit('new-token')"><KeyRound aria-hidden="true" />Crear token nuevo</button></template>
    </AdminBanner>

    <div class="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-adm-meta">
      <template v-if="windowOpen && windowUntil">
        <span :class="[admChip, 'bg-adm-st-sched-bg text-adm-st-sched']"><Timer aria-hidden="true" />Ventana abierta hasta las {{ madridParts(windowUntil).time }}</span>
        <button type="button" :class="[admBtnQuiet, 'h-8']" :disabled="busy" @click="emit('close-window')">Cerrar ventana</button>
      </template>
      <template v-else>
        <button type="button" :class="[admBtnGhost, 'h-8']" :disabled="busy" @click="emit('open-window')"><Timer aria-hidden="true" />Abrir ventana de 2 h</button>
        <span class="max-w-[60ch]">La rutina solo recoge lunes y jueves de 03:00 a 12:00. La ventana le deja recoger ahora, durante 2 horas.</span>
      </template>
    </div>
  </div>
</template>
