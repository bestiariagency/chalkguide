type Locale = 'es' | 'en'
type Seo = Record<string, string>

/**
 * Default meta descriptions of the fixed pages. The panel only loads the Spanish messages, so the
 * `seo.*` strings are read from the locale files on demand: the dynamic import keeps the whole
 * messages out of the editor bundle (each file becomes its own lazy chunk).
 */
const loaders: Record<Locale, () => Promise<{ default: { seo: Seo } }>> = {
  es: () => import('~~/i18n/locales/es.json'),
  en: () => import('~~/i18n/locales/en.json'),
}

export async function loadSeoDefaults(): Promise<Record<Locale, Seo>> {
  const [es, en] = await Promise.all([loaders.es(), loaders.en()])
  return { es: es.default.seo, en: en.default.seo }
}
