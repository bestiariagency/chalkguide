// F4.6 §8 · HTML propio (no plantillas de Brevo). Todo campo de BD se escapa (texto plano; nunca markdown ni HTML).
// Enlaces solo https al SITE_URL o a la fuente https de una noticia publicada. Sin imágenes remotas ni píxeles.
// Textos provisionales: los revisa loro-lola (es/en) antes del lanzamiento.

export function esc(s: unknown): string {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

/** Solo https (o el propio SITE_URL en local); cualquier otra cosa se descarta. */
export function safeHref(url: unknown, site: string): string | null {
  if (typeof url !== 'string' || url.length > 2000) return null
  try {
    const u = new URL(url)
    if (u.protocol === 'https:' && !u.username && !u.password) return u.toString()
    if (url.startsWith(site + '/') || url === site) return url
    return null
  } catch {
    return null
  }
}

const WRAP_OPEN =
  '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">' +
  '<meta name="referrer" content="no-referrer"></head>' +
  '<body style="margin:0;padding:0;background:#f6f4ef;font-family:Helvetica,Arial,sans-serif;color:#1d1d1b">' +
  '<table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center" style="padding:24px 12px">' +
  '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:8px">' +
  '<tr><td style="padding:28px 28px 8px;font-size:20px;font-weight:bold">ChalkGuide</td></tr>'
const WRAP_CLOSE = '</table></td></tr></table></body></html>'

const CONFIRM_COPY = {
  es: {
    subject: 'Confirma tu suscripción a ChalkGuide',
    lead: 'Soy Xavi, de ChalkGuide. Has pedido recibir la newsletter semanal (agenda de escalada en Barcelona, noticias con su fuente y el último artículo) y por eso recibes este email. Para activarla, entra abajo: te llevará a una página de ChalkGuide donde la confirmas con un clic más.',
    button: 'Confirmar suscripción',
    expires: 'El enlace caduca en 48 horas.',
    ignore:
      'Si no lo has pedido tú, ignora este email: no te daremos de alta y no recibirás nada más. Puedes responder a este correo si tienes dudas; me llega a mí.',
  },
  en: {
    subject: 'Confirm your ChalkGuide subscription',
    lead: 'I’m Xavi, from ChalkGuide. You asked to get the weekly newsletter (climbing agenda in Barcelona, news with their source and the latest article), which is why you are getting this email. To switch it on, head below: it takes you to a ChalkGuide page where you confirm with one more click.',
    button: 'Confirm subscription',
    expires: 'The link expires in 48 hours.',
    ignore:
      'If you did not ask for this, just ignore this email: you will not be subscribed and you will not hear from us again. You can reply to this email if you have any questions; it comes straight to me.',
  },
} as const

/** Ruta de la página de confirmación (contrato con el front: botón POST, nunca confirma por GET). */
export function confirmUrl(site: string, locale: string, token: string): string {
  const path = locale === 'en' ? '/en/newsletter/confirm' : '/newsletter/confirmar'
  return `${site}${path}?t=${token}`
}

export function confirmEmail(
  site: string,
  locale: string,
  token: string,
): { subject: string; html: string; text: string } {
  const c = locale === 'en' ? CONFIRM_COPY.en : CONFIRM_COPY.es
  const url = confirmUrl(site, locale, token)
  const html =
    WRAP_OPEN +
    `<tr><td style="padding:8px 28px;font-size:16px;line-height:1.5">${esc(c.lead)}</td></tr>` +
    `<tr><td style="padding:16px 28px"><a href="${esc(url)}" style="display:inline-block;background:#1d1d1b;color:#ffffff;` +
    `text-decoration:none;padding:12px 20px;border-radius:6px;font-weight:bold">${esc(c.button)}</a></td></tr>` +
    `<tr><td style="padding:8px 28px;font-size:14px;color:#555">${esc(c.expires)}</td></tr>` +
    `<tr><td style="padding:8px 28px 28px;font-size:14px;color:#555">${esc(c.ignore)}</td></tr>` +
    WRAP_CLOSE
  const text = `${c.lead}\n\n${url}\n\n${c.expires}\n${c.ignore}\n`
  return { subject: c.subject, html, text }
}

export type IssueItem = {
  kind: 'article' | 'news' | 'event'
  title_es?: string | null
  title_en?: string | null
  blurb_es?: string | null
  blurb_en?: string | null
  excerpt_es?: string | null
  excerpt_en?: string | null
  path_es?: string | null
  path_en?: string | null
  source_name?: string | null
  source_url?: string | null
  starts_at?: string | null
  location?: string | null
}

export type Issue = {
  id: string
  has_en: boolean
  subject_es: string
  subject_en: string | null
  preheader_es: string | null
  preheader_en: string | null
  intro_es: string
  intro_en: string | null
  items: IssueItem[]
}

const NL_COPY = {
  es: {
    read: 'Leer',
    source: 'Fuente',
    footer:
      'Recibes este email porque te suscribiste a la newsletter de ChalkGuide. No medimos aperturas ni clics. Puedes responder a este correo: me llega a mí.',
    unsub: 'Darme de baja',
    onlyEs: '',
  },
  en: {
    read: 'Read',
    source: 'Source',
    footer:
      'You are getting this email because you subscribed to the ChalkGuide newsletter. We do not track opens or clicks. You can reply to this email: it comes straight to me.',
    unsub: 'Unsubscribe',
    onlyEs: 'This week’s issue is in Spanish only.',
  },
} as const

/** C2 (leona-lia): en campañas, además, sin llaves: Brevo interpretaría `{{ … }}` o `{% … %}` del contenido. */
function escc(s: unknown): string {
  return esc(s).replace(/\{/g, '&#123;').replace(/\}/g, '&#125;')
}

/** Asunto y previewText de campaña: texto plano sin llaves (no admiten entidades HTML). */
function noBraces(s: string): string {
  return s.replace(/[{}]/g, '')
}

/** LSSI art. 21: identificación del remitente en cada carta. TODO(Xavi): añadir titular cuando estén los textos legales. */
function senderIdentity(): string {
  return (
    (Deno.env.get('NEWSLETTER_SENDER_IDENTITY') ?? '').trim() || 'ChalkGuide · hola@chalkguide.es'
  )
}

function paragraphs(s: string): string {
  return escc(s)
    .split(/\n{2,}/)
    .map((p) => `<p style="margin:0 0 12px">${p.replace(/\n/g, '<br>')}</p>`)
    .join('')
}

/** HTML de una campaña. EN sin versión inglesa (D78): contenido ES con el aviso «This week only in Spanish». */
export function newsletterHtml(
  site: string,
  issue: Issue,
  locale: 'es' | 'en',
): { subject: string; preview: string; html: string } {
  const en = locale === 'en' && issue.has_en
  const c = locale === 'en' ? NL_COPY.en : NL_COPY.es
  const subject = noBraces((en ? issue.subject_en : issue.subject_es) ?? issue.subject_es)
  const preview = noBraces((en ? issue.preheader_en : issue.preheader_es) ?? '').slice(0, 110)
  const intro = (en ? issue.intro_en : issue.intro_es) ?? issue.intro_es
  let body = ''
  if (locale === 'en' && !issue.has_en) {
    body += `<tr><td style="padding:8px 28px;font-size:14px;color:#555"><em>${escc(c.onlyEs)}</em></td></tr>`
  }
  body += `<tr><td style="padding:8px 28px;font-size:16px;line-height:1.5">${paragraphs(intro)}</td></tr>`
  for (const it of issue.items) {
    const title = (en ? it.title_en : null) ?? it.title_es ?? ''
    const blurb =
      (en ? it.blurb_en : it.blurb_es) ??
      (en ? it.excerpt_en : it.excerpt_es) ??
      it.blurb_es ??
      it.excerpt_es ??
      ''
    const path = (locale === 'en' ? it.path_en : null) ?? it.path_es ?? '/'
    const href = safeHref(site + path, site)
    let row = `<tr><td style="padding:12px 28px;border-top:1px solid #eee;font-size:15px;line-height:1.5">`
    row += href
      ? `<a href="${escc(href)}" style="color:#1d1d1b;font-weight:bold">${escc(title)}</a>`
      : `<strong>${escc(title)}</strong>`
    if (it.kind === 'event' && it.starts_at) {
      const d = new Date(it.starts_at)
      if (!Number.isNaN(d.getTime())) {
        const when = d.toLocaleDateString(locale === 'en' ? 'en-GB' : 'es-ES', {
          timeZone: 'Europe/Madrid',
          day: 'numeric',
          month: 'long',
        })
        row += `<br><span style="color:#555">${escc(when)}${it.location ? ' · ' + escc(it.location) : ''}</span>`
      }
    }
    if (blurb) row += `<br>${escc(blurb)}`
    if (it.kind === 'news') {
      const src = safeHref(it.source_url, site)
      if (src) {
        row += `<br><span style="font-size:13px;color:#555">${escc(c.source)}: <a href="${escc(src)}" rel="nofollow noopener noreferrer ugc" style="color:#555">${escc(it.source_name ?? new URL(src).hostname)}</a></span>`
      }
    }
    row += '</td></tr>'
    body += row
  }
  body +=
    `<tr><td style="padding:20px 28px 28px;font-size:12px;color:#777;border-top:1px solid #eee">${escc(c.footer)} ` +
    `<a href="{{ unsubscribe }}" style="color:#777">${escc(c.unsub)}</a><br>${escc(senderIdentity())}</td></tr>`
  const html = WRAP_OPEN + body + WRAP_CLOSE
  return { subject, preview, html }
}
