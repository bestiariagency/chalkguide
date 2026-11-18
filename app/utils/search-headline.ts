import type { TextPart } from './search'

const MATCH_START = '\u0002'
const MATCH_END = '\u0003'

/**
 * Splits a `guide.search_articles` headline into text parts. The DB sends plain text with the
 * matches between U+0002 and U+0003 (never HTML), so the result is rendered as text nodes and
 * <mark>: no `v-html`. Unbalanced or repeated marks degrade to plain text.
 */
export function headlineParts(headline: string): TextPart[] {
  const parts: TextPart[] = []
  let hit = false
  let buffer = ''
  const flush = () => {
    if (buffer) parts.push({ text: buffer, hit })
    buffer = ''
  }
  for (const char of headline) {
    if (char === MATCH_START || char === MATCH_END) {
      flush()
      hit = char === MATCH_START
    } else buffer += char
  }
  flush()
  return parts
}
