<script setup lang="ts">
import { CalendarClock, CircleCheck, CircleX, TriangleAlert, Undo2, Upload } from 'lucide-vue-next'
import { fromBarcelonaInput, scheduleSlot, toBarcelonaInput } from '~/utils/admin-articles'
import type { ChecklistItem } from '~/utils/article-form'

/** Publish now or schedule. Blocking checks stop it; advice (cover alt, lead…) is shown but allows it. */
const props = defineProps<{ checklist: ChecklistItem[]; busy: boolean; scheduled: boolean; scheduledAt: string | null }>()
const emit = defineEmits<{ now: []; schedule: [iso: string]; draft: [] }>()
const open = defineModel<boolean>('open', { default: false })
const mode = defineModel<'now' | 'schedule'>('mode', { default: 'now' })

const when = ref('')
const error = ref('')
const total = computed(() => props.checklist.length)
const passed = computed(() => props.checklist.filter((i) => i.ok).length)
const blockers = computed(() => props.checklist.filter((i) => i.blocking && !i.ok))
const advice = computed(() => props.checklist.filter((i) => !i.blocking && !i.ok))

watch(open, (value) => {
  if (!value) return
  error.value = ''
  when.value = props.scheduledAt ? toBarcelonaInput(props.scheduledAt) : scheduleSlot('tomorrow')
})

function confirm() {
  if (mode.value === 'now') return emit('now')
  const date = fromBarcelonaInput(when.value)
  if (!when.value || Number.isNaN(date.getTime()) || date.getTime() < Date.now() + 60_000) {
    error.value = 'Elige una fecha y hora futuras.'
    return
  }
  emit('schedule', date.toISOString())
}
const choice = 'flex min-h-11 cursor-pointer items-start gap-2.5 rounded-lg border border-adm-line p-3 has-[:checked]:border-adm-acc has-[:checked]:bg-adm-acc-soft has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-adm-acc'
</script>

<template>
  <AdminModal v-model:open="open" :busy="busy" :title="mode === 'schedule' ? 'Programar publicación' : 'Publicar artículo'" description="Publicar lo hace visible en el sitio; programar lo publica a la hora elegida.">
    <fieldset class="space-y-2">
      <legend class="sr-only">Cuándo publicar</legend>
      <label :class="choice"><input v-model="mode" type="radio" value="now" name="publish-mode" class="mt-1 accent-adm-acc" :data-autofocus="mode === 'now' ? '' : undefined" /><span><b class="font-medium">Publicar ahora</b><span class="block text-xs text-adm-meta">Visible en el sitio en cuanto se reconstruya.</span></span></label>
      <label :class="choice"><input v-model="mode" type="radio" value="schedule" name="publish-mode" class="mt-1 accent-adm-acc" :data-autofocus="mode === 'schedule' ? '' : undefined" /><span><b class="font-medium">Programar</b><span class="block text-xs text-adm-meta">Se publica solo en la fecha elegida.</span></span></label>
    </fieldset>
    <div v-if="mode === 'schedule'" class="mt-3">
      <AdminField v-slot="{ id, describedby, invalid }" label="Fecha y hora (hora de Barcelona)" :error="error" required>
        <input :id="id" v-model="when" type="datetime-local" :aria-describedby="describedby" :aria-invalid="invalid || undefined" :class="[admInput, invalid && admInputInvalid]" />
      </AdminField>
      <div class="mt-2 flex flex-wrap gap-2" role="group" aria-label="Atajos de fecha">
        <button type="button" :class="[admBtnGhost, 'h-7 text-xs max-md:h-11']" @click="when = scheduleSlot('tomorrow')">Mañana 08:00</button>
        <button type="button" :class="[admBtnGhost, 'h-7 text-xs max-md:h-11']" @click="when = scheduleSlot('monday')">Lunes 08:00</button>
      </div>
    </div>
    <p v-if="!blockers.length && !advice.length" class="mt-4 flex items-center gap-2 rounded-lg bg-adm-ok-soft p-3 text-[13px] text-adm-ok" role="status">
      <CircleCheck class="size-4 flex-none" aria-hidden="true" />Listo para publicar · {{ passed }} de {{ total }} comprobaciones
    </p>
    <ul v-if="blockers.length" class="mt-4 space-y-1.5 rounded-lg bg-adm-danger-soft p-3 text-[13px]" role="alert">
      <li v-for="item in blockers" :key="item.key" class="flex gap-2"><CircleX class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" /><span>{{ item.hint ?? item.label }}<AdminEditorChecklistLinks :item="item" /></span></li>
    </ul>
    <ul v-else-if="advice.length" class="mt-4 space-y-1.5 rounded-lg bg-adm-warn-soft p-3 text-[13px]">
      <li v-for="item in advice" :key="item.key" class="flex gap-2"><TriangleAlert class="mt-0.5 size-4 flex-none text-adm-warn-icon" aria-hidden="true" />Recomendado: {{ item.label.toLowerCase() }}</li>
    </ul>
    <template #footer>
      <button v-if="scheduled" type="button" :class="[admBtnQuiet, 'mr-auto']" :disabled="busy" @click="emit('draft')"><Undo2 aria-hidden="true" />Volver a borrador</button>
      <button type="button" :class="admBtnGhost" :disabled="busy" @click="open = false">Cancelar</button>
      <button type="button" :class="admBtnPrimary" :disabled="busy || blockers.length > 0" @click="confirm">
        <component :is="mode === 'now' ? Upload : CalendarClock" aria-hidden="true" />{{ mode === 'now' ? 'Publicar' : 'Programar' }}
      </button>
    </template>
  </AdminModal>
</template>
