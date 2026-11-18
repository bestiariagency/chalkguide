import type { EditorState } from '@tiptap/pm/state'

/** Rows and columns of the table around the selection (0 x 0 outside a table). */
export function tableSize(state: EditorState): { rows: number; columns: number } {
  const { $from } = state.selection
  for (let depth = $from.depth; depth > 0; depth--) {
    const node = $from.node(depth)
    if (node.type.name === 'table') return { rows: node.childCount, columns: node.firstChild?.childCount ?? 0 }
  }
  return { rows: 0, columns: 0 }
}

/** True when the first row of the table around the selection is made of header cells. */
export function hasHeaderRow(state: EditorState): boolean {
  const { $from } = state.selection
  for (let depth = $from.depth; depth > 0; depth--) {
    const node = $from.node(depth)
    if (node.type.name === 'table') return node.firstChild?.firstChild?.type.name === 'tableHeader'
  }
  return false
}
