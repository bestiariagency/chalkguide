import type { Database } from '~/types/database.types'
import type { EventType } from '~/types/domain'
import type { AdminEvent } from '~/utils/admin-events'
import { isPastEvent, madridParts, madridToIso } from '~/utils/admin-madrid'

export const MAX_EVENT_TITLE = 200
export const MAX_EVENT_PLACE = 200
export const MAX_EVENT_PRICE = 120
export const MAX_EVENT_URL = 500

export type PlaceMode = 'gym' | 'other'

/** The editor's form. The description is not edited (the site does not show it, D33) and is never sent. */
export interface EventForm {
  titleEs: string
  titleEn: string
  type: EventType | ''
  allDay: boolean
  startDate: string
  startTime: string
  endDate: string
  endTime: string
  placeMode: PlaceMode
  itemId: string
  locationText: string
  price: string
  /** Without the `https://` prefix (the field shows it as an affix). */
  url: string
}

export type EventField = keyof EventForm | 'place'
export type EventErrors = Partial<Record<EventField, string>>

export const emptyEventForm = (date = ''): EventForm => ({
  titleEs: '',
  titleEn: '',
  type: '',
  allDay: false,
  startDate: date,
  startTime: '',
  endDate: '',
  endTime: '',
  placeMode: 'gym',
  itemId: '',
  locationText: '',
  price: '',
  url: '',
})

