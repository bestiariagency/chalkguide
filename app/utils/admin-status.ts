export type AdminStatusKind =
  | 'draft'
  | 'scheduled'
  | 'published'
  | 'revised'
  | 'hidden'
  | 'new'
  | 'visible'
  | 'pending'
  | 'active'
  | 'unconfirmed'
  | 'unsubscribed'
  | 'bounced'

interface StatusDef {
  label: string
  /** Tailwind classes (tokens `adm-st-*`); hidden uses a dashed outline instead of a fill. */
  tone: string
  /** `dot` (default) or the eye-off icon of "hidden". */
  icon?: 'eye-off'
}

const TONES = {
  draft: 'bg-adm-st-draft-bg text-adm-st-draft',
  sched: 'bg-adm-st-sched-bg text-adm-st-sched',
  pub: 'bg-adm-st-pub-bg text-adm-st-pub',
  hidden: 'bg-transparent text-adm-st-hidden outline-1 -outline-offset-1 outline-dashed outline-adm-st-hidden-line',
  acc: 'bg-adm-acc-soft text-adm-acc',
  neutral: 'bg-adm-subtle text-adm-meta',
  danger: 'bg-adm-danger-soft text-adm-danger',
} as const

/** Status badges of the design system (docs/design/admin/design-system.html#estados). */
export const ADMIN_STATUS: Record<AdminStatusKind, StatusDef> = {
  draft: { label: 'Borrador', tone: TONES.draft },
  scheduled: { label: 'Programado', tone: TONES.sched },
  published: { label: 'Publicado', tone: TONES.pub },
  revised: { label: 'Publicado', tone: TONES.pub },
  hidden: { label: 'Oculto', tone: TONES.hidden, icon: 'eye-off' },
  new: { label: 'Nueva', tone: TONES.acc },
  visible: { label: 'Visible', tone: TONES.pub },
  pending: { label: 'Pendiente', tone: TONES.sched },
  active: { label: 'Activo', tone: TONES.pub },
  unconfirmed: { label: 'Sin confirmar', tone: TONES.sched },
  unsubscribed: { label: 'Baja', tone: TONES.neutral },
  bounced: { label: 'Rebotado', tone: TONES.danger },
}

export function changesLabel(count: number): string {
  return `${count} ${count === 1 ? 'cambio' : 'cambios'}`
}
