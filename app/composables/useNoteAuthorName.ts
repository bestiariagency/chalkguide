/**
 * Author name for the "Nota de {name}" label (`site_settings.author_name`). `null` when unset: the
 * label then falls back to a generic one. Shared by <UiProse> and the panel editor.
 */
export function useNoteAuthorName() {
  const { data: settings } = useSiteSettings()
  return computed(() => settings.value?.author?.name?.trim() || null)
}
