// 8.13 · Envío semanal por campañas de Brevo (docs/security/F4.6-brevo-spec.md §7.8; B22–B27; L3, L7, L8, L10;
// decisión 4 de Xavi: si no cabe, ES ese día y EN al día siguiente).
//
// verify_jwt = false. Puerta: `x-cron-secret` = NEWSLETTER_SEND_SECRET (≥ 32; mismo valor que el secreto de Vault
// `newsletter_send_secret`). Lo llama guide.run_newsletter_send (pg_cron */10) solo si hay una edición vencida.
// Por idioma: preflight N3 por conjunto (L3) → cupo (L7) → campaña con nombre determinista cg-<id>-<locale> → sendNow.
// La comparación de contactos se hace en memoria; nada de la lista de Brevo se guarda ni se registra.
import { brevo, type BrevoContact, listContacts, listIdFor } from '../_shared/newsletter/brevo.ts'
import { type Issue, newsletterHtml } from '../_shared/newsletter/email.ts'
import {
  empty,
  env,
  envInt,
  json,
  logEvent,
  safeEqual,
  serviceClient,
  siteUrl,
  strongSecret,
  testAllowlist,
} from '../_shared/newsletter/http.ts'

type Db = NonNullable<ReturnType<typeof serviceClient>>
type LocState = { id?: number | null; state?: string; count?: number }
type Claim = Issue & { result: string; state: Record<'es' | 'en', LocState>; sent_today: number }
type Audience = {
  open_sync: number
  failed_sync: number
  failed_deletes: number
  audience: Array<{ id: string; email: string; contact_id: number | null }>
}
type Campaign = { id: number; name?: string; status?: string }

const SENT_STATES = new Set(['sent', 'queued', 'in_process', 'archive'])

async function record(
  db: Db,
  id: string,
  lock: string,
  locale: 'es' | 'en',
  campaignId: number | null,
  state: string,
  count: number | null,
  err: string | null,
) {
  const { data, error } = await db.rpc('svc_newsletter_record', {
    p_id: id,
    p_lock_id: lock,
    p_locale: locale,
    p_campaign_id: campaignId,
    p_state: state,
    p_count: count,
    p_error: err,
  })
  return error ? null : ((data as { result?: string })?.result ?? null)
}

/** L7: mínimo entre los créditos de /v3/account (si los da) y el contador interno; menos la reserva de confirmaciones. */
async function budget(apiKey: string, sentToday: number): Promise<number | null> {
  const limit = envInt('BREVO_DAILY_LIMIT', 300)
  const reserve = envInt('BREVO_CONFIRM_RESERVE', 30)
  if (limit === null || reserve === null) return null
  let internal = limit - sentToday
  const acc = await brevo<{ plan?: Array<{ creditsType?: string; credits?: number }> }>(
    apiKey,
    'GET',
    '/account',
  )
  if (acc.ok) {
    const credits = (acc.data?.plan ?? [])
      .filter(
        (p) =>
          p.creditsType === 'sendLimit' &&
          typeof p.credits === 'number' &&
          Number.isFinite(p.credits),
      )
      .map((p) => p.credits as number)
    if (credits.length > 0) internal = Math.min(internal, ...credits)
  }
  return internal - reserve
}

