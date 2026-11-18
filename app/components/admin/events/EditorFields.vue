<script setup lang="ts">
import { Mountain, MapPin, Sparkles, TriangleAlert } from 'lucide-vue-next'
import type { GymOption } from '~/services/admin/events'
import { EVENT_TYPES } from '~/utils/admin-events'
import { formIsPast, MAX_EVENT_PLACE, MAX_EVENT_PRICE, MAX_EVENT_TITLE, type EventErrors, type EventForm } from '~/utils/admin-events-form'

/**
 * Fields of the event drawer. Everything the agent guessed carries "deducido" until the author touches it.
 * The description is not edited (the site does not show it, D33).
 */
const props = defineProps<{ gyms: readonly GymOption[]; errors: EventErrors; inferred: ReadonlySet<string>; focusDate?: boolean }>()
const form = defineModel<EventForm>('form', { required: true })
const touched = ref(new Set<string>())
const touch = (key: string) => (touched.value = new Set(touched.value).add(key))
const guessed = (...keys: string[]) => keys.some((k) => props.inferred.has(k) && !touched.value.has(k))

const typeOptions: { value: string; label: string }[] = EVENT_TYPES.map((t) => ({ value: t.value, label: t.label }))
const typeModel = computed<string>({
  get: () => form.value.type,
  set: (v) => {
    form.value.type = v as EventForm['type']
    touch('type')
  },
})
const placeOptions = [{ value: 'gym' as const, label: 'Rocódromo de la guía' }, { value: 'other' as const, label: 'Otro lugar' }]
const gymOptions = computed(() => props.gyms.map((g) => ({ value: g.id, label: g.name })))
const past = computed(() => formIsPast(form.value))
const typeId = `ev-type-${useId()}`
const mark = 'ml-1 inline-flex items-center gap-0.5 text-[11px] font-normal text-adm-meta'
</script>

<template>
  <div class="space-y-5">
    <AdminLangPair legend="Título">
      <template #es><AdminTextField v-model="form.titleEs" label="Título" lang="ES" name="titleEs" required :max="MAX_EVENT_TITLE" :error="errors.titleEs" :data-autofocus="focusDate ? undefined : ''" /></template>
      <template #en><AdminTextField v-model="form.titleEn" label="Título" lang="EN" name="titleEn" :max="MAX_EVENT_TITLE" :error="errors.titleEn" help="Sin título en inglés, el evento no sale en /en/agenda." /></template>
    </AdminLangPair>

    <div>
      <p :id="typeId" :class="admLabel">
        Tipo <span class="text-adm-danger" aria-hidden="true">*</span><span class="sr-only">(obligatorio)</span>
        <span v-if="guessed('type')" :class="mark"><Sparkles class="size-3" aria-hidden="true" />deducido</span>
      </p>
      <div data-field="type"><AdminSegmented v-model="typeModel" class="grid! w-full grid-cols-3" :labelledby="typeId" :options="typeOptions" /></div>
      <p v-if="errors.type" class="mt-1.5 text-xs text-adm-danger" role="alert">{{ errors.type }}</p>
    </div>

    <fieldset class="space-y-3">
      <legend :class="[admLabel, 'mb-0!']">Cuándo <span class="font-normal text-adm-meta">· hora de Barcelona</span></legend>
      <AdminSwitch v-model="form.allDay" label="Todo el día" name="allDay" />
      <div class="grid grid-cols-[minmax(0,1fr)_120px] gap-3">
        <AdminTextField v-model="form.startDate" type="date" label="Empieza" name="startDate" required :error="errors.startDate" :data-autofocus="focusDate ? '' : undefined" />
        <AdminTextField v-if="!form.allDay" v-model="form.startTime" type="time" label="Hora" name="startTime" :error="errors.startTime" />
      </div>
      <p v-if="past && !errors.startDate" class="flex items-start gap-1.5 text-xs text-adm-warn"><TriangleAlert class="mt-0.5 size-3.5 flex-none text-adm-warn-icon" aria-hidden="true" />Esta fecha ya ha pasado: no saldrá en la agenda.</p>
      <div class="grid grid-cols-[minmax(0,1fr)_120px] gap-3">
        <AdminTextField v-model="form.endDate" type="date" label="Termina (opcional)" name="endDate" :error="errors.endDate" @update:model-value="touch('end')" />
        <AdminTextField v-if="!form.allDay" v-model="form.endTime" type="time" label="Hora" name="endTime" @update:model-value="touch('end')" />
      </div>
      <p v-if="guessed('end', 'all_day')" :class="mark"><Sparkles class="size-3" aria-hidden="true" />El agente ha deducido la hora de fin o el «Todo el día»: compruébalo.</p>
    </fieldset>

    <fieldset>
      <legend :class="admLabel">Dónde</legend>
      <AdminSegmented v-model="form.placeMode" class="grid! w-full grid-cols-2" label="Tipo de lugar" :options="placeOptions" />
      <div class="mt-3">
        <div v-if="form.placeMode === 'gym'" data-field="place">
        <AdminSelect
          :model-value="form.itemId || undefined"
          label="Rocódromo"
          hide-label
          placeholder="Elige un rocódromo…"
          :options="gymOptions"
          :error="errors.place"
          help="En la agenda, el nombre enlaza a su ficha."
          @update:model-value="(v) => { form.itemId = v ?? ''; touch('place') }"
        />
        </div>
        <AdminTextField v-else v-model="form.locationText" label="Lugar" name="place" placeholder="Montserrat (Monistrol)" :max="MAX_EVENT_PLACE" :error="errors.place" help="Texto libre, sin enlace." @update:model-value="touch('place')" />
      </div>
      <p v-if="guessed('place')" :class="[mark, 'mt-1.5']"><Sparkles class="size-3" aria-hidden="true" />deducido</p>
      <p class="mt-1.5 flex items-center gap-1.5 text-xs text-adm-meta"><component :is="form.placeMode === 'gym' ? Mountain : MapPin" class="size-3.5" aria-hidden="true" />Solo vale una de las dos: con rocódromo, el sitio usa el nombre de su ficha.</p>
    </fieldset>

    <AdminTextField v-model="form.price" label="Precio (opcional)" name="price" :max="MAX_EVENT_PRICE" placeholder="15 € · gratis para socios" :error="errors.price" help="Tal como lo dice el organizador. Vacío: no se muestra." @update:model-value="touch('price')" />
    <p v-if="guessed('price')" :class="[mark, '-mt-4']"><Sparkles class="size-3" aria-hidden="true" />Precio deducido: compruébalo.</p>

    <AdminTextField v-model="form.url" label="Enlace del organizador" name="url" prefix="https://" placeholder="presabadalona.cat/agenda/clinic" :error="errors.url" help="Sale como «Más información». La agenda del sitio avisa de que fechas y precios pueden cambiar." />
  </div>
</template>
