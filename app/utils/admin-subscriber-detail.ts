import { reasonShort, sourceLabel, viaLabel, type SubscriberDetail, type SubscriberEvent } from '~/utils/admin-subscribers'
import { fullDateTime } from '~/utils/admin-madrid'
import { RELATED_LABEL } from '~/utils/admin-subscribers-related'

/** Ficha of a subscriber (F6.14): history lines, plain-text proof and the messages of the two writes. */
export function actorLabel(actor: string | null, event: string): string {
  if (actor === 'admin') return 'Tú'
  if (actor === 'service') return 'Sistema'
  // F4.6: unsubscriptions, bounces and spam complaints reported by the email provider's webhook.
  if (actor === 'brevo' || actor?.startsWith('brevo:')) return 'Proveedor de email'
  return actor === 'user' && event === 'subscribe' ? 'La persona, con sesión iniciada' : 'La persona'
}

export interface HistoryLine {
  key: string
  tone: 'ok' | 'off' | 'none'
  text: string
  when: string
  who: string
  page: string | null
  /** D66: shown with the «Afines» tag; one single timeline for both purposes. */
  related: boolean
}

/** Text of an event of the related-products consent (README §18.3). */
function relatedText(e: SubscriberEvent): { text: string; tone: HistoryLine['tone'] } {
  if (e.event === 'subscribe') {
    const base = e.source === 'preferences' ? 'Dio los avisos afines (desde Preferencias)' : e.source === 'chalk_waitlist' ? 'Marcó la casilla de afines (lista de espera de Chalk app)' : 'Marcó la casilla de afines'
    return { text: e.version && e.source !== 'preferences' ? `${base} · texto v${e.version}` : base, tone: 'none' }
  }
  if (e.event === 'confirm') return { text: 'Dio los avisos afines (al confirmar el email)', tone: 'ok' }
  if (e.event === 'unsubscribe') {
    const reason = reasonShort(e.reason)
    return { text: ['Retiró los avisos afines', e.source ? viaLabel(e.source) : '', reason ? `«${reason}»` : ''].filter(Boolean).join(' · '), tone: 'off' }
  }
  if (e.event === 'expire') return { text: `Se descartó (${e.source === 'timeout' ? 'caducó sin confirmar' : 'nueva alta sin la casilla'})`, tone: 'off' }
  return { text: e.event, tone: 'none' }
}

/** Newest first, as the RPC returns them. A second `subscribe` is a comeback ("Volvió a suscribirse"). */
export function historyLines(events: readonly SubscriberEvent[]): HistoryLine[] {
  const subscribes = events.filter((e) => e.event === 'subscribe' && e.purpose !== 'related_products').length
  let seen = subscribes
  return events.map((e, index) => {
    if (e.purpose === 'related_products') {
      const { text, tone } = relatedText(e)
      return { key: `${e.at}-r-${e.event}-${index}`, tone, text, when: fullDateTime(e.at), who: actorLabel(e.actor, e.event), page: e.page, related: true }
    }
    const via = e.source && e.event === 'unsubscribe' ? viaLabel(e.source) : ''
    let text = e.event
    let tone: HistoryLine['tone'] = 'none'
    if (e.event === 'subscribe') {
      seen -= 1
      const parts = [seen > 0 ? 'Volvió a suscribirse' : 'Se suscribió', e.source ? sourceLabel(e.source) : '', e.version ? `texto v${e.version}` : '', e.locale ? e.locale.toUpperCase() : '']
      text = parts.filter(Boolean).join(' · ')
    } else if (e.event === 'confirm') {
      text = 'Confirmó el email (doble opt-in)'
      tone = 'ok'
    } else if (e.event === 'unsubscribe') {
      const reason = reasonShort(e.reason)
      text = ['Se dio de baja', via, reason ? `«${reason}»` : ''].filter(Boolean).join(' · ')
      tone = 'off'
    } else if (e.event === 'bounce') {
      text = 'Rebotó'
      tone = 'off'
    } else if (e.event === 'complaint') {
      text = 'Marcó el email como spam'
      tone = 'off'
    } else if (e.event === 'confirm_sent') {
      text = 'Email de confirmación enviado'
    } else if (e.event === 'expire') {
      text = 'Caducó sin confirmar (7 días)'
      tone = 'off'
    }
    return { key: `${e.at}-${e.event}-${index}`, tone, text, when: fullDateTime(e.at), who: actorLabel(e.actor, e.event), page: e.page, related: false }
  })
}

