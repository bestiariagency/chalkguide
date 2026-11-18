import type { InjectionKey } from 'vue'
import type { ItemForm } from '~/utils/item-fields'
import type { ItemSpec } from '~/utils/item-spec'

/** What the editor shell shares with the category panels (gyms, resolers) rendered inside it. */
export interface ItemEditorContext<F extends ItemForm = ItemForm> {
  id: string
  editor: ReturnType<typeof useItemEditor<F>>
  spec: ItemSpec<F>
  /** Opens the media picker for the cover, the share image or the gallery. */
  pick: (what: 'cover' | 'og' | 'gallery') => void
}

const KEY: InjectionKey<ItemEditorContext> = Symbol('item-editor')

export const provideItemEditor = (context: ItemEditorContext) => provide(KEY, context)

/** The editor the panels belong to; `F` is the form of the category the caller renders. */
export function useItemEditorContext<F extends ItemForm>(): ItemEditorContext<F> {
  const context = inject(KEY)
  if (!context) throw new Error('useItemEditorContext must be used inside <AdminItemsEditor>')
  return context as unknown as ItemEditorContext<F>
}
