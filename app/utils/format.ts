/** Prices in EUR without decimals when whole ("59 €", "€59" in English). */
export function formatEur(value: number | null, locale: string): string | null {
  if (value === null) return null
  return new Intl.NumberFormat(locale, {
    style: 'currency',
    currency: 'EUR',
    maximumFractionDigits: Number.isInteger(value) ? 0 : 2,
  }).format(value)
}

export function formatEurRange(min: number | null, max: number | null, locale: string) {
  if (min === null && max === null) return null
  if (min === null || max === null || min === max) return formatEur(min ?? max, locale)
  const fmt = new Intl.NumberFormat(locale, { maximumFractionDigits: 0 })
  return locale.startsWith('en')
    ? `€${fmt.format(min)}–${fmt.format(max)}`
    : `${fmt.format(min)}–${fmt.format(max)} €`
}

/** One decimal, locale-aware ("4.5" / "4,5"): scores, indices, rubber thickness. `decimals: 0` for whole user ratings. */
export function formatScore(value: number | null, locale: string, decimals = 1): string | null {
  if (value === null) return null
  return new Intl.NumberFormat(locale, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  }).format(value)
}