async function findCampaign(apiKey: string, name: string): Promise<Campaign | null | 'error'> {
  const r = await brevo<{ campaigns?: Campaign[] }>(
    apiKey,
    'GET',
    '/emailCampaigns?type=classic&limit=100&offset=0&sort=desc',
  )
  if (!r.ok) return 'error'
  return (r.data?.campaigns ?? []).find((c) => c.name === name) ?? null
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return empty(405)
  const secret = strongSecret('NEWSLETTER_SEND_SECRET')
  if (!secret) return empty(503)
  if (!safeEqual(req.headers.get('x-cron-secret') ?? '', secret)) return empty(401)

  const apiKey = env('BREVO_API_KEY')
  const senderEmail = env('BREVO_SENDER_EMAIL')
  const senderName = env('BREVO_SENDER_NAME') ?? 'ChalkGuide'
  const replyTo = env('BREVO_REPLY_TO')
  const site = siteUrl()
  const lists = { es: listIdFor('es'), en: listIdFor('en') }
  const db = serviceClient()
  const dailyLimit = envInt('BREVO_DAILY_LIMIT', 300)
  const reserve = envInt('BREVO_CONFIRM_RESERVE', 30)
  if (
    !apiKey ||
    !senderEmail ||
    !site ||
    !lists.es ||
    !lists.en ||
    !db ||
    dailyLimit === null ||
    reserve === null
  )
    return empty(503)
  const allow = testAllowlist()

  const lock = crypto.randomUUID()
  const { data: claimData, error: claimErr } = await db.rpc('svc_newsletter_claim', {
    p_lock_id: lock,
  })
  if (claimErr) return json({ result: 'claim_failed' }, 500)
  if (!claimData) return json({ result: 'idle' })
  const issue = claimData as Claim
  if (issue.result !== 'claimed') return json({ result: issue.result })

  let left = await budget(apiKey, issue.sent_today ?? 0)
  if (left === null) {
    await record(db, issue.id, lock, 'es', null, 'retry', null, 'quota_unknown')
    return json({ result: 'quota_unknown' })
  }

  let outcome = 'recorded'
  for (const loc of ['es', 'en'] as const) {
    const st = issue.state?.[loc]?.state ?? 'pending'
    if (st === 'sent' || st === 'skipped_empty') continue
    const listId = lists[loc] as number

    // B24/L10: sin trabajos de sincronización abiertos ni borrados RGPD fallidos.
    const { data: audData, error: audErr } = await db.rpc('svc_newsletter_audience', {
      p_id: issue.id,
      p_lock_id: lock,
      p_locale: loc,
    })
    if (audErr || !audData) {
      outcome =
        (await record(db, issue.id, lock, loc, null, 'retry', null, 'brevo_error')) ?? 'error'
      break
    }
    const aud = audData as Audience
    if (aud.failed_deletes > 0) {
      outcome =
        (await record(db, issue.id, lock, loc, null, 'retry', null, 'delete_failed')) ?? 'error'
      break
    }
    if (aud.open_sync > 0 || aud.failed_sync > 0) {
      outcome =
        (await record(db, issue.id, lock, loc, null, 'retry', null, 'sync_mismatch')) ?? 'error'
      break
    }
    const audience = aud.audience ?? []
    const count = audience.length
    if (count === 0) {
      outcome = (await record(db, issue.id, lock, loc, null, 'skipped_empty', 0, null)) ?? 'error'
      continue
    }

    // B27: con lista de prueba, todos los destinatarios deben estar en ella.
    if (allow.length > 0 && audience.some((a) => !allow.includes(a.email.toLowerCase()))) {
      outcome =
        (await record(db, issue.id, lock, loc, null, 'failed', null, 'not_allowed_test')) ?? 'error'
      break
    }

    // L3: preflight por conjunto (ids y emails), con reconciliación a la baja antes de comparar.
    const contacts = await listContacts(apiKey, listId)
    if (!contacts) {
      outcome =
        (await record(db, issue.id, lock, loc, null, 'retry', null, 'brevo_error')) ?? 'error'
      break
    }
    let lowered = 0
    for (const c of contacts) {
      if (typeof c.id !== 'number' || typeof c.email !== 'string') continue
      if (c.emailBlacklisted === true || (c.listUnsubscribed ?? []).includes(listId)) {
        const { data } = await db.rpc('svc_apply_brevo_event', {
          p_event: 'unsubscribed',
          p_contact_id: c.id,
          p_email: c.email,
          p_event_at: null,
        })
        if (data === 'applied') lowered++
      }
    }
    const byId = new Map<number, BrevoContact>()
    for (const c of contacts) if (typeof c.id === 'number') byId.set(c.id, c)
    const dbIds = new Set<number>()
    const missing: string[] = []
    for (const a of audience) {
      const c = a.contact_id !== null ? byId.get(a.contact_id) : undefined
      if (a.contact_id !== null) dbIds.add(a.contact_id)
      if (!c || (c.email ?? '').toLowerCase() !== a.email.toLowerCase()) missing.push(a.id)
    }
    const extra = [...byId.keys()].filter((id) => !dbIds.has(id))
    if (lowered > 0 || missing.length > 0 || extra.length > 0) {
      await db.rpc('svc_outbox_resync', { p_subscriber_ids: missing, p_contact_ids: extra })
      outcome =
        (await record(db, issue.id, lock, loc, null, 'retry', null, 'sync_mismatch')) ?? 'error'
      logEvent('newsletter_send_preflight', {
        locale: loc,
        lowered,
        missing: missing.length,
        extra: extra.length,
      })
      break
    }

    // Cupo (decisión 4): si no cabe hoy pero cabe en un día limpio, mañana; si ni así, failed.
    if (count > left) {
      const fitsFreshDay = count <= dailyLimit - reserve
      outcome =
        (await record(
          db,
          issue.id,
          lock,
          loc,
          null,
          fitsFreshDay ? 'deferred_quota' : 'failed',
          null,
          fitsFreshDay ? null : 'quota_exceeded',
        )) ?? 'error'
      break
    }

    // B22: campaña con nombre determinista; si ya existe (lock recuperado), se consulta antes de crear o enviar.
    const name = `cg-${issue.id}-${loc}`
    let campaign: Campaign | null
    const known = issue.state?.[loc]?.id
    if (typeof known === 'number' && known > 0) {
      const r = await brevo<Campaign>(apiKey, 'GET', `/emailCampaigns/${known}`)
      if (!r.ok) {
        outcome =
          (await record(db, issue.id, lock, loc, null, 'retry', null, 'brevo_error')) ?? 'error'
        break
      }
      campaign = { id: known, status: r.data?.status }
    } else {
      const f = await findCampaign(apiKey, name)
      if (f === 'error') {
        outcome =
          (await record(db, issue.id, lock, loc, null, 'retry', null, 'brevo_error')) ?? 'error'
        break
      }
      campaign = f
    }
    if (campaign && SENT_STATES.has(campaign.status ?? '')) {
      outcome = (await record(db, issue.id, lock, loc, campaign.id, 'sent', count, null)) ?? 'error'
      left -= count
      continue
    }
    if (!campaign) {
      const { subject, preview, html } = newsletterHtml(site, issue, loc)
      const c = await brevo<{ id?: number }>(apiKey, 'POST', '/emailCampaigns', {
        name,
        subject,
        ...(preview ? { previewText: preview } : {}),
        sender: { name: senderName, email: senderEmail },
        ...(replyTo ? { replyTo } : {}),
        htmlContent: html,
        recipients: { listIds: [listId] },
        inlineImageActivation: false,
        mirrorActive: false,
      })
      if (!c.ok || typeof c.data?.id !== 'number') {
        outcome =
          (await record(db, issue.id, lock, loc, null, 'retry', null, 'brevo_error')) ?? 'error'
        break
      }
      campaign = { id: c.data.id, status: 'draft' }
      if ((await record(db, issue.id, lock, loc, campaign.id, 'created', null, null)) === null) {
        outcome = 'error'
        break
      }
    }
    // C3 (leona-lia): sin trabajos de sincronización abiertos justo antes de enviar (cierra la ventana del preflight).
    const { data: again, error: againErr } = await db.rpc('svc_newsletter_audience', {
      p_id: issue.id,
      p_lock_id: lock,
      p_locale: loc,
    })
    const a2 = again as Audience | null
    if (
      againErr ||
      !a2 ||
      a2.open_sync > 0 ||
      a2.failed_sync > 0 ||
      a2.failed_deletes > 0 ||
      (a2.audience ?? []).length !== count
    ) {
      outcome =
        (await record(db, issue.id, lock, loc, campaign.id, 'retry', null, 'sync_mismatch')) ??
        'error'
      break
    }
    const sent = await brevo(apiKey, 'POST', `/emailCampaigns/${campaign.id}/sendNow`)
    if (!sent.ok) {
      outcome =
        (await record(db, issue.id, lock, loc, campaign.id, 'retry', null, 'brevo_error')) ??
        'error'
      break
    }
    outcome = (await record(db, issue.id, lock, loc, campaign.id, 'sent', count, null)) ?? 'error'
    left -= count
  }

  // Si la pasada acabó sin estado terminal (p. ej. ES enviado y EN ya aplazado), se suelta el lock.
  if (outcome === 'recorded')
    await db.rpc('svc_newsletter_release', { p_id: issue.id, p_lock_id: lock })
  logEvent('newsletter_send', { result: outcome })
  return json({ result: outcome })
})
