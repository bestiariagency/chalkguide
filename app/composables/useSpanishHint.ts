/** True when a link forced to Spanish (`locale="es"`) is rendered under /en, so it needs the "(in Spanish)" hint. */
export function useSpanishHint(forcedLocale: () => 'es' | 'en' | undefined) {
  const { locale } = useI18n()
  return computed(() => forcedLocale() === 'es' && locale.value === 'en')
}
