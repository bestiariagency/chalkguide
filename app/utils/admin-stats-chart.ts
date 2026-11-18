/** Geometry of the SVG charts (README §16.4): drawn at the real width, the axis text stays at 11 px. */
export const PAD_LEFT = 40
export const PAD_RIGHT = 12
const MIN_LABEL_GAP = 44

export interface ChartFrame {
  left: number
  right: number
  band: number
  bw: number
  cx: (i: number) => number
}

export function chartFrame(width: number, count: number): ChartFrame {
  const band = (width - PAD_LEFT - PAD_RIGHT) / Math.max(count, 1)
  return { left: PAD_LEFT, right: width - PAD_RIGHT, band, bw: Math.max(1, Math.min(32, band * 0.62)), cx: (i) => PAD_LEFT + band * (i + 0.5) }
}

export const indexAt = (x: number, f: ChartFrame, count: number) => Math.max(0, Math.min(count - 1, Math.floor((x - f.left) / f.band)))

/** x labels thin out to keep ≥ 44 px between them, counting from the last period (the current one always shows). */
export function labelIndexes(count: number, band: number): Set<number> {
  const step = Math.max(1, Math.ceil(MIN_LABEL_GAP / band))
  return new Set(Array.from({ length: count }, (_, i) => i).filter((i) => (count - 1 - i) % step === 0))
}

/** Smallest round ceiling whose half is a whole number (the middle mark of the y axis). */
export function niceCeil(value: number): number {
  if (value <= 2) return 2
  const p = 10 ** Math.floor(Math.log10(value))
  for (const m of [1, 2, 2.5, 4, 5, 10]) if (m * p >= value && ((m * p) / 2) % 1 === 0) return m * p
  return 10 * p
}

/** Whole-number steps only (the y marks are counts). */
function niceStep(range: number): number {
  const p = 10 ** Math.floor(Math.log10(Math.max(range, 1)))
  for (const m of [1, 2, 5, 10]) if (m * p >= range) return m * p
  return 10 * p
}

/** Three marks (low, middle, high). The line does not start at 0 when the total barely moves. */
export function lineScale(values: readonly number[]): { lo: number; hi: number; ticks: number[] } {
  const min = Math.min(...values)
  const max = Math.max(...values)
  let step = niceStep(Math.max(max - min, 4) / 2)
  while (Math.floor(min / step) * step + 2 * step < max) step = niceStep(step + 1)
  const lo = Math.floor(min / step) * step
  return { lo, hi: lo + 2 * step, ticks: [lo, lo + step, lo + 2 * step] }
}
