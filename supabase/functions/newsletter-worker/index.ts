// F4.6 · Worker de guide.email_outbox (docs/security/F4.6-brevo-spec.md §2, §7; B1, B15, B17, B27, B29; L1, L2, L8, L10).
//
// verify_jwt = false. Puerta: `x-worker-secret` = NEWSLETTER_WORKER_SECRET (≥ 32; mismo valor que el secreto de Vault
// `newsletter_worker_secret`). Lo llaman guide.outbox_kick (cada INSERT en el outbox) y el barrido de pg_cron (5 min).
// Sin secretos ni configuración de Brevo responde 401/503 sin tomar trabajos.
//   confirm_email: svc_issue_confirm_token (único sitio con el token en claro) → POST /v3/smtp/email → done(messageId).
//   brevo_sync:    estado vigente → alta/cambio de lista en Brevo → done(contact_id) (L1 lo resuelve la RPC).
//   brevo_delete:  comprobación L2 → DELETE /v3/contacts/{id} (404 = done, L10).
// La respuesta (que pg_net guarda en net._http_response) solo lleva recuentos (L8).
import { brevo, codeFor, getContact, listIdFor } from '../_shared/newsletter/brevo.ts'
import { confirmEmail } from '../_shared/newsletter/email.ts'
import {
  empty,
  env,
  json,
  logEvent,
  safeEqual,
  serviceClient,
  siteUrl,
  strongSecret,
  testAllowlist,
} from '../_shared/newsletter/http.ts'

type Job = {
  id: number
  kind: 'confirm_email' | 'brevo_sync' | 'brevo_delete'
  subscriber_id: string | null
  brevo_contact_id: number | null
}
type Db = NonNullable<ReturnType<typeof serviceClient>>

const MAX_ROUNDS = 3
const BUDGET_MS = 45000

async function done(
  db: Db,
  job: Job,
  lock: string,
  result: 'done' | 'skipped',
  code: string | null,
  contactId: number | null,
  messageId: string | null,
) {
  const { error } = await db.rpc('svc_outbox_done', {
    p_outbox_id: job.id,
    p_lock_id: lock,
    p_result: result,
    p_code: code,
    p_brevo_contact_id: contactId,
    p_message_id: messageId,
  })
  return !error
}

