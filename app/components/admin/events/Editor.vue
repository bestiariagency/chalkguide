<script setup lang="ts">
import { Ban, ChevronDown, CircleAlert, Loader2, Sparkles, Trash2, Undo2, X } from 'lucide-vue-next'
import type { EventSaveAction } from '~/composables/useAdminEventSave'
import type { GymOption } from '~/services/admin/events'
import { isPublished, type AdminEvent, type EventPreview } from '~/utils/admin-events'
import { emptyEventForm, eventToForm, formRange, validateEvent, type EventError, type EventErrors, type EventField, type EventForm } from '~/utils/admin-events-form'

/**
 * Event drawer (520 px; sheet under 768). New: Guardar borrador / Publicar. Draft: Descartar ▾, Guardar,
 * Guardar y aprobar. Published: Guardar (and, for approved, Marcar como cancelado; for cancelled, Volver a la
 * agenda). Discarded: read only with Recuperar. Events are saved at once, there is no draft of changes (D23).
 */
const props = defineProps<{ event?: AdminEvent; initial?: EventForm; gyms: readonly GymOption[]; busy: boolean; serverError?: EventError }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{
  save: [form: EventForm, action: EventSaveAction]
  reject: [reason: string | null]
  recover: []
  cancel: []
  uncancel: []
  remove: []
}>()

const form = ref<EventForm>(props.event ? eventToForm(props.event) : (props.initial ?? emptyEventForm()))
const snapshot = JSON.stringify(form.value)
const dirty = computed(() => JSON.stringify(form.value) !== snapshot)
const errors = ref<EventErrors>({})
const banner = ref<HTMLElement>()
const leaving = ref(false)

const isNew = computed(() => !props.event)
const status = computed(() => props.event?.status)
const locked = computed(() => status.value === 'rejected')
const published = computed(() => !!props.event && isPublished(props.event))
const title = computed(() => (props.event ? `Editar «${props.event.titleEs}»` : 'Nuevo evento'))
const inferred = computed(() => new Set(props.event?.agent?.inferred ?? []))
const found = computed(() => {
  const at = props.event ? collectedAt(props.event) : null
  return at ? adminDate(at) : null
})

const FIELD_LABELS: Partial<Record<EventField, string>> = { titleEs: 'título', titleEn: 'título en inglés', type: 'tipo', startDate: 'fecha de inicio', startTime: 'hora', endDate: 'fecha de fin', place: 'lugar', price: 'precio', url: 'enlace del organizador', allDay: 'todo el día' }
const errorFields = computed(() => (Object.keys(errors.value) as EventField[]).filter((k) => errors.value[k]))

function focusField(field: EventField) {
  const root = document.getElementById('event-form')
  const el = root?.querySelector<HTMLElement>(`[name="${field}"]:not([type=hidden]), [data-field="${field}"] button, [data-field="${field}"] input`)
  el?.focus()
}
function fail(next: EventErrors) {
  errors.value = next
  void nextTick(() => banner.value?.focus())
}
function submit(action: EventSaveAction) {
  if (props.busy || locked.value) return
  const publishing = action === 'publish' || action === 'save-approve' || (action === 'save' && published.value)
  const result = validateEvent(form.value, { publishing, wasLive: published.value })
  if (Object.keys(result).length || !formRange(form.value)) return fail(result)
  errors.value = {}
  emit('save', { ...form.value }, action)
}
watch(
  () => props.serverError,
  (e) => {
    if (!e) return
    errors.value = e.field ? { ...errors.value, [e.field]: e.message } : errors.value
    void nextTick(() => banner.value?.focus())
  },
)

/** Closing with unsaved changes asks first. */
function requestClose(value: boolean) {
  if (value) return
  if (dirty.value && !props.busy) leaving.value = true
  else open.value = false
}
function leave() {
  leaving.value = false
  open.value = false
}
const preview = computed<EventPreview>(() => {
  const range = formRange(form.value)
  const gym = form.value.placeMode === 'gym'
  return {
    titleEs: form.value.titleEs,
    titleEn: form.value.titleEn,
    type: form.value.type,
    startsAt: range?.startsAt ?? null,
    allDay: form.value.allDay,
    time: form.value.allDay ? '' : form.value.startTime,
    place: gym ? (props.gyms.find((g) => g.id === form.value.itemId)?.name ?? '') : form.value.locationText,
    gym,
    price: form.value.price,
    hasUrl: !!form.value.url.trim(),
    cancelled: status.value === 'cancelled',
  }
})
const bannerText = computed(() => props.serverError?.message)
</script>

