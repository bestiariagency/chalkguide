<script setup lang="ts">
import { CircleAlert, Copy, Plus, X } from 'lucide-vue-next'
import type { HoursForm } from '~/utils/item-fields'
import type { ItemErrors } from '~/utils/item-patch'
import { WEEKDAYS, closingValue, type Weekday } from '~/utils/opening-hours'

/** Weekly schedule (hora de Barcelona): one row per day, several slots when the gym closes at midday. */
const props = defineProps<{ errors: ItemErrors }>()
const hours = defineModel<HoursForm>({ required: true })
const DAYS: Record<Weekday, string> = { mon: 'Lunes', tue: 'Martes', wed: 'Miércoles', thu: 'Jueves', fri: 'Viernes', sat: 'Sábado', sun: 'Domingo' }
const errorList = computed(() => WEEKDAYS.filter((d) => props.errors[`opening_hours.${d}`]))
const timeInput = [admInput, 'w-[88px]! tabular-nums text-center']

function addSlot(day: Weekday) {
  const last = hours.value[day].slots.at(-1)
  hours.value[day].closed = false
  hours.value[day].slots.push(last ? [last[1], ''] : ['07:00', '23:00'])
}
const removeSlot = (day: Weekday, index: number) => hours.value[day].slots.splice(index, 1)
function toggleClosed(day: Weekday, closed: boolean) {
  hours.value[day].closed = closed
  if (!closed && !hours.value[day].slots.length) addSlot(day)
}
function copyMonday() {
  for (const day of ['tue', 'wed', 'thu', 'fri'] as const) hours.value[day] = { closed: hours.value.mon.closed, slots: hours.value.mon.slots.map(([a, b]) => [a, b]) }
}
</script>

<template>
  <div>
    <div class="flex items-end gap-3">
      <div>
        <h3 class="text-sm font-semibold">Horario</h3>
        <p class="mt-0.5 text-xs text-adm-meta">Hora de Barcelona. Varios tramos por día si cierra a mediodía. Para cerrar a medianoche, escribe 24:00 (o 00:00). Un día sin tramos ni marca de cerrado no se muestra.</p>
      </div>
      <button type="button" :class="[admBtnQuiet, 'ml-auto h-7 text-xs max-md:h-11']" @click="copyMonday"><Copy aria-hidden="true" />Copiar el lunes a martes–viernes</button>
    </div>
    <p v-if="errorList.length" class="mt-3 flex items-start gap-2 rounded-lg bg-adm-danger-soft px-3 py-2 text-[13px]" role="alert">
      <CircleAlert class="mt-0.5 size-4 flex-none text-adm-danger" aria-hidden="true" />
      <span>{{ errorList.length }} {{ errorList.length === 1 ? 'error' : 'errores' }}: <template v-for="(day, i) in errorList" :key="day"><a :href="`#gym-hours-${day}`" class="underline underline-offset-2">{{ DAYS[day].toLowerCase() }}</a>{{ i < errorList.length - 1 ? ', ' : '' }}</template>.</span>
    </p>
    <ul class="mt-3 divide-y divide-adm-line rounded-lg border border-adm-line bg-adm-elev">
      <li v-for="day in WEEKDAYS" :id="`gym-hours-${day}`" :key="day" :class="['flex flex-wrap items-center gap-x-3 gap-y-2 px-3 py-2', errors[`opening_hours.${day}`] && 'bg-adm-danger-soft/40']">
        <span class="order-1 w-24 text-sm sm:order-none">{{ DAYS[day] }}</span>
        <!-- < sm: line 1 = day + "Cerrado"; line 2 = slots + "Tramo". From sm up it is one row (contents). -->
        <div class="order-3 flex basis-full flex-wrap items-center gap-x-3 gap-y-2 sm:order-none sm:contents">
        <template v-if="!hours[day].closed">
          <div v-for="(slot, index) in hours[day].slots" :key="index" class="flex items-center gap-1.5">
            <input v-model="slot[0]" type="text" inputmode="numeric" placeholder="07:00" :class="timeInput" :aria-label="`${DAYS[day]}, abre${hours[day].slots.length > 1 ? `, tramo ${index + 1}` : ''}`" :aria-invalid="!!errors[`opening_hours.${day}`] || undefined" :aria-describedby="errors[`opening_hours.${day}`] ? `gym-hours-${day}-e` : undefined" />
            <span class="text-adm-muted" aria-hidden="true">–</span>
            <input v-model="slot[1]" type="text" inputmode="numeric" placeholder="23:00" :class="timeInput" :aria-label="`${DAYS[day]}, cierra${hours[day].slots.length > 1 ? `, tramo ${index + 1}` : ''}`" :aria-invalid="!!errors[`opening_hours.${day}`] || undefined" :aria-describedby="errors[`opening_hours.${day}`] ? `gym-hours-${day}-e` : undefined" @change="slot[1] = closingValue(slot[1])" />
            <button type="button" :class="admIconBtn" :aria-label="`Quitar tramo ${index + 1} del ${DAYS[day].toLowerCase()}`" @click="removeSlot(day, index)"><X aria-hidden="true" /></button>
          </div>
          <button type="button" :class="[admBtnQuiet, 'h-7 text-xs max-md:h-11']" @click="addSlot(day)"><Plus aria-hidden="true" />Tramo</button>
        </template>
        <span v-else class="text-sm text-adm-meta max-sm:hidden">Cerrado</span>
        </div>
        <label class="order-2 ml-auto flex items-center gap-2 text-xs text-adm-meta max-md:min-h-11 sm:order-none">
          <input type="checkbox" :checked="hours[day].closed" class="size-4 accent-[var(--adm-acc)]" @change="toggleClosed(day, ($event.target as HTMLInputElement).checked)" />Cerrado
        </label>
        <p v-if="errors[`opening_hours.${day}`]" :id="`gym-hours-${day}-e`" class="order-4 flex w-full sm:order-none items-start gap-1.5 text-xs text-adm-danger"><CircleAlert class="mt-px size-3.5 flex-none" aria-hidden="true" />{{ errors[`opening_hours.${day}`] }}</p>
      </li>
    </ul>
  </div>
</template>
