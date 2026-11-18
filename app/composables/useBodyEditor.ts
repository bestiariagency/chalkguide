import { Editor } from '@tiptap/vue-3'
import type { Extensions } from '@tiptap/core'
import { editorProse } from '~/utils/editor-classes'
import { articleExtensions, type ArticleBody } from '~/utils/article-editor'

/**
 * One Tiptap instance for an article body. It reports `{ json, html }` on every change (the HTML is
 * sanitised later, when saving). `tick` changes with each transaction so toolbars re-read
 * `editor.isActive(...)`, which is not reactive by itself.
 */
export function useBodyEditor(options: {
  body: () => ArticleBody
  placeholder: string
  locale: 'es' | 'en'
  editable: () => boolean
  label: string
  /** Legal pages: text, headings, lists and links only. */
  textOnly?: boolean
  /** Editor-only extensions (e.g. highlighting of provisional marks). */
  extra?: Extensions
  onChange: (body: ArticleBody) => void
}) {
  const editor = shallowRef<Editor | null>(null)
  const tick = ref(0)

  onMounted(() => {
    const instance = new Editor({
      extensions: articleExtensions(options.placeholder, options.locale, { textOnly: options.textOnly, extra: options.extra }),
      content: options.body().json,
      editable: options.editable(),
      editorProps: {
        attributes: {
          role: 'textbox',
          'aria-multiline': 'true',
          'aria-label': options.label,
          class: editorProse,
        },
      },
      onUpdate: ({ editor: e }) => options.onChange({ json: e.getJSON(), html: e.getHTML() }),
      onTransaction: () => tick.value++,
    })
    editor.value = instance
  })

  watch(options.editable, (value) => editor.value?.setEditable(value))
  onBeforeUnmount(() => editor.value?.destroy())

  /** Replace the whole document (e.g. "copy the Spanish text") without echoing an update. */
  function replace(body: ArticleBody) {
    editor.value?.commands.setContent(body.json, { emitUpdate: false })
    options.onChange({ json: editor.value?.getJSON() ?? body.json, html: editor.value?.getHTML() ?? body.html })
  }

  return { editor, tick, replace }
}
