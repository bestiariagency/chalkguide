import { addDays } from '~/utils/admin-dashboard'
import { madridParts, madridToIso } from '~/utils/admin-madrid'
import type { Database } from '~/types/database.types'
import type { EventType } from '~/types/domain'

export type EventStatus = Database['guide']['Enums']['event_status']
export type EventSource = Database['guide']['Enums']['event_source']

/** Shape of `agent_meta` (F8): `{confidence, note, excerpt, found_at, inferred[], duplicate_of}`. Absent for manual events. */
export interface AgentMeta {
  /** 0–1. */
  confidence: number
  note: string | null
  excerpt: string | null
  foundAt: string | null
  /** Fields the agent guessed: `type | start | end | all_day | price | place | title_en | description | url`. */
  inferred: string[]
  duplicateOf: string | null
}

/** One event as the panel reads it (`admin_list_events`). Provenance only arrives through that RPC. */
export interface AdminEvent {
  id: string
  status: EventStatus
  source: EventSource
  type: EventType
  titleEs: string
  titleEn: string | null
  startsAt: string
  endsAt: string | null
  allDay: boolean
  locationText: string | null
  url: string | null
  priceText: string | null
  itemId: string | null
  itemName: string | null
  itemSlug: string | null
  /** An unpublished item arrives with its name copied into `locationText` and counts as "Otro lugar". */
  itemPublished: boolean
  sourceUrl: string | null
  agent: AgentMeta | null
  /** Collection that created it and when it started (`ingest_runs`); null when manual or from before F8. */
  runId: string | null
  runStartedAt: string | null
  duplicate: { id: string; status: EventStatus } | null
  rejectReason: string | null
  hasEn: boolean
  isPast: boolean
  approvedAt: string | null
  createdAt: string
  updatedAt: string
}

export interface EventsSummary {
  /** Menu counter: drafts that have not expired. */
  badge: number
  pending: number
  pendingAgent: number
  pendingPast: number
  upcoming: number
  cancelledUpcoming: number
  pastPublished: number
  rejected: number
  total: number
  byType: Record<string, number>
}

export type EventView = 'revisar' | 'proximos' | 'pasados' | 'descartados' | 'todos'
export const EVENT_VIEWS: readonly { value: EventView; label: string }[] = [
  { value: 'revisar', label: 'Por aprobar' },
  { value: 'proximos', label: 'Próximos' },
  { value: 'pasados', label: 'Pasados' },
  { value: 'descartados', label: 'Descartados' },
  { value: 'todos', label: 'Todos' },
]
export const eventViewOf = (value: unknown): EventView | undefined => EVENT_VIEWS.find((v) => v.value === value)?.value

export const EVENT_TYPES: readonly { value: EventType; label: string; en: string }[] = [
  { value: 'competition', label: 'Competición', en: 'Competition' },
  { value: 'workshop', label: 'Taller', en: 'Workshop' },
  { value: 'outing', label: 'Quedada', en: 'Meet-up' },
  { value: 'social', label: 'Encuentro', en: 'Social' },
  { value: 'course', label: 'Curso', en: 'Course' },
  { value: 'other', label: 'Otro', en: 'Other' },
]
export const eventTypeLabel = (type: string, lang: 'es' | 'en' = 'es') => {
  const hit = EVENT_TYPES.find((t) => t.value === type)
  return hit ? (lang === 'en' ? hit.en : hit.label) : type
}

/** Reasons accepted by `reject_event` (`null` = sin motivo). `expired` is set by the nightly job and is not offered. */
export const EVENT_REJECT_REASONS = [
  { value: 'duplicate', label: 'Duplicado', icon: 'copy' },
  { value: 'not_climbing', label: 'No es de escalada', icon: 'circle-off' },
  { value: 'members_only', label: 'Solo para socios o privado', icon: 'lock' },
  { value: 'outside_area', label: 'Fuera del área de Barcelona', icon: 'map-pin-off' },
  { value: 'wrong_data', label: 'Fecha o datos incorrectos', icon: 'calendar-x' },
] as const
export const rejectReasonLabel = (reason: string | null) =>
  reason === 'expired' ? 'Caducado' : (EVENT_REJECT_REASONS.find((r) => r.value === reason)?.label ?? 'Sin motivo')

/** Visual state of an event: approved and past is "Pasado"; cancelled keeps its own chip. */
export type EventChipState = 'draft' | 'live' | 'past' | 'cancelled' | 'rejected'
export function chipState(e: Pick<AdminEvent, 'status' | 'isPast'>): EventChipState {
  if (e.status === 'draft') return 'draft'
  if (e.status === 'rejected') return 'rejected'
  if (e.status === 'cancelled') return 'cancelled'
  return e.isPast ? 'past' : 'live'
}

