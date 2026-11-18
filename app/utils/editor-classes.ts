/** Typography of the article body inside the editor (Tailwind arbitrary variants on the Tiptap root). */
export const editorProse = [
  'min-h-64 text-[17px] leading-[1.7] text-adm-fg outline-none',
  '[&_p]:my-3 [&_h2]:mt-8 [&_h2]:mb-2 [&_h2]:text-2xl [&_h2]:leading-8 [&_h2]:font-semibold [&_h2]:tracking-tight',
  '[&_h3]:mt-6 [&_h3]:mb-2 [&_h3]:text-xl [&_h3]:leading-7 [&_h3]:font-semibold',
  '[&_a]:text-adm-acc [&_a]:underline [&_a]:underline-offset-2',
  '[&_ul]:my-3 [&_ul]:list-disc [&_ul]:pl-6 [&_ol]:my-3 [&_ol]:list-decimal [&_ol]:pl-6',
  '[&_blockquote]:my-4 [&_blockquote]:border-l-[3px] [&_blockquote]:border-adm-line-strong [&_blockquote]:pl-4 [&_blockquote]:text-adm-meta',
  '[&_img]:my-5 [&_img]:h-auto [&_img]:max-w-full [&_img]:rounded-md [&_img.ProseMirror-selectednode]:outline-2 [&_img.ProseMirror-selectednode]:outline-adm-acc',
  '[&_table]:my-5 [&_table]:w-full [&_table]:border-collapse [&_th]:border [&_th]:border-adm-line-strong [&_th]:bg-adm-subtle [&_th]:px-2.5 [&_th]:py-1.5 [&_th]:text-left [&_th]:text-sm [&_th]:font-medium',
  '[&_td]:border [&_td]:border-adm-line [&_td]:px-2.5 [&_td]:py-1.5 [&_td]:text-sm [&_td>p]:!my-0 [&_th>p]:!my-0 [&_.selectedCell]:bg-adm-acc/10',
  /* CSS fallback not needed: placeholder text comes from Tiptap's data-placeholder via attr() */
  '[&_p.is-editor-empty:first-child]:before:pointer-events-none [&_p.is-editor-empty:first-child]:before:float-left [&_p.is-editor-empty:first-child]:before:h-0',
  '[&_p.is-editor-empty:first-child]:before:text-adm-muted [&_p.is-editor-empty:first-child]:before:content-[attr(data-placeholder)]',
].join(' ')

/** Violet 3 px bar at the left of a field or block with unpublished changes (D23). */
export const changedBar = (on: boolean) =>
  on ? 'relative before:absolute before:inset-y-0 before:-left-3 before:w-[3px] before:rounded-full before:bg-adm-st-rev' : ''