const stripScheme = (url: string) => url.trim().replace(/^https?:\/\//i, '')

export function eventToForm(e: AdminEvent): EventForm {
  const start = madridParts(e.startsAt)
  const end = e.endsAt ? madridParts(e.endsAt) : null
  const gym = !e.itemId || e.itemPublished
  return {
    titleEs: e.titleEs,
    titleEn: e.titleEn ?? '',
    type: e.type,
    allDay: e.allDay,
    startDate: start.date,
    startTime: e.allDay ? '' : start.time,
    // All-day events end on their last day (inclusive), stored at 00:00.
    endDate: end && (end.date !== start.date || !e.allDay) ? end.date : '',
    endTime: end && !e.allDay ? end.time : '',
    placeMode: e.itemId && gym ? 'gym' : e.locationText ? 'other' : 'gym',
    itemId: e.itemId && gym ? e.itemId : '',
    locationText: e.itemId && gym ? '' : (e.locationText ?? ''),
    price: e.priceText ?? '',
    url: stripScheme(e.url ?? ''),
  }
}

/** A copy for another date (leagues, courses with several sessions): everything but the dates, which start empty. */
export function duplicateForm(e: AdminEvent): EventForm {
  return { ...eventToForm(e), startDate: '', startTime: e.allDay ? '' : madridParts(e.startsAt).time, endDate: '', endTime: '' }
}

/** ISO range of the form, or `null` while the start is incomplete. */
export function formRange(form: EventForm): { startsAt: string; endsAt: string | null } | null {
  if (!form.startDate || (!form.allDay && !form.startTime)) return null
  const startsAt = madridToIso(form.startDate, form.allDay ? '00:00' : form.startTime)
  const endDate = form.endDate || (form.endTime && !form.allDay ? form.startDate : '')
  if (!endDate) return { startsAt, endsAt: null }
  return { startsAt, endsAt: madridToIso(endDate, form.allDay ? '00:00' : form.endTime || form.startTime) }
}

export const formIsPast = (form: EventForm) => {
  const range = formRange(form)
  return !!range && isPastEvent(range.startsAt, range.endsAt, form.allDay)
}

function validUrl(value: string): boolean {
  if (/\s/.test(value)) return false
  try {
    const url = new URL(`https://${value}`)
    return url.hostname.includes('.') && !url.username && !url.password
  } catch {
    return false
  }
}

/**
 * `publishing`: approve now (new + Publicar, Guardar y aprobar, editing a live event). A draft only needs a
 * title and a date; the place is required to publish, as the database does (`event_place_required`).
 */
export function validateEvent(form: EventForm, { publishing, wasLive }: { publishing: boolean; wasLive: boolean }): EventErrors {
  const errors: EventErrors = {}
  if (!form.titleEs.trim()) errors.titleEs = 'Escribe el título en español.'
  else if (form.titleEs.length > MAX_EVENT_TITLE) errors.titleEs = `El título admite hasta ${MAX_EVENT_TITLE} caracteres.`
  if (form.titleEn.length > MAX_EVENT_TITLE) errors.titleEn = `El título admite hasta ${MAX_EVENT_TITLE} caracteres.`
  if (!form.type) errors.type = 'Elige el tipo de evento.'

  if (!form.startDate) errors.startDate = 'Pon la fecha de inicio.'
  else if (!form.allDay && !form.startTime) errors.startTime = 'Pon la hora o marca «Todo el día».'
  const range = formRange(form)
  if (range) {
    if (range.endsAt && new Date(range.endsAt) < new Date(range.startsAt)) errors.endDate = 'Termina antes de empezar.'
    else if (range.endsAt && new Date(range.endsAt).getTime() - new Date(range.startsAt).getTime() > 366 * 86_400_000) errors.endDate = 'Un evento no puede durar más de 366 días.'
    else if (publishing && !wasLive && isPastEvent(range.startsAt, range.endsAt, form.allDay)) errors.startDate = 'Esta fecha ya ha pasado: no se puede publicar así.'
  }

  if (form.price.length > MAX_EVENT_PRICE) errors.price = `El precio admite hasta ${MAX_EVENT_PRICE} caracteres.`
  const url = stripScheme(form.url)
  if (url && (!validUrl(url) || url.length + 8 > MAX_EVENT_URL)) errors.url = 'No es una dirección web válida. Ejemplo: presabadalona.cat/agenda'

  if (form.placeMode === 'gym') {
    if (publishing && !form.itemId) errors.place = 'Elige un rocódromo o cambia a «Otro lugar».'
  } else if (form.locationText.length > MAX_EVENT_PLACE) errors.place = `El lugar admite hasta ${MAX_EVENT_PLACE} caracteres.`
  else if (publishing && !form.locationText.trim()) errors.place = 'Escribe dónde es.'
  return errors
}

export type EventWrite = Database['guide']['Tables']['events']['Update']

/** Columns to write. Provenance (`source`, `agent_meta`…) and the description are never part of it. */
export type EventInsert = EventWrite & { title_es: string; event_type: EventType; starts_at: string }
export function formToWrite(form: EventForm): EventInsert {
  const range = formRange(form)
  if (!range || !form.type) throw new Error('incomplete event')
  const gym = form.placeMode === 'gym'
  const url = stripScheme(form.url)
  return {
    title_es: form.titleEs.trim(),
    title_en: form.titleEn.trim() || null,
    event_type: form.type,
    starts_at: range.startsAt,
    ends_at: range.endsAt,
    all_day: form.allDay,
    item_id: gym ? form.itemId || null : null,
    location_text: gym ? null : form.locationText.trim() || null,
    price_text: form.price.trim() || null,
    url: url ? `https://${url}` : null,
  }
}

const FIELD_ERRORS: [RegExp, EventField, string][] = [
  [/event_place_required/, 'place', 'Un evento publicado necesita un lugar: elige un rocódromo publicado o escribe dónde es.'],
  [/event_in_past/, 'startDate', 'Esta fecha ya ha pasado: no se puede publicar así.'],
  [/event_item_category/, 'place', 'Solo se pueden elegir fichas de rocódromo.'],
  [/event_item_not_published/, 'place', 'Esa ficha no está publicada: elige otra o escribe el lugar.'],
  [/events_dates/, 'endDate', 'Termina antes de empezar.'],
  [/events_duration/, 'endDate', 'Un evento no puede durar más de 366 días.'],
  [/events_starts_range/, 'startDate', 'La fecha de inicio está fuera de rango.'],
  [/events_all_day_midnight/, 'allDay', 'Un evento de todo el día no lleva hora. Quita las horas.'],
  [/events_url_https/, 'url', 'No es una dirección web válida (máximo 500 caracteres).'],
  [/events_text_no_control/, 'titleEs', 'Algún texto tiene caracteres de control. Pégalo como texto sin formato.'],
]

export interface EventError {
  field?: EventField
  message: string
  /** The row changed under us: reload the list. */
  reload?: boolean
}

/** Maps a Supabase/Postgres error of the Agenda actions to a field or banner message. */
export function eventError(error: unknown): EventError {
  const e = error as { code?: string; message?: string } | null
  const code = e?.code
  const message = e?.message ?? ''
  if (code === '23514') {
    const hit = FIELD_ERRORS.find(([re]) => re.test(message))
    return hit ? { field: hit[1], message: hit[2] } : { message: 'Algún dato no cumple las reglas de la agenda (formato o longitud).' }
  }
  if (code === '42501' && /event_id_immutable/.test(message)) return { message: 'El identificador del evento no se puede cambiar. Recarga la página.' }
  if (code === 'PT423') return { message: 'Un evento publicado no se elimina: retíralo de la agenda primero (vuelve a Por aprobar) o márcalo como cancelado.', reload: true }
  if (code === '55000') return { message: 'El evento ya había cambiado de estado (quizá en otra pestaña). Se ha recargado la lista.', reload: true }
  if (code === '42501') return { message: 'No tienes permiso para hacer esto. Vuelve a entrar en el panel.' }
  if (code === 'P0002') return { message: 'El evento ya no existe. Se ha recargado la lista.', reload: true }
  if (/fetch|network|failed to load/i.test(message)) return { message: 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.' }
  return { message: 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.' }
}
