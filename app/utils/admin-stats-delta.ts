import { fmtNum } from './admin-stats-format'

/** Comparison line of a KPI (README §16.11). The sign and the arrow carry the meaning, never only the colour. */
export interface StatsDelta {
  kind: 'none' | 'zero' | 'new' | 'same' | 'up' | 'down'
  /** Bold figure ("+92 %", "−1", "= 7"). */
  strong: string
  text: string
}

const LABEL = 'el periodo anterior'
const MINUS = '−'

/** Singular and plural of the noun after the figure: `['alta', 'altas']`. */
export type StatsNoun = readonly [one: string, other: string]

/** `noun` (optional) agrees with the bold figure. `prev` `null`: the previous period is out of the 24 months. */
export function statsDelta(cur: number, prev: number | null, noun?: StatsNoun): StatsDelta {
  const word = (count: number) => (noun ? `${count === 1 ? noun[0] : noun[1]} ` : '')
  const n = word(0)
  if (prev === null) return { kind: 'none', strong: '', text: 'Sin datos comparables' }
  if (!prev && !cur) return { kind: 'zero', strong: '', text: `0 ${n}también en ${LABEL}` }
  if (!prev) return { kind: 'new', strong: '', text: `0 ${n}en ${LABEL}` }
  const diff = cur - prev
  const percent = Math.round((diff / prev) * 100)
  const usePercent = prev >= 10
  const flat = usePercent ? percent === 0 : diff === 0
  if (flat && !usePercent) return { kind: 'same', strong: `= ${fmtNum(prev)}`, text: `${word(prev)}igual que en ${LABEL}` }
  const sign = diff > 0 ? '+' : MINUS
  const strong = usePercent
    ? Math.abs(percent) > 999
      ? diff > 0 ? '> +999 %' : `${MINUS}999 %`
      : flat ? '= 0 %' : `${sign}${fmtNum(Math.abs(percent))} %`
    : `${sign}${fmtNum(Math.abs(diff))}`
  return { kind: flat ? 'same' : diff > 0 ? 'up' : 'down', strong, text: `${usePercent ? n : word(Math.abs(diff))}frente a ${fmtNum(prev)} en ${LABEL}` }
}
