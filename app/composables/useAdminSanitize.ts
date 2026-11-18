import type { SafeHtml } from '~~/shared/lib/sanitize/safe-html'

/**
 * Panel-only access to the article sanitizer (D64, F6.19 C1/C7). The module is big (`sanitize-html`),
 * so it is loaded on demand with `import()` and only from panel code: public chunks never contain it.
 * `clean` is synchronous (the patch builders are), so await `loadAdminSanitizer()` (the editors'
 * loaders and every save `run()` do) before the first call; before that it throws instead of letting
 * unsanitized HTML through.
 */
type Sanitize = (html: string, options?: { supabaseUrl?: string }) => SafeHtml

let loading: Promise<Sanitize> | null = null
let loaded: Sanitize | null = null

export function loadAdminSanitizer(): Promise<Sanitize> {
  loading ??= import('~~/shared/lib/sanitize/sanitize-article-html').then((m) => (loaded = m.sanitizeArticleHtml))
  return loading
}

export function useAdminSanitize() {
  const supabaseUrl = String(useRuntimeConfig().public.supabase?.url ?? '')
  if (import.meta.client) void loadAdminSanitizer()
  const clean = (html: string): SafeHtml => {
    if (!loaded) throw new Error('Sanitizer not loaded yet')
    return loaded(html, { supabaseUrl })
  }
  return { clean, whenReady: loadAdminSanitizer }
}
