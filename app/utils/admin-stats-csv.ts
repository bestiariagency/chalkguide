import { toCsv } from './csv'
import { GRAIN_QUERY } from './admin-stats-range'
import type { StatsData } from './admin-stats'

/** CSV of the current view (README §16.12): one row per period, counts only (no emails, no personal data). */
const COLUMNS = ['periodo_inicio', 'periodo_fin', 'parcial', 'altas', 'bajas', 'suscriptores_total', 'articulos_publicados', 'opiniones_visibles', 'opiniones_ocultas']

export function statsCsv(data: StatsData): string {
  return toCsv(
    COLUMNS,
    data.buckets.map((b) => ({
      periodo_inicio: b.start,
      periodo_fin: b.end,
      parcial: b.partial,
      altas: b.subsIn,
      bajas: b.subsOut,
      suscriptores_total: b.subsTotal,
      articulos_publicados: b.articles,
      opiniones_visibles: b.reviewsVisible,
      opiniones_ocultas: b.reviewsHidden,
    })),
  )
}

/** `estadisticas_2026-03-01_2026-06-15_semana.csv` */
export const statsCsvName = (data: StatsData) => `estadisticas_${data.from}_${data.to}_${GRAIN_QUERY[data.grain]}.csv`
