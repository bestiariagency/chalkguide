import type { Editor } from '@tiptap/vue-3'
import { applyBlock, filterBlocks, type BlockDef, type BlockKey, type DialogBlockKey } from '~/utils/article-blocks'

/**
 * `/` menu of the article body: it opens when the cursor sits at the end of a paragraph that holds
 * only `/` + a few letters, filters the blocks while typing and is driven from the keyboard
 * (↑ ↓ Intro Esc). Key handling runs in the capture phase of the editor element, so it wins over
 * ProseMirror only while the menu is open. `listboxId` / the active option are mirrored on the
 * editor element (`aria-controls`, `aria-activedescendant`).
 */
export function useSlashMenu(options: { editor: Ref<Editor | null>; tick: Ref<number>; onDialog: (key: DialogBlockKey) => void; exclude?: readonly BlockKey[] }) {
  const listboxId = `slash-${useId()}`
  const optionId = (key: string) => `${listboxId}-${key}`
  const query = ref('')
  const active = ref(0)
  const visible = ref(false)
  const position = ref<{ left: number; top?: number; bottom?: number }>({ left: 0 })
  /** Text of the paragraph where Esc was pressed: the menu stays closed until that text changes. */
  let dismissed: string | null = null

  const blocks = computed<BlockDef[]>(() => filterBlocks(query.value, options.exclude))
  const open = computed(() => visible.value)
  const activeId = computed(() => (open.value && blocks.value[active.value] ? optionId(blocks.value[active.value]!.key) : undefined))

  /** Paragraph text before the cursor when it looks like `/word`; `null` otherwise. */
  function slashText(editor: Editor): string | null {
    const { selection } = editor.state
    if (!selection.empty || !editor.isEditable) return null
    const { $from } = selection
    if ($from.parent.type.name !== 'paragraph' || $from.parentOffset !== $from.parent.content.size) return null
    const text = $from.parent.textContent
    return /^\/[\p{L}\d]{0,20}$/u.test(text) ? text : null
  }

  function place(editor: Editor) {
    const rect = editor.view.coordsAtPos(editor.state.selection.from)
    const below = window.innerHeight - rect.bottom
    position.value = {
      left: Math.max(8, Math.min(rect.left, window.innerWidth - 328)),
      ...(below < 300 && rect.top > below ? { bottom: window.innerHeight - rect.top + 6 } : { top: rect.bottom + 6 }),
    }
  }

  function sync() {
    const editor = options.editor.value
    const text = editor ? slashText(editor) : null
    if (!editor || text === null || text === dismissed) {
      if (text === null) dismissed = null
      visible.value = false
      return
    }
    const next = text.slice(1)
    if (next !== query.value || !visible.value) active.value = 0
    query.value = next
    visible.value = true
    place(editor)
  }
  watch(options.tick, sync)
  watch(visible, (value) => {
    const dom = options.editor.value?.view.dom
    if (!dom) return
    if (value) dom.setAttribute('aria-controls', listboxId)
    else {
      dom.removeAttribute('aria-controls')
      dom.removeAttribute('aria-activedescendant')
    }
  })
  watch(activeId, (id) => {
    const dom = options.editor.value?.view.dom
    if (id) dom?.setAttribute('aria-activedescendant', id)
    else dom?.removeAttribute('aria-activedescendant')
  })

  function choose(block: BlockDef) {
    const editor = options.editor.value
    if (!editor) return
    const { from } = editor.state.selection
    const range = { from: from - (query.value.length + 1), to: from }
    visible.value = false
    if (block.dialog) {
      editor.chain().focus().deleteRange(range).run()
      options.onDialog(block.key as DialogBlockKey)
    } else {
      applyBlock(editor.chain().focus().deleteRange(range), block.key as never).run()
    }
  }

  function onKeyDown(event: KeyboardEvent) {
    if (!open.value || event.isComposing) return
    const count = blocks.value.length
    const stop = () => {
      event.preventDefault()
      event.stopPropagation()
    }
    if (event.key === 'Escape') {
      stop()
      dismissed = `/${query.value}`
      visible.value = false
    } else if (event.key === 'ArrowDown' && count) {
      stop()
      active.value = (active.value + 1) % count
    } else if (event.key === 'ArrowUp' && count) {
      stop()
      active.value = (active.value - 1 + count) % count
    } else if ((event.key === 'Enter' || event.key === 'Tab') && blocks.value[active.value]) {
      stop()
      choose(blocks.value[active.value]!)
    }
  }
  const reposition = () => open.value && options.editor.value && place(options.editor.value)

  let dom: HTMLElement | null = null
  watch(options.editor, (editor) => {
    dom?.removeEventListener('keydown', onKeyDown, true)
    dom = editor?.view.dom ?? null
    dom?.addEventListener('keydown', onKeyDown, true)
  })
  onMounted(() => window.addEventListener('scroll', reposition, { capture: true, passive: true }))
  onBeforeUnmount(() => {
    dom?.removeEventListener('keydown', onKeyDown, true)
    window.removeEventListener('scroll', reposition, { capture: true })
  })

  return { listboxId, optionId, open, blocks, active, activeId, position, choose }
}
