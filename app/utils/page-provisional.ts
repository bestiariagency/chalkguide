import { Extension } from '@tiptap/core'
import { Plugin, PluginKey } from '@tiptap/pm/state'
import { Decoration, DecorationSet } from '@tiptap/pm/view'

/**
 * Provisional-text marks the seed and the drafts in docs/copy leave in the pages (F7.4): `[XAVI: …]`,
 * `[LEONA: …]` and `[PENDIENTE XAVI: …]` placeholders and the words "Texto provisional". They only warn
 * (amber), they never block a publication (D34).
 */
const MARKS = /\[(?:PENDIENTE )?XAVI:[^\]]*\]|\[LEONA:[^\]]*\]|Texto provisional/gi

/** Number of marks in a plain string (HTML is fine: tags do not match). */
export function countProvisional(text: string): number {
  return text.match(MARKS)?.length ?? 0
}

const key = new PluginKey('provisional-marks')

/** Editor-only extension: highlights the marks in `warn-soft` so the author sees what would be published as is. */
export const ProvisionalMarks = Extension.create({
  name: 'provisionalMarks',
  addProseMirrorPlugins() {
    return [
      new Plugin({
        key,
        props: {
          decorations(state) {
            const decorations: Decoration[] = []
            state.doc.descendants((node, pos) => {
              if (!node.isText || !node.text) return
              for (const match of node.text.matchAll(MARKS)) {
                const from = pos + (match.index ?? 0)
                decorations.push(Decoration.inline(from, from + match[0].length, { class: 'rounded-[3px] bg-adm-warn-soft px-0.5 text-adm-warn' }))
              }
            })
            return DecorationSet.create(state.doc, decorations)
          },
        },
      }),
    ]
  },
})