async function fail(db: Db, job: Job, lock: string, code: string) {
  await db.rpc('svc_outbox_fail', { p_outbox_id: job.id, p_lock_id: lock, p_code: code })
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return empty(405)
  const secret = strongSecret('NEWSLETTER_WORKER_SECRET')
  if (!secret) return empty(503)
  if (!safeEqual(req.headers.get('x-worker-secret') ?? '', secret)) return empty(401)

  const apiKey = env('BREVO_API_KEY')
  const senderEmail = env('BREVO_SENDER_EMAIL')
  const senderName = env('BREVO_SENDER_NAME') ?? 'ChalkGuide'
  const replyTo = env('BREVO_REPLY_TO')
  const site = siteUrl()
  const listEs = listIdFor('es')
  const listEn = listIdFor('en')
  const db = serviceClient()
  if (!apiKey || !senderEmail || !site || !listEs || !listEn || !db) return empty(503)
  const allow = testAllowlist()

  const started = Date.now()
  const counts = { done: 0, skipped: 0, retry: 0, deferred: 0 }

  for (let round = 0; round < MAX_ROUNDS && Date.now() - started < BUDGET_MS; round++) {
    const lock = crypto.randomUUID()
    const { data: claimed, error } = await db.rpc('svc_outbox_claim', {
      p_limit: 20,
      p_lock_id: lock,
    })
    if (error) return json({ error: 'claim_failed', ...counts }, 500)
    const jobs = (claimed ?? []) as Job[]
    if (jobs.length === 0) break

    for (const job of jobs) {
      if (job.kind === 'confirm_email') {
        const { data: t, error: te } = await db.rpc('svc_issue_confirm_token', {
          p_outbox_id: job.id,
          p_lock_id: lock,
          p_allowlist: allow,
        })
        if (te) {
          await fail(db, job, lock, 'config')
          counts.retry++
          continue
        }
        const tok = t as { result: string; email?: string; locale?: string; token?: string }
        if (tok.result === 'skip') {
          counts.skipped++
          continue
        }
        if (tok.result === 'defer') {
          counts.deferred++
          continue
        }
        if (tok.result !== 'ok' || !tok.email || !tok.token) {
          await fail(db, job, lock, 'config')
          counts.retry++
          continue
        }
        const mail = confirmEmail(site, tok.locale === 'en' ? 'en' : 'es', tok.token)
        const r = await brevo<{ messageId?: string }>(apiKey, 'POST', '/smtp/email', {
          sender: { email: senderEmail, name: senderName },
          to: [{ email: tok.email }],
          ...(replyTo ? { replyTo: { email: replyTo } } : {}),
          subject: mail.subject,
          htmlContent: mail.html,
          textContent: mail.text,
          tags: ['cg-confirm'],
        })
        if (!r.ok) {
          await fail(db, job, lock, r.code === 'brevo_404' ? 'brevo_4xx' : r.code)
          counts.retry++
          continue
        }
        const mid = typeof r.data?.messageId === 'string' ? r.data.messageId : null
        // Sin messageId no se puede casar un bounce (L4); el email ya salió, así que se cierra con un id neutro.
        await done(
          db,
          job,
          lock,
          'done',
          null,
          null,
          mid && /^<?[A-Za-z0-9._%+=@-]{1,198}>?$/.test(mid) ? mid : '<unknown@brevo>',
        )
        counts.done++
        continue
      }

      const { data: tg, error: tge } = await db.rpc('svc_outbox_target', {
        p_outbox_id: job.id,
        p_lock_id: lock,
      })
      if (tge) {
        await fail(db, job, lock, 'config')
        counts.retry++
        continue
      }
      const target = tg as {
        status?: string | null
        email?: string | null
        locale?: string
        contact_id?: number
        stale?: boolean
      }

      if (job.kind === 'brevo_sync') {
        // B17: nunca da de alta una fila que ya no está active.
        if (target.status !== 'active' || !target.email) {
          await done(db, job, lock, 'skipped', 'stale_state', null, null)
          counts.skipped++
          continue
        }
        if (allow.length > 0 && !allow.includes(target.email.toLowerCase())) {
          await done(db, job, lock, 'skipped', 'not_allowed_test', null, null)
          counts.skipped++
          continue
        }
        const list = target.locale === 'en' ? listEn : listEs
        const other = target.locale === 'en' ? listEs : listEn
        // C1 (leona-lia): nunca se rehabilita en Brevo a quien Brevo tiene en lista negra o dado de baja de nuestras
        // listas (p. ej. un webhook de baja que no llegó). La fila baja a unsubscribed y el trabajo se cierra.
        const existing = await getContact(apiKey, target.email)
        if (!existing.ok && existing.status !== 404) {
          await fail(db, job, lock, existing.code === 'brevo_404' ? 'brevo_4xx' : existing.code)
          counts.retry++
          continue
        }
        if (
          existing.ok &&
          (existing.data?.emailBlacklisted === true ||
            (existing.data?.listUnsubscribed ?? []).some((l) => l === listEs || l === listEn))
        ) {
          await db.rpc('svc_outbox_sync_suppressed', { p_outbox_id: job.id, p_lock_id: lock })
          counts.skipped++
          continue
        }
        const created = await brevo<{ id?: number }>(apiKey, 'POST', '/contacts', {
          email: target.email,
          listIds: [list],
          updateEnabled: true,
        })
        if (!created.ok) {
          await fail(db, job, lock, created.code === 'brevo_404' ? 'brevo_4xx' : created.code)
          counts.retry++
          continue
        }
        let id = typeof created.data?.id === 'number' ? created.data.id : null
        if (id === null) {
          // 204: el contacto ya existía → se lee su id y se quita de la otra lista (cambio de idioma).
          const got = await getContact(apiKey, target.email)
          if (!got.ok || typeof got.data?.id !== 'number') {
            await fail(db, job, lock, got.ok ? 'brevo_4xx' : got.code)
            counts.retry++
            continue
          }
          id = got.data.id
          const upd = await brevo(apiKey, 'PUT', `/contacts/${id}?identifierType=contact_id`, {
            listIds: [list],
            unlinkListIds: [other],
          })
          if (!upd.ok) {
            await fail(db, job, lock, upd.code === 'brevo_404' ? 'brevo_4xx' : upd.code)
            counts.retry++
            continue
          }
        }
        await done(db, job, lock, 'done', null, id, null)
        counts.done++
        continue
      }

      // brevo_delete (L2: si una fila active usa ese contacto, no se borra)
      if (target.stale || typeof target.contact_id !== 'number') {
        await done(db, job, lock, 'skipped', 'stale_state', null, null)
        counts.skipped++
        continue
      }
      const del = await brevo(
        apiKey,
        'DELETE',
        `/contacts/${target.contact_id}?identifierType=contact_id`,
      )
      if (del.ok) {
        await done(db, job, lock, 'done', null, null, null)
        counts.done++
        continue
      }
      if (del.status === 404) {
        await done(db, job, lock, 'done', 'brevo_404', null, null)
        counts.done++
        continue
      }
      await fail(db, job, lock, codeFor(del.status) === 'brevo_404' ? 'brevo_4xx' : del.code)
      counts.retry++
    }
    if (jobs.length < 20) break
  }

  logEvent('newsletter_worker', counts)
  return json(counts)
})