<template>
  <AdminModal :open="open" :title="title" placement="right" wide :busy="busy" @update:open="requestClose">
    <form id="event-form" novalidate @submit.prevent="submit(isNew ? 'draft' : 'save')">
      <fieldset :disabled="locked" class="min-w-0 space-y-5">
        <div v-if="event" class="flex flex-wrap items-center gap-2"><AdminEventsChip :event="event" /><AdminEventsOrigin :source="event.source" /><AdminEventsFlags :event="event" /></div>

        <div v-if="errorFields.length || bannerText" ref="banner" tabindex="-1" role="alert" class="flex items-start gap-2 rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px] leading-5 text-adm-danger outline-none">
          <CircleAlert class="mt-0.5 size-4 flex-none" aria-hidden="true" />
          <span>
            <template v-if="bannerText && !errorFields.length">{{ bannerText }}</template>
            <template v-else>
              Revisa {{ errorFields.length }} {{ errorFields.length === 1 ? 'campo' : 'campos' }}:
              <template v-for="(field, i) in errorFields" :key="field">
                <button type="button" class="underline underline-offset-2" @click="focusField(field)">{{ FIELD_LABELS[field] ?? field }}</button>{{ i < errorFields.length - 1 ? ', ' : '.' }}
              </template>
            </template>
          </span>
        </div>

        <p v-if="event?.agent && status === 'draft'" class="flex items-start gap-2 rounded-lg bg-adm-warn-soft px-3 py-2 text-[13px] leading-5 text-adm-warn">
          <Sparkles class="mt-0.5 size-4 flex-none" aria-hidden="true" />
          <span>
            Propuesto por el agente<template v-if="found"> el <b>{{ found }}</b></template><template v-if="event.sourceUrl"> desde <a :href="safeHref(event.sourceUrl)" target="_blank" :rel="SOURCE_LINK_REL" class="underline underline-offset-2">{{ sourceDomain(event.sourceUrl) }}<span class="sr-only"> (se abre en otra pestaña)</span></a></template>.
            Los campos con «deducido» no estaban explícitos en la web: compruébalos.
          </span>
        </p>
        <p v-if="locked" class="rounded-lg bg-adm-subtle px-3 py-2 text-[13px] text-adm-meta">Está descartado: no se edita. «Recuperar» lo devuelve a Por aprobar.</p>

        <AdminEventsEditorFields v-model:form="form" :gyms="gyms" :errors="errors" :inferred="inferred" :focus-date="isNew && !form.startDate" />
      </fieldset>

      <div class="mt-5 space-y-5">
        <div class="border-t border-adm-line pt-4"><AdminEventsPreview :data="preview" selector /></div>

        <section v-if="event?.agent?.excerpt || event?.agent?.note" class="border-t border-adm-line pt-4 text-sm" aria-labelledby="ev-agent-h">
          <h3 id="ev-agent-h" class="flex items-center gap-2 text-sm font-semibold"><Sparkles class="size-4 text-adm-meta" aria-hidden="true" />Qué encontró el agente</h3>
          <p v-if="event.agent.note" class="mt-2"><span class="text-adm-meta">Nota:</span> {{ event.agent.note }}</p>
          <blockquote v-if="event.agent.excerpt" class="mt-2 border-l-2 border-adm-line-strong pl-3 text-adm-meta" lang="ca">{{ event.agent.excerpt }}</blockquote>
          <p class="mt-2 text-xs text-adm-meta">La fuente es fija: no se edita. El enlace del organizador sí.</p>
        </section>
      </div>
    </form>

    <template #footer>
      <template v-if="locked">
        <button type="button" :class="admBtnGhost" @click="open = false">Cerrar</button>
        <button type="button" :class="admBtnPrimary" :disabled="busy" @click="emit('recover')"><Undo2 aria-hidden="true" />Recuperar</button>
      </template>
      <template v-else>
        <div v-if="status === 'draft'" class="sm:mr-auto max-md:w-full">
          <AdminEventsRejectMenu :agent="event?.source === 'agent'" @select="(reason) => emit('reject', reason)">
            <button type="button" :class="[admBtnGhost, 'max-md:w-full']" :disabled="busy" aria-haspopup="menu"><X aria-hidden="true" />Descartar<ChevronDown class="size-3.5! text-adm-muted" aria-hidden="true" /></button>
          </AdminEventsRejectMenu>
        </div>
        <div v-else-if="event && (!published || status === 'approved' && !event.isPast || status === 'cancelled')" class="flex gap-2 sm:mr-auto max-md:w-full max-md:[&>*]:flex-1">
          <button v-if="!published" type="button" :class="admBtnDangerGhost" :disabled="busy" @click="emit('remove')"><Trash2 aria-hidden="true" />Eliminar…</button>
          <button v-if="status === 'approved' && !event.isPast" type="button" :class="admBtnGhost" :disabled="busy" @click="emit('cancel')"><Ban aria-hidden="true" />Marcar como cancelado</button>
          <button v-if="status === 'cancelled'" type="button" :class="admBtnGhost" :disabled="busy" @click="emit('uncancel')"><Undo2 aria-hidden="true" />Volver a la agenda</button>
        </div>
        <button type="button" :class="admBtnGhost" :disabled="busy" @click="requestClose(false)">Cancelar</button>
        <template v-if="isNew">
          <button type="button" :class="admBtnGhost" :disabled="busy" @click="submit('draft')">Guardar borrador</button>
          <button type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined" @click="submit('publish')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Publicar</button>
        </template>
        <template v-else-if="status === 'draft'">
          <button type="button" :class="admBtnGhost" :disabled="busy" @click="submit('save')">Guardar</button>
          <button type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined" @click="submit('save-approve')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar y aprobar</button>
        </template>
        <button v-else type="button" :class="admBtnPrimary" :disabled="busy" :aria-busy="busy || undefined" @click="submit('save')"><Loader2 v-if="busy" class="animate-adm-spin" aria-hidden="true" />Guardar</button>
      </template>
    </template>
  </AdminModal>

  <AdminModal v-model:open="leaving" alert stacked title="¿Salir sin guardar?" description="Tienes cambios sin guardar en este evento. Si sales, se pierden.">
    <template #footer>
      <button type="button" :class="admBtnGhost" data-autofocus @click="leaving = false">Seguir editando</button>
      <button type="button" :class="admBtnDanger" @click="leave">Salir sin guardar</button>
    </template>
  </AdminModal>
</template>
