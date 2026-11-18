import { countOf, type ByCategory, type DashboardStats } from './admin-dashboard'
import { GYM_INFO, RESOLER_INFO, SHOE_INFO } from './item-spec'

/** "Pendiente" of Inicio v2 (README §14.2): three groups, from most to least urgent; groups and rows without work are dropped. */
export type PendingIcon = 'reviews' | 'photos' | 'events' | 'news' | 'ingest' | 'changes' | 'imported' | 'drafts' | 'stale' | 'alt' | 'pages' | 'cleanup'
export type PendingTone = 'acc' | 'rev' | 'subtle' | 'warn' | 'danger'

export interface PendingRow {
  key: string
  icon: PendingIcon
  tone: PendingTone
  /** Destination of the inbox; a row without it is a notice that does not open anything. */
  to?: string
  /** Line 1: count + noun. */
  strong: string
  /** Line 2: context. */
  context: string
  /** Deadline notice (only the events row, when the first one is within 7 days). */
  deadline?: string
  /** Remedy shown on demand (notice rows without a destination). */
  help?: string
}

export interface PendingGroup {
  key: 'moderate' | 'publish' | 'review'
  label: string
  rows: PendingRow[]
}

export interface PendingInput {
  stats: DashboardStats
  newReviews: number
  /** Unpublished-changes drafts by kind. */
  changes: { articles: number; pages: number; items: number }
  provisionalPages: number
  /** Instant used to judge how old the cleanup check is (default: now). */
  now?: number
  /** Day key (`YYYY-MM-DD`, Madrid). */
  today: string
  /** News drafts and the health of the agent (`admin_news_summary`); absent when it could not be read. */
  news?: { pending: number; warnings: number; ingestFailing: boolean } | null
}

const CATEGORIES = [
  { key: 'gym', info: GYM_INFO },
  { key: 'resoler', info: RESOLER_INFO },
  { key: 'shoe', info: SHOE_INFO },
] as const

const join = (parts: (string | false | null | undefined)[]) => parts.filter(Boolean).join(' · ')

/** «12 rocódromos, 3 pies de gato» of the categories that have any. */
export function categoryBreakdown(by: ByCategory | null): string {
  if (!by) return ''
  return CATEGORIES.filter(({ key }) => by[key] > 0)
    .map(({ key, info }) => countOf(by[key], info.noun, info.nouns))
    .join(', ')
}

/** Listing route of the category with the most items (gyms when there is no breakdown or it is a tie at 0). */
export function topCategoryRoute(by: ByCategory | null): string {
  if (!by) return GYM_INFO.route
  return [...CATEGORIES].sort((a, b) => by[b.key] - by[a.key])[0]!.info.route
}

/** «El primero, mañana» for the first event to approve when it falls in the next 7 days; `undefined` otherwise. */
export function deadlineNotice(nextAt: string | null, today: string): string | undefined {
  if (!nextAt) return undefined
  const key = dayKey(nextAt)
  const days = Math.round((new Date(`${key}T12:00:00Z`).getTime() - new Date(`${today}T12:00:00Z`).getTime()) / 86_400_000)
  if (days < 0 || days > 7) return undefined
  if (days === 0) return 'El primero, hoy'
  if (days === 1) return 'El primero, mañana'
  return `El primero, ${weekdayDay(key)}`
}

function changesRow(changes: PendingInput['changes']): PendingRow | null {
  const total = changes.articles + changes.pages + changes.items
  if (!total) return null
  const parts = [
    changes.articles && countOf(changes.articles, 'artículo', 'artículos'),
    changes.items && countOf(changes.items, 'ficha', 'fichas'),
    changes.pages && countOf(changes.pages, 'página', 'páginas'),
  ]
  // Mixed or articles: the articles list shows them; only fichas or only pages open their own listing.
  const to = changes.articles || (changes.items && changes.pages)
    ? `${adminPath('articulos')}#cambios`
    : changes.items
      ? `${adminPath(GYM_INFO.route)}?estado=cambios`
      : adminPath('paginas')
  return { key: 'changes', icon: 'changes', tone: 'rev', to, strong: `${fmtInt(total)} con cambios sin publicar`, context: parts.filter(Boolean).join(', ') }
}

function moderateRows({ stats, newReviews, today, news }: PendingInput): PendingRow[] {
  const rows: PendingRow[] = []
  if (news?.ingestFailing)
    rows.push({
      key: 'ingest',
      icon: 'ingest',
      tone: 'danger',
      to: adminPath('ingesta'),
      strong: 'La rutina de novedades no está recogiendo',
      context: 'Mira el motivo y qué hacer en Ingesta',
    })
  if (news?.pending)
    rows.push({
      key: 'news',
      icon: 'news',
      tone: 'acc',
      to: `${adminPath('noticias')}?vista=revisar`,
      strong: countOf(news.pending, 'noticia', 'noticias'),
      context: join(['del agente por revisar', news.warnings ? `${news.warnings} con ${news.warnings === 1 ? 'aviso' : 'avisos'}` : '']),
    })
  if (newReviews)
    rows.push({
      key: 'reviews',
      icon: 'reviews',
      tone: 'acc',
      to: adminPath('opiniones'),
      strong: countOf(newReviews, 'opinión nueva', 'opiniones nuevas'),
      context: join([stats.userReviewsLowSince ? `${fmtInt(stats.userReviewsLowSince)} con nota baja` : '', 'desde tu última visita']),
    })
  if (stats.reviewPhotosPending)
    rows.push({
      key: 'photos',
      icon: 'photos',
      tone: 'acc',
      to: `${adminPath('opiniones')}?vista=photos`,
      strong: countOf(stats.reviewPhotosPending, 'foto de lectores', 'fotos de lectores'),
      context: 'por revisar',
    })
  if (stats.eventsDrafts)
    rows.push({
      key: 'events',
      icon: 'events',
      tone: 'acc',
      to: `${adminPath('agenda')}?vista=revisar`,
      strong: countOf(stats.eventsDrafts, 'evento', 'eventos'),
      context: join([
        'del agente por aprobar',
        stats.eventsDraftsDuplicates ? countOf(stats.eventsDraftsDuplicates, 'posible duplicado', 'posibles duplicados') : '',
      ]),
      deadline: deadlineNotice(stats.eventsDraftsNextAt, today),
    })
  return rows
}

