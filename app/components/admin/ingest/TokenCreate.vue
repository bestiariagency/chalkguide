<script setup lang="ts">
import { Check, Copy, Loader2 } from 'lucide-vue-next'
import { TOKEN_EXPIRY } from '~/utils/admin-ingest'

/**
 * Create a token in two steps (README §19.4). 1) name and expiry. 2) `alertdialog` «Copia el token ahora»: the plain token is shown
 * once with Copiar and the box «Lo he copiado y guardado en la rutina»; Hecho stays disabled until it is ticked. The token lives only in
 * the local `token` ref of this component: it is never put in global state, a toast, the URL or a log, and it is overwritten and
 * dropped when the dialog closes or the component is destroyed.
 */
const props = defineProps<{ busy: boolean; error?: string; create: (label: string, days: number) => Promise<string | undefined> }>()
const open = defineModel<boolean>('open', { default: true })

const label = ref(`Rutina en la nube ·${new Intl.DateTimeFormat('es-ES', { month: 'short', year: 'numeric' }).format(new Date()).replace('.', '')}`)
const days = ref<string | undefined>('30')
const token = ref('')
const acknowledged = ref(false)
const copied = ref(false)
const announce = ref('')

async function submit() {
  if (props.busy || !label.value.trim()) return
  token.value = (await props.create(label.value, Number(days.value ?? 30))) ?? ''
}
async function copy() {
  try {
    await navigator.clipboard.writeText(token.value)
    copied.value = true
    announce.value = 'Token copiado'
  } catch {
    announce.value = 'No se ha podido copiar. Selecciónalo y cópialo a mano.'
  }
}
/** Closing is only possible from «Hecho»; the token is wiped first. */
function done() {
  token.value = ''
  acknowledged.value = false
  copied.value = false
  announce.value = ''
  open.value = false
}
onBeforeUnmount(() => (token.value = ''))
const shown = computed(() => !!token.value)
</script>

<template>
  <AdminModal v-if="!shown" v-model:open="open" title="Crear token" :busy="busy">
    <form id="token-form" class="space-y-4" @submit.prevent="submit">
      <p v-if="error" class="rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] text-adm-danger" role="alert">{{ error }}</p>
      <AdminTextField v-model="label" label="Nombre" required :max="60" data-autofocus />
      <AdminSelect v-model="days" label="Caduca" :options="[...TOKEN_EXPIRY]" help="Máximo 30 días: lo fija el servidor. Te avisamos 5 días antes en Inicio." />
    </form>
    <template #footer>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="submit" form="token-form" :class="admBtnPrimary" :disabled="busy || !label.trim()" :aria-busy="busy || undefined"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Crear</button>
    </template>
  </AdminModal>

  <AdminModal v-else :open="true" alert title="Copia el token ahora" description="Solo se muestra esta vez. Pégalo en el entorno de la rutina. Si lo pierdes, revócalo y crea otro.">
    <div class="space-y-3">
      <p class="rounded-lg border border-adm-line-strong bg-adm-subtle p-3 font-mono text-[13px] break-all select-all" aria-label="Token">{{ token }}</p>
      <button type="button" :class="[admBtnGhost, 'w-full']" @click="copy"><component :is="copied ? Check : Copy" aria-hidden="true" />{{ copied ? 'Copiado' : 'Copiar' }}</button>
      <span class="sr-only" role="status">{{ announce }}</span>
      <label class="flex min-h-11 items-start gap-3 pt-1 text-sm"><AdminCheckbox :model-value="acknowledged" label="Lo he copiado y guardado en la rutina" class="mt-0.5" @update:model-value="(v) => (acknowledged = v === true)" /><span aria-hidden="true">Lo he copiado y guardado en la rutina.</span></label>
    </div>
    <template #footer><button type="button" :class="admBtnPrimary" :disabled="!acknowledged" @click="done">Hecho</button></template>
  </AdminModal>
</template>
