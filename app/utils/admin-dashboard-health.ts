import { dayKey, fmtInt, hhmm, type DashboardStats } from './admin-dashboard'
import type { PendingRow } from './admin-dashboard-pending'

/** Bloque «Sistema» de Pendiente (README §20): avisos que salen de `guide.job_health`. */
export interface JobHealth {
  job: string
  checkedAt: string | null
  statusCode: number | null
  /** `details.alerts`. */
  alerts: string[]
  /** Numeric fields of `details` (`cap_per_day`, `today_attempts`...). */
  numbers: Record<string, number>
}

export const HEALTH_JOBS = ['analytics', 'cookie_consent']

const HOUR = 3_600_000
const FRESH_MS = 3 * HOUR
const STOPPED_MS = 24 * HOUR
const CLEANUP_MAX_AGE_MS = 48 * HOUR

const JOB_NAME = { cookie_consent: 'consentimientos de cookies', analytics: 'analítica' } as const
const TASK = { cookie_consent: 'guide-cookie-consent-purge', analytics: 'guide-analytics-purge' } as const
type Job = keyof typeof JOB_NAME

const plural = (n: number, one: string, many: string) => `${fmtInt(n)} ${n === 1 ? one : many}`

function ageText(ms: number): string {
  const hours = Math.floor(ms / HOUR)
  return hours >= 48 ? `${Math.floor(hours / 24)} días` : `${Math.max(hours, 1)} h`
}

/** «18 nov» of a UTC day (the caps count per UTC day). */
const utcDay = (iso: string, offsetDays = 0) =>
  new Intl.DateTimeFormat('es-ES', { timeZone: 'UTC', day: 'numeric', month: 'short' }).format(new Date(Date.parse(iso) + offsetDays * 86_400_000)).replace('.', '')

const checkedAt = (iso: string, now: number) =>
  dayKey(iso) === dayKey(new Date(now)) ? `comprobado a las ${hhmm(iso)}` : `comprobado ayer a las ${hhmm(iso)}`

type Notice = Omit<PendingRow, 'key'> & { order: number }

const SR = { danger: 'Fallo: ', warn: 'Aviso: ', subtle: 'Sin confirmar: ' } as const

function consentNotice(h: JobHealth, checked: string): Notice | null {
  const n = h.numbers
  const cap = n.cap_per_day ?? 0
  const hits = n.minute_cap_hits_last_hour ?? 0
  const capToday = h.alerts.includes('daily_cap_reached') && (n.today_attempts ?? 0) >= cap
  const bursts = h.alerts.includes('minute_cap_hits')
  const base = { icon: 'consent' as const }
  if (capToday)
    return {
      ...base,
      tone: 'danger',
      sr: SR.danger,
      order: 0,
      strong: 'No se registran todos los consentimientos de cookies',
      context: [`Hoy: tope de ${fmtInt(cap)} alcanzado`, bursts && plural(hits, 'minuto al tope en la última hora', 'minutos al tope en la última hora'), checked].filter(Boolean).join(' · '),
      help: 'Los visitantes no lo notan, pero los consentimientos por encima del tope no quedan registrados y no se recuperan. Revisa el origen en Supabase antes de subir el tope.',
    }
  if (bursts)
    return {
      ...base,
      tone: 'danger',
      sr: SR.danger,
      order: 0,
      strong: 'Ráfagas en el registro de consentimientos',
      context: [`${plural(hits, 'minuto', 'minutos')} al tope de ${fmtInt(n.cap_per_minute ?? 0)} en la última hora`, 'posible bot', checked].join(' · '),
      help: 'En esos minutos no se registraron consentimientos reales. Si sigue, revisa el origen del tráfico en Supabase.',
    }
  if (h.alerts.includes('daily_cap_reached'))
    return {
      ...base,
      tone: 'warn',
      sr: SR.warn,
      order: 1,
      strong: 'Ayer no se registraron todos los consentimientos de cookies',
      context: `${utcDay(h.checkedAt!, -1)}: tope de ${fmtInt(cap)} alcanzado · hoy, normal (${fmtInt(n.today_attempts ?? 0)}) · ${checked}`,
      help: 'Los consentimientos de ayer por encima del tope no se recuperan. El aviso se va solo si hoy no se repite.',
    }
  return null
}

function analyticsNotice(h: JobHealth, checked: string): Notice | null {
  if (!h.alerts.includes('daily_cap_reached')) return null
  const n = h.numbers
  const today = (n.today_attempts ?? 0) >= (n.cap_per_day ?? 0)
  return {
    icon: 'analytics',
    tone: 'warn',
    sr: SR.warn,
    order: 1,
    strong: today ? 'Las cifras de hoy no son fiables' : `Las cifras del ${utcDay(h.checkedAt!, -1)} no son fiables`,
    context: `Tope de ${fmtInt(n.cap_per_day ?? 0)} eventos alcanzado · ese día las visitas salen por debajo de las reales · ${checked}`,
    help: 'Los eventos por encima del tope no se guardan. Si fue un pico real, se puede subir el tope; si fue un bot, no hace falta hacer nada.',
  }
}