function publishRows(input: PendingInput): PendingRow[] {
  const { stats } = input
  const rows: PendingRow[] = []
  const changes = changesRow(input.changes)
  if (changes) rows.push(changes)
  if (stats.itemsImportedUnpublished)
    rows.push({
      key: 'imported',
      icon: 'imported',
      tone: 'subtle',
      to: `${adminPath(topCategoryRoute(stats.itemsImportedByCategory))}?estado=sin-publicar`,
      strong: countOf(stats.itemsImportedUnpublished, 'ficha importada', 'fichas importadas'),
      context: join(['sin publicar', categoryBreakdown(stats.itemsImportedByCategory)]),
    })
  if (stats.articles.draft)
    rows.push({
      key: 'drafts',
      icon: 'drafts',
      tone: 'subtle',
      to: `${adminPath('articulos')}?estado=borrador`,
      strong: countOf(stats.articles.draft, 'borrador', 'borradores'),
      context: 'de artículo',
    })
  return rows
}

const CLEANUP_MAX_AGE_MS = 48 * 3_600_000

const cleanupCheckedMs = (stats: DashboardStats) => (stats.cleanupCheckedAt ? Date.parse(stats.cleanupCheckedAt) : NaN)

/** Remedy of the cleanup notice (the row opens nothing: the fix lives outside the panel). */
const CLEANUP_HELP = 'Comprueba que la limpieza sigue programada y que su secreto coincide en Edge Function secrets y en Vault.'

/** The nightly cleanup of reader photos is not confirmed: failed status, never checked or check older than 48 h. */
function cleanupNeedsAttention(stats: DashboardStats, now: number): boolean {
  const checked = cleanupCheckedMs(stats)
  return stats.cleanupLastStatus !== 200 || !Number.isFinite(checked) || now - checked > CLEANUP_MAX_AGE_MS
}

/** Copy of the cleanup row: confirmed failure, never checked or stale check (only the first one is a known failure). */
function cleanupCopy(stats: DashboardStats, now: number): Pick<PendingRow, 'strong' | 'context' | 'tone'> {
  const checked = cleanupCheckedMs(stats)
  if (!Number.isFinite(checked))
    return {
      tone: 'warn',
      strong: 'Limpieza nocturna de fotos nunca comprobada',
      context: 'No se sabe si se borran las fotos rechazadas o caducadas',
    }
  if (now - checked > CLEANUP_MAX_AGE_MS)
    return {
      tone: 'warn',
      strong: 'Limpieza nocturna de fotos sin comprobar hace más de 48 h',
      context: 'No se sabe si se borran las fotos rechazadas o caducadas',
    }
  return {
    tone: 'danger',
    strong: 'Ha fallado la limpieza nocturna de fotos',
    context: 'Las fotos rechazadas o caducadas pueden no borrarse',
  }
}

function reviewRows({ stats, provisionalPages, now = Date.now() }: PendingInput): PendingRow[] {
  const rows: PendingRow[] = []
  if (cleanupNeedsAttention(stats, now))
    rows.push({
      key: 'cleanup',
      icon: 'cleanup',
      help: CLEANUP_HELP,
      ...cleanupCopy(stats, now),
    })
  if (stats.itemsStale)
    rows.push({
      key: 'stale',
      icon: 'stale',
      tone: 'warn',
      to: `${adminPath(topCategoryRoute(stats.itemsStaleByCategory))}?estado=sin-verificar`,
      strong: countOf(stats.itemsStale, 'ficha', 'fichas'),
      context: join(['sin verificar hace más de 6 meses', categoryBreakdown(stats.itemsStaleByCategory)]),
    })
  if (stats.mediaWithoutAlt)
    rows.push({
      key: 'alt',
      icon: 'alt',
      tone: 'warn',
      to: `${adminPath('medios')}?filtro=sin-alt`,
      strong: countOf(stats.mediaWithoutAlt, 'foto', 'fotos'),
      context: join(['sin texto alternativo', stats.mediaWithoutAltInUse ? `${fmtInt(stats.mediaWithoutAltInUse)} en contenido publicado` : '']),
    })
  if (provisionalPages)
    rows.push({
      key: 'pages',
      icon: 'pages',
      tone: 'warn',
      to: adminPath('paginas'),
      strong: countOf(provisionalPages, 'página', 'páginas'),
      context: 'con texto provisional',
    })
  return rows
}

export function buildPending(input: PendingInput): PendingGroup[] {
  const groups: PendingGroup[] = [
    { key: 'moderate', label: 'Moderar', rows: moderateRows(input) },
    { key: 'publish', label: 'Publicar', rows: publishRows(input) },
    { key: 'review', label: 'Revisar', rows: reviewRows(input) },
  ]
  return groups.filter((g) => g.rows.length)
}
