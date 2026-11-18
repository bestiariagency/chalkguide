/** Longest query we keep from the URL or the field (untrusted input). */
export const MAX_QUERY_LENGTH = 80

const MARKS = /\p{M}/gu

/** One character → lowercase without diacritics ("À" → "a"). */
const foldChar = (char: string) => char.normalize('NFD').replace(MARKS, '').toLowerCase()

/** Client-side search folding: NFD, no diacritics, lowercase ("Gràcia" → "gracia"). */
export function normalizeText(text: string): string {
  return text.normalize('NFD').replace(MARKS, '').toLowerCase()
}

/** Words to look for: all of them must appear (AND). Empty query → no tokens. */
export function searchTokens(query: string): string[] {
  return [...new Set(normalizeText(query).split(/\s+/).filter(Boolean))]
}

/** True when every token appears in at least one of the fields (or there are no tokens). */
export function matchesTokens(fields: (string | null | undefined)[], tokens: string[]): boolean {
  if (!tokens.length) return true
  const haystack = normalizeText(fields.filter(Boolean).join(' · '))
  return tokens.every((token) => haystack.includes(token))
}

export interface TextPart {
  text: string
  hit: boolean
}

/**
 * Splits `text` into plain and matching parts, matching on the folded text but returning the
 * original characters (so "gracia" highlights "Gràcia"). Pure data: render it as text nodes.
 */
export function highlightParts(text: string, tokens: string[]): TextPart[] {
  if (!text || !tokens.length) return [{ text, hit: false }]

  let folded = ''
  // foldedToOriginal[i] = [start, end) in `text` of the character that produced folded[i].
  const foldedToOriginal: [number, number][] = []
  let offset = 0
  for (const char of text) {
    const next = foldChar(char)
    for (let i = 0; i < next.length; i++) foldedToOriginal.push([offset, offset + char.length])
    folded += next
    offset += char.length
  }

  const ranges: [number, number][] = []
  for (const token of tokens) {
    let from = folded.indexOf(token)
    while (from !== -1) {
      const start = foldedToOriginal[from]?.[0]
      const end = foldedToOriginal[from + token.length - 1]?.[1]
      if (start !== undefined && end !== undefined) ranges.push([start, end])
      from = folded.indexOf(token, from + token.length)
    }
  }
  if (!ranges.length) return [{ text, hit: false }]

  ranges.sort((a, b) => a[0] - b[0])
  const merged: [number, number][] = []
  for (const range of ranges) {
    const last = merged.at(-1)
    if (last && range[0] <= last[1]) last[1] = Math.max(last[1], range[1])
    else merged.push([...range])
  }

  const parts: TextPart[] = []
  let cursor = 0
  for (const [start, end] of merged) {
    if (start > cursor) parts.push({ text: text.slice(cursor, start), hit: false })
    parts.push({ text: text.slice(start, end), hit: true })
    cursor = end
  }
  if (cursor < text.length) parts.push({ text: text.slice(cursor), hit: false })
  return parts
}
