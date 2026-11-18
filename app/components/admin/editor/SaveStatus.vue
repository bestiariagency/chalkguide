<script setup lang="ts">
import { Check, CircleAlert, Loader2, PenLine } from 'lucide-vue-next'
import type { SaveState } from '~/composables/useArticleAutosave'

/** "Guardado · hace 4 s" with live region; error with "Reintentar". */
const props = defineProps<{ state: SaveState; savedAt: number | null; message: string; readonly?: boolean }>()
defineEmits<{ retry: [] }>()

const now = ref(Date.now())
let interval: ReturnType<typeof setInterval> | undefined
onMounted(() => (interval = setInterval(() => (now.value = Date.now()), 10_000)))
onBeforeUnmount(() => clearInterval(interval))

const ago = computed(() => {
  if (!props.savedAt) return ''
  const seconds = Math.max(0, Math.round((now.value - props.savedAt) / 1000))
  if (seconds < 10) return 'ahora mismo'
  if (seconds < 60) return `hace ${seconds} s`
  if (seconds < 3600) return `hace ${Math.round(seconds / 60)} min`
  if (seconds < 86_400) return `hace ${Math.floor(seconds / 3600)} h`
  return ''
})
/** From 24 h on: a short date. */
const stale = computed(() => !!props.savedAt && now.value - props.savedAt >= 86_400_000)
const savedIso = computed(() => (props.savedAt ? new Date(props.savedAt).toISOString() : ''))
</script>

<template>
  <div class="flex items-center gap-1 text-xs whitespace-nowrap" aria-live="polite">
    <template v-if="readonly"><span class="text-adm-muted">Solo lectura</span></template>
    <template v-else-if="state === 'error'">
      <CircleAlert class="size-3.5 text-adm-danger" aria-hidden="true" /><span class="text-adm-danger">No se ha guardado.</span>
      <button type="button" class="underline underline-offset-2 max-md:min-h-11" @click="$emit('retry')">Reintentar</button>
      <span class="sr-only">{{ message }}</span>
    </template>
    <template v-else-if="state === 'saving'"><Loader2 class="size-3.5 animate-adm-spin text-adm-muted" aria-hidden="true" /><span class="text-adm-muted">Guardando…</span></template>
    <template v-else-if="state === 'dirty'"><PenLine class="size-3.5 text-adm-muted" aria-hidden="true" /><span class="text-adm-muted">Cambios sin guardar</span></template>
    <template v-else-if="state === 'blocked'"><CircleAlert class="size-3.5 text-adm-warn-icon" aria-hidden="true" /><span class="text-adm-warn">Revisa los errores: no se guarda</span></template>
    <template v-else-if="savedAt"><Check class="size-3.5 text-adm-muted" aria-hidden="true" /><span class="text-adm-muted">Guardado · <AdminTime v-if="stale" :iso="savedIso" short /><template v-else>{{ ago }}</template></span></template>
    <span v-else class="text-adm-muted">Sin cambios</span>
  </div>
</template>
