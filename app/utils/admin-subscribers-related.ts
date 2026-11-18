import type { Database } from '~/types/database.types'

/**
 * Related-products consent in the panel (D66, docs/design/admin/README.md §18). Independent of the newsletter:
 * `related_status` and the `related_*` columns never change the newsletter state. Pure labels and rules.
 */
export type RelatedStatus = Database['guide']['Enums']['related_consent_status']
export type ConsentPurpose = 'newsletter' | 'related_products'

export interface SubscriberRelated {
  status: RelatedStatus
  consentAt: string | null
  source: string | null
  version: number | null
  confirmedAt: string | null
  withdrawnAt: string | null
  withdrawSource: string | null
}

export const RELATED_LABEL: Record<RelatedStatus, string> = { none: 'Sin dar', pending: 'Pendiente', granted: 'Dado', withdrawn: 'Retirado' }

/** `afines=dado,pendiente` in the URL; the value of each filter option is its slug. */
export const RELATED_FILTERS: readonly { value: RelatedStatus; slug: string; label: string }[] = [
  { value: 'granted', slug: 'dado', label: 'Dado' },
  { value: 'pending', slug: 'pendiente', label: 'Pendiente' },
  { value: 'withdrawn', slug: 'retirado', label: 'Retirado' },
  { value: 'none', slug: 'sin-dar', label: 'Sin dar' },
]
export const relatedFromSlug = (slug: string): RelatedStatus | undefined => RELATED_FILTERS.find((f) => f.slug === slug)?.value
export const relatedSlug = (status: RelatedStatus): string => RELATED_FILTERS.find((f) => f.value === status)?.slug ?? status

/** Only `granted` and `pending` can be withdrawn (`admin_withdraw_related`: 22023 otherwise). */
export const canWithdrawRelated = (s: { related: Pick<SubscriberRelated, 'status'> }) => s.related.status === 'granted' || s.related.status === 'pending'

export const RELATED_ORIGINS: Record<string, string> = { preferences: 'Preferencias', chalk_waitlist: 'Lista de espera de Chalk app' }
export const RELATED_VIAS: Record<string, string> = { preferences: 'Desde sus preferencias' }

export const WITHDRAW_REASONS = [
  { value: 'request', label: 'Me lo pidió (email, mensaje o en persona)' },
  { value: 'wrong', label: 'Email erróneo o de prueba' },
  { value: 'abuse', label: 'Lo marcó otra persona, no el titular del email' },
  { value: 'other', label: 'Otro' },
] as const

export const emptyRelated = (): SubscriberRelated => ({ status: 'none', consentAt: null, source: null, version: null, confirmedAt: null, withdrawnAt: null, withdrawSource: null })