/** Recent 500 whose alert the panel does not know: still shown, with the raw code. */
function genericNotice(job: Job, h: JobHealth, checked: string): Notice {
  const tone = job === 'cookie_consent' ? 'danger' : 'warn'
  return {
    icon: job === 'cookie_consent' ? 'consent' : 'analytics',
    tone,
    sr: SR[tone],
    order: tone === 'danger' ? 0 : 1,
    strong: `Ha fallado la comprobación de ${JOB_NAME[job]}`,
    context: `Aviso sin reconocer: ${h.alerts.join(', ') || 'sin código'} · ${checked}`,
    help: 'El panel no sabe explicar este aviso. Mira el detalle de la tarea en Supabase.',
  }
}

/** One check of a daily-cap job: failure, unconfirmed (last 500 between 3 h and 24 h), stopped (> 24 h or no row) or nothing (README §20.2). */
function jobNotice(job: Job, h: JobHealth | undefined, now: number): Notice | null {
  const checkedMs = h?.checkedAt ? Date.parse(h.checkedAt) : NaN
  const age = Number.isFinite(checkedMs) ? now - checkedMs : Infinity
  if (age > STOPPED_MS)
    return {
      icon: 'stopped',
      tone: 'warn',
      sr: SR.warn,
      order: 1,
      strong: `Comprobación de ${JOB_NAME[job]} parada`,
      context: `${Number.isFinite(age) ? `Sin comprobar desde hace ${ageText(age)}` : 'Nunca comprobada'} · no se vigila el tope ni se purga${job === 'cookie_consent' ? ' el registro' : 'n los eventos'}`,
      help: 'Comprueba en Supabase que la tarea programada {code} sigue activa.',
      helpCode: TASK[job],
    }
  if (!h || h.statusCode !== 500) return null
  const checked = checkedAt(h.checkedAt!, now)
  if (age <= FRESH_MS) return (job === 'cookie_consent' ? consentNotice(h, checked) : analyticsNotice(h, checked)) ?? genericNotice(job, h, checked)
  return {
    icon: job === 'cookie_consent' ? 'consent-unknown' : 'analytics',
    tone: 'subtle',
    sr: SR.subtle,
    order: 2,
    strong: `No se ha podido confirmar el estado de ${JOB_NAME[job]}`,
    context: `Último aviso a las ${hhmm(h.checkedAt!)} · sin comprobar desde hace ${ageText(age)}`,
    help: 'Puede ser un simple retraso: se comprueba cada hora. Si mañana sigue igual, saldrá como comprobación parada.',
  }
}

/** Cleanup of reader photos (not confirmed: failed status, never checked or older than 48 h). Texts unchanged since F6.19. */
function cleanupNotice(stats: DashboardStats, now: number): Notice | null {
  const checked = stats.cleanupCheckedAt ? Date.parse(stats.cleanupCheckedAt) : NaN
  const never = !Number.isFinite(checked)
  const stale = !never && now - checked > CLEANUP_MAX_AGE_MS
  if (stats.cleanupLastStatus === 200 && !never && !stale) return null
  const known = !never && !stale
  const tone = known ? 'danger' : 'warn'
  return {
    icon: 'cleanup',
    tone,
    sr: SR[tone],
    order: tone === 'danger' ? 0 : 1,
    strong: never ? 'Limpieza nocturna de fotos nunca comprobada' : stale ? 'Limpieza nocturna de fotos sin comprobar hace más de 48 h' : 'Ha fallado la limpieza nocturna de fotos',
    context: known ? 'Las fotos rechazadas o caducadas pueden no borrarse' : 'No se sabe si se borran las fotos rechazadas o caducadas',
    help: 'Comprueba que la limpieza sigue programada y que su secreto coincide en Edge Function secrets y en Vault.',
  }
}

export interface SystemInput {
  stats: DashboardStats
  now: number
  /** Failing `ingest` check of the agent (`admin_news_summary`). */
  ingestFailing: boolean
  /** `job_health` rows of `analytics` and `cookie_consent`; `null` when they could not be read (no rows, no error). */
  health: JobHealth[] | null
}

/** Rows of the «Sistema» block: danger, then warn, then neutral; ties as ingest, consent, cleanup, analytics. */
export function systemRows({ stats, now, ingestFailing, health }: SystemInput): PendingRow[] {
  const by = (job: Job) => health?.find((h) => h.job === job)
  const rows: (PendingRow & { order: number })[] = []
  const add = (key: string, notice: Notice | null) => notice && rows.push({ key, ...notice })
  if (ingestFailing)
    add('ingest', { icon: 'ingest', tone: 'danger', sr: SR.danger, order: 0, to: adminPath('ingesta'), strong: 'La rutina de novedades no está recogiendo', context: 'Mira el motivo y qué hacer en Ingesta' })
  if (!health)
    add('read-error', { icon: 'consent-unknown', tone: 'subtle', sr: SR.subtle, order: 2, strong: 'No se ha podido leer el estado del sistema', context: 'Recarga la página. Si sigue igual, puede ser un problema de permisos en Supabase.' })
  if (health) add('consent', jobNotice('cookie_consent', by('cookie_consent'), now))
  add('cleanup', cleanupNotice(stats, now))
  if (health) add('analytics', jobNotice('analytics', by('analytics'), now))
  // Array.sort is stable: ties keep the insertion order above.
  return rows.sort((a, b) => a.order - b.order).map(({ order: _order, ...row }) => row)
}
