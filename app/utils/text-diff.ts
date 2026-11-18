/** Small diffs for the "Publicar cambios" summary: words in short texts, blocks in the body. */

export interface DiffPart {
  type: 'same' | 'add' | 'del'
  text: string
}

/** Longest-common-subsequence pairs `[indexInA, indexInB]` (quadratic; fine for article sizes). */
function lcs(a: readonly string[], b: readonly string[]): Array<[number, number]> {
  const rows = a.length + 1
  const cols = b.length + 1
  const table = Array.from({ length: rows }, () => new Uint16Array(cols))
  for (let i = a.length - 1; i >= 0; i--) {
    for (let j = b.length - 1; j >= 0; j--) {
      table[i]![j] = a[i] === b[j] ? table[i + 1]![j + 1]! + 1 : Math.max(table[i + 1]![j]!, table[i]![j + 1]!)
    }
  }
  const pairs: Array<[number, number]> = []
  let i = 0
  let j = 0
  while (i < a.length && j < b.length) {
    if (a[i] === b[j]) {
      pairs.push([i++, j++])
    } else if (table[i + 1]![j]! >= table[i]![j + 1]!) i++
    else j++
  }
  return pairs
}

function push(parts: DiffPart[], type: DiffPart['type'], text: string) {
  const last = parts[parts.length - 1]
  if (last?.type === type) last.text += text
  else parts.push({ type, text })
}

/** Word diff keeping whitespace, merged into runs. */
export function wordDiff(before: string, after: string): DiffPart[] {
  const tokens = (text: string) => text.match(/\s+|[^\s]+/g) ?? []
  const a = tokens(before)
  const b = tokens(after)
  const parts: DiffPart[] = []
  let i = 0
  let j = 0
  for (const [x, y] of [...lcs(a, b), [a.length, b.length] as [number, number]]) {
    while (i < x) push(parts, 'del', a[i++]!)
    while (j < y) push(parts, 'add', b[j++]!)
    if (x < a.length) push(parts, 'same', a[x]!)
    i = x + 1
    j = y + 1
  }
  return parts
}

export interface BlockChange {
  kind: 'added' | 'changed' | 'removed'
  before?: string
  after?: string
}

export interface BlockSummary {
  added: number
  changed: number
  removed: number
  changes: BlockChange[]
}

export interface Block {
  /** Full identity (text and formatting) to know whether it changed. */
  key: string
  /** Plain text to show. */
  text: string
}

/** Compares two lists of top-level blocks: within each gap, paired ones count as changed. */
export function blockDiff(before: readonly Block[], after: readonly Block[]): BlockSummary {
  const changes: BlockChange[] = []
  let i = 0
  let j = 0
  for (const [x, y] of [...lcs(before.map((b) => b.key), after.map((b) => b.key)), [before.length, after.length] as [number, number]]) {
    const old = before.slice(i, x)
    const next = after.slice(j, y)
    for (let k = 0; k < Math.max(old.length, next.length); k++) {
      const o = old[k]
      const n = next[k]
      if (o && n) changes.push({ kind: 'changed', before: o.text, after: n.text })
      else if (n) changes.push({ kind: 'added', after: n.text })
      else if (o) changes.push({ kind: 'removed', before: o.text })
    }
    i = x + 1
    j = y + 1
  }
  const count = (kind: BlockChange['kind']) => changes.filter((c) => c.kind === kind).length
  return { added: count('added'), changed: count('changed'), removed: count('removed'), changes }
}