export const isPublished = (e: Pick<AdminEvent, 'status'>) => e.status === 'approved' || e.status === 'cancelled'
export const isGymPlace = (e: Pick<AdminEvent, 'itemId' | 'itemPublished'>) => !!e.itemId && e.itemPublished
export const placeOf = (e: AdminEvent) => (isGymPlace(e) ? e.itemName : e.locationText) ?? ''

// Confidence ------------------------------------------------------------------------------------
export const LOW_CONFIDENCE = 0.65
export const confidenceWord = (c: number) => (c >= 0.8 ? 'alta' : c >= LOW_CONFIDENCE ? 'media' : 'baja')
/** Filled segments out of 5. */
export const confidenceSegments = (c: number) => Math.round(Math.min(1, Math.max(0, c)) * 5)

/** Instant of the collection that proposed the event: the run's start, else the agent's `found_at`. */
export const collectedAt = (e: Pick<AdminEvent, 'runStartedAt' | 'agent'>) => e.runStartedAt ?? e.agent?.foundAt ?? null

export const inferredHas = (e: Pick<AdminEvent, 'agent'>, key: string) => !!e.agent?.inferred.includes(key)

/** Arguments of `admin_list_events` (see `queryFor`). */
export interface EventQuery {
  status?: EventStatus
  source?: EventSource
  when?: 'upcoming' | 'past' | 'all'
  from?: string
  to?: string
  itemId?: string
  types?: string[]
  search?: string
  sort?: 'asc' | 'desc'
}

// Query per view -----------------------------------------------------------------------------------
export interface EventFilters {
  search: string
  types: string[]
  /** Gym item id; empty = any place. */
  itemId: string
  /** `YYYY-MM-DD` bounds, inclusive; empty = open. */
  from: string
  to: string
  source: '' | 'agent' | 'manual'
  /** `ingest_runs.id` of a collection; empty = any. Filtered in the panel (the RPC has no such argument). */
  run: string
}

export const emptyEventFilters = (): EventFilters => ({ search: '', types: [], itemId: '', from: '', to: '', source: '', run: '' })

export const hasEventFilters = (f: EventFilters) => !!(f.search.trim() || f.types.length || f.itemId || f.from || f.to || f.source || f.run)

/** `admin_list_events` arguments of a view. Approved + cancelled are not one status: Próximos and Pasados filter the rest afterwards. */
export function queryFor(view: EventView, f: EventFilters, month?: string): EventQuery {
  const base = {
    search: f.search,
    types: f.types,
    itemId: f.itemId || undefined,
    source: f.source || undefined,
    from: f.from ? madridToIso(f.from) : undefined,
    to: f.to ? madridToIso(addDays(f.to, 1)) : undefined,
  }
  if (month) return { ...base, from: madridToIso(`${month}-01`), to: madridToIso(addDays(`${month}-01`, 32).slice(0, 8) + '01'), sort: 'asc' }
  if (view === 'revisar') return { ...base, status: 'draft', sort: 'asc' }
  if (view === 'proximos') return { ...base, when: 'upcoming', sort: 'asc' }
  if (view === 'pasados') return { ...base, when: 'past', sort: 'desc' }
  if (view === 'descartados') return { ...base, status: 'rejected', sort: 'desc' }
  return { ...base, sort: 'desc' }
}

export function inView(view: EventView, e: Pick<AdminEvent, 'status'>): boolean {
  return view === 'proximos' || view === 'pasados' ? isPublished(e) : true
}

export function viewCounts(s: EventsSummary): Record<EventView, number> {
  return { revisar: s.pending + s.pendingPast, proximos: s.upcoming + s.cancelledUpcoming, pasados: s.pastPublished, descartados: s.rejected, todos: s.total }
}

// Preview ("Así sale en la agenda") ------------------------------------------------------------------
export interface EventPreview {
  titleEs: string
  titleEn: string
  type: string
  /** Null while the form has no valid start. */
  startsAt: string | null
  allDay: boolean
  /** `HH:mm` of the start, empty for all-day events. */
  time: string
  place: string
  /** The place is a gym card (its name links to the card on the site). */
  gym: boolean
  price: string
  hasUrl: boolean
  cancelled: boolean
}

export function previewOf(e: AdminEvent): EventPreview {
  return {
    titleEs: e.titleEs,
    titleEn: e.titleEn ?? '',
    type: e.type,
    startsAt: e.startsAt,
    allDay: e.allDay,
    time: e.allDay ? '' : madridParts(e.startsAt).time,
    place: placeOf(e),
    gym: isGymPlace(e),
    price: e.priceText ?? '',
    hasUrl: !!e.url,
    cancelled: e.status === 'cancelled',
  }
}
