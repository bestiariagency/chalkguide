/**
 * Typographic poster for shoes without a photo (docs/design/site/pages/pies-de-gato-poster.html).
 * Pure helpers: one word per line (like "7 / NOV"), the widest line measured in em so the name
 * fills the tile without overflowing.
 */

/** One word per line; above 3 words the shortest contiguous pair is joined until only 3 remain. */
export function posterLines(model: string): string[] {
  const words = model.trim().split(/\s+/).filter(Boolean)
  while (words.length > 3) {
    let at = 0
    let min = Infinity
    for (let i = 0; i < words.length - 1; i++) {
      const length = words[i]!.length + words[i + 1]!.length
      if (length < min) {
        min = length
        at = i
      }
    }
    words.splice(at, 2, `${words[at]} ${words[at + 1]}`)
  }
  return words
}

/** Width of Archivo Expanded 700, in em per character (measured in browser). Tracking -.03em. */
const WIDTHS: Record<string, number> = {
  A: 0.92, B: 0.9, C: 0.94, D: 0.93, E: 0.87, F: 0.79, G: 1.01, H: 0.98, I: 0.36, J: 0.71,
  K: 0.93, L: 0.73, M: 1.13, N: 0.97, O: 1.02, P: 0.86, Q: 1.02, R: 0.93, S: 0.86, T: 0.83,
  U: 0.95, V: 0.88, W: 1.2, X: 0.92, Y: 0.88, Z: 0.84, '0': 0.77, '1': 0.68, '2': 0.77,
  '3': 0.77, '4': 0.75, '5': 0.77, '6': 0.77, '7': 0.7, '8': 0.79, '9': 0.77, '+': 0.73,
  '-': 0.42, '.': 0.33, ' ': 0.31,
}

function lineWidth(line: string): number {
  const clean = line.toUpperCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
  return [...clean].reduce((sum, char) => sum + (WIDTHS[char] ?? 0.92) - 0.03, 0)
}

export interface PosterLayout {
  lines: string[]
  /** Width in em of the widest line (`--n`). */
  n: number
  /** Two initials, for tiles under 120 px when the name is too wide to read. */
  mono: string
  /** n >= 7: under 120 px it becomes initials. */
  long: boolean
}

export function posterLayout(model: string): PosterLayout {
  const lines = posterLines(model)
  const n = Number(Math.max(0.1, ...lines.map(lineWidth)).toFixed(2))
  const mono = model
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((word) => word[0] ?? '')
    .join('')
    .toUpperCase()
  return { lines, n, mono, long: n >= 7 }
}