/** Plain-text proof (to answer the person or the AEPD). */
export function proofText(d: SubscriberDetail): string {
  const s = d.subscriber
  const t = d.texts[s.version]
  const text = t ? ((s.locale === 'en' && t.en) || t.es) : null
  const doi = s.confirmedAt ? `confirmado el ${fullDateTime(s.confirmedAt)}` : 'sin confirmar'
  const unsub = s.unsubscribedAt ? `${fullDateTime(s.unsubscribedAt)} · ${viaLabel(s.unsubscribeSource)}${s.unsubscribeReason ? ` · «${reasonShort(s.unsubscribeReason)}»` : ''}` : '—'
  const r = s.related
  const relatedText = d.relatedTexts[r.version ?? 0]
  const relatedQuote = relatedText ? ((s.locale === 'en' && relatedText.en) || relatedText.es) : null
  const related =
    r.status === 'none'
      ? ['Avisos de Chalk app y productos afines: no los ha dado']
      : [
          `Avisos de Chalk app y productos afines: ${RELATED_LABEL[r.status].toLowerCase()}`,
          `  Consentimiento: ${r.consentAt ? fullDateTime(r.consentAt) : '—'} · ${r.source ? sourceLabel(r.source) : '—'}`,
          `  Texto aceptado: versión ${r.version ?? '—'}${relatedQuote ? `: «${relatedQuote}»` : ': texto no conservado'}`,
          r.confirmedAt ? `  Vigente desde: ${fullDateTime(r.confirmedAt)}` : '  Sin confirmar',
          ...(r.withdrawnAt ? [`  Retirada: ${fullDateTime(r.withdrawnAt)} · ${viaLabel(r.withdrawSource)}`] : []),
        ]
  return [
    `Suscriptor: ${s.email}`,
    `Consentimiento: ${fullDateTime(s.consentAt)} (hora de Barcelona)`,
    `Origen: ${sourceLabel(s.source)}${s.consentPage ? ` · ${s.consentPage}` : ''}`,
    `Texto aceptado: versión ${s.version} (${s.locale.toUpperCase()})${text ? `: «${text}»` : ': texto no conservado'}`,
    `Doble opt-in: ${doi}`,
    `Baja: ${unsub}`,
    ...related,
  ].join('\n')
}

// Errors ---------------------------------------------------------------------------------------------
export interface SubscriberFailure {
  message: string
  /** The list is stale: re-read it. */
  reload?: boolean
  /** The typed email did not match (field error). */
  mismatch?: boolean
}

export function subscriberError(error: unknown, action: 'unsubscribe' | 'erase' | 'read' | 'withdraw'): SubscriberFailure {
  const e = error as { code?: string; message?: string } | null
  const code = e?.code
  const message = e?.message ?? ''
  if (action === 'withdraw' && (code === '22023' || code === 'P0002')) return { message: 'Ya no tenía afines vigentes. Se ha recargado la ficha.', reload: true }
  if (code === 'P0002') {
    return action === 'unsubscribe'
      ? { message: 'No se ha dado de baja a nadie: alguno de los suscriptores ya no existe (quizá se suprimió) y la operación es de todo o nada. Se ha recargado la lista.', reload: true }
      : { message: 'Este suscriptor ya no existe (quizá ya se suprimió). Se ha recargado la lista.', reload: true }
  }
  if (code === '22023' && /invalid subscriber state/.test(message)) {
    return { message: 'No se ha dado de baja a nadie: alguno de los suscriptores ya está de baja o ha caducado y la operación es de todo o nada. Se ha recargado la lista.', reload: true }
  }
  if (code === '22023' && /email confirmation mismatch/.test(message)) return { message: 'El email escrito no coincide con el del suscriptor.', mismatch: true }
  if (code === '22023') return { message: 'La petición no es válida. Recarga la página e inténtalo de nuevo.' }
  if (code === '42501') return { message: 'No tienes permiso para hacer esto. Vuelve a entrar en el panel.' }
  if (/fetch|network|failed to load/i.test(message)) return { message: 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.' }
  return { message: 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.' }
}
