/**
 * `/api/content/*` checks (D64, F6.19 C2/C3/C4/C9). Runs the real routes against a local fixture:
 * a mock PostgREST (127.0.0.1) holds a malicious article, page and shoe review plus an unpublished
 * draft that it serves ONLY to requests carrying an `Authorization` header (as RLS would for an
 * admin session). The app is started with `nuxt dev` pointed at that mock. Expected:
 *   - hostile HTML (`<img onerror>`, `javascript:`, `<script>`, `data:` image) leaves sanitized;
 *   - a draft is 404 even when the caller sends an admin JWT and cookies (nothing is forwarded);
 *   - invalid slug / key / kind / locale / extra query give 400, unknown content gives 404;
 *   - no request from the app to the mock ever carries `Authorization` other than the publishable key.
 * Usage: `npm run check:content-api` (needs a free port, default 3999; `PORT=…` to change).
 * Exit code 1 when anything fails.
 */
import { spawn } from 'node:child_process'
import { createServer, type IncomingMessage } from 'node:http'

const PORT = Number(process.env.PORT ?? 3999)
const MOCK_PORT = PORT + 1
const KEY = 'sb_publishable_fixture'
const ADMIN_JWT = 'Bearer eyJhbGciOiJIUzI1NiJ9.admin-fixture.sig'

const HOSTILE =
  '<p>texto</p><img src="https://evil.example/x.png" onerror="alert(1)"><a href="javascript:alert(1)" onclick="x()">enlace</a>' +
  '<script>alert(1)</script><img src="data:image/svg+xml;base64,AAAA"><iframe src="https://evil.example"></iframe><h2 onmouseover="x()">Título</h2>'

const article = (slug: string) => ({
  id: 'a1', slug_es: slug, slug_en: null, title_es: 'Artículo', title_en: null, excerpt_es: null, excerpt_en: null,
  published_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z', is_featured: false, has_en: false,
  reading_minutes_es: 3, reading_minutes_en: null, category: null, cover: null, category_id: 'c1', body_html_es: HOSTILE,
  body_html_en: null, seo_title_es: null, seo_title_en: null, seo_description_es: null, seo_description_en: null,
  noindex: false, author: null,
})
const page = {
  key: 'about', slug_es: 'sobre-mi', slug_en: 'about', title_es: 'Sobre mí', title_en: 'About', body_html_es: HOSTILE,
  body_html_en: HOSTILE, has_en: true, seo_title_es: null, seo_title_en: null, seo_description_es: null,
  seo_description_en: null, noindex: false, og_media_id: null, revised_on: null,
}
const review = {
  headline_es: 'Titular', headline_en: null, body_html_es: HOSTILE, body_html_en: null, visit_date: null,
  visit_type: 'paid', disclosure_note_es: null, disclosure_note_en: null,
}

/** Requests the mock saw that carried a visitor credential: must stay 0 (C3). */
let leaked = 0

function mockRest(req: IncomingMessage): unknown[] {
  const url = new URL(req.url ?? '/', 'http://mock')
  const table = url.pathname.replace('/rest/v1/', '')
  const auth = req.headers.authorization
  // The supabase client sends the publishable key as Bearer too; anything else is a forwarded session.
  if (auth && auth !== `Bearer ${KEY}`) leaked++
  if (req.headers.cookie) leaked++
  const admin = !!auth && auth !== `Bearer ${KEY}` // what RLS would show an admin session: drafts
  const q = url.search
  if (table === 'articles') {
    if (q.includes('slug_es=eq.test-article')) return [article('test-article')]
    if (q.includes('slug_es=eq.draft-article')) return admin ? [article('draft-article')] : []
    return []
  }
  if (table === 'pages') return q.includes('key=eq.about') ? [page] : []
  if (table === 'items') {
    if (q.includes('slug=eq.test-shoe')) return [{ id: 'i1', has_en: false }]
    if (q.includes('slug=eq.draft-shoe')) return admin ? [{ id: 'i2', has_en: false }] : []
    return []
  }
  if (table === 'author_reviews') return [review]
  return []
}

const mock = createServer((req, res) => {
  res.setHeader('content-type', 'application/json')
  res.end(JSON.stringify(mockRest(req)))
})

let failed = 0
let total = 0
function check(name: string, ok: boolean, detail = '') {
  total++
  if (!ok) {
    failed++
    console.error(`FAIL ${name}${detail ? ` · ${detail}` : ''}`)
  }
}

async function get(path: string, headers: Record<string, string> = {}) {
  const res = await fetch(`http://127.0.0.1:${PORT}${path}`, { headers })
  const text = await res.text()
  return { status: res.status, text }
}

const clean = (text: string) =>
  !/onerror|onclick|onmouseover|javascript:|<script|<iframe|data:image|evil\.example/i.test(text) && text.includes('texto')

async function run() {
  const credentials = { authorization: ADMIN_JWT, cookie: 'sb-fixture-auth-token=admin-session' }

  const a = await get('/api/content/article/test-article', credentials)
  check('article: 200', a.status === 200, String(a.status))
  check('article: hostile HTML comes out sanitized', clean(a.text), a.text.slice(0, 300))
  check('article: h2 kept without handler', /<h2>Título<\/h2>/.test(JSON.parse(a.text).bodyHtml))

  const draft = await get('/api/content/article/draft-article', credentials)
  check('article draft: 404 even with admin JWT and cookies', draft.status === 404, String(draft.status))

  const p = await get('/api/content/page/about?locale=en', credentials)
  check('page: 200', p.status === 200, String(p.status))
  check('page: sanitized', clean(p.text))

  const s = await get('/api/content/item/shoe/test-shoe', credentials)
  check('item: 200', s.status === 200, String(s.status))
  check('item: review sanitized', clean(s.text), s.text.slice(0, 300))
  const sd = await get('/api/content/item/shoe/draft-shoe', credentials)
  check('item draft: 404 even with admin JWT and cookies', sd.status === 404, String(sd.status))

  const cases: [string, string, number][] = [
    ['article slug uppercase', '/api/content/article/Test-Article', 400],
    ['article slug dots', '/api/content/article/..%2Fetc', 400],
    ['article slug too long', `/api/content/article/${'a'.repeat(121)}`, 400],
    ['article locale', '/api/content/article/test-article?locale=fr', 400],
    ['article extra query', '/api/content/article/test-article?x=1', 400],
    ['article unknown', '/api/content/article/nope', 404],
    ['page key not listed', '/api/content/page/admins', 400],
    ['page unknown published', '/api/content/page/privacy', 404],
    ['item kind', '/api/content/item/event/test-shoe', 400],
    ['item slug', '/api/content/item/shoe/Bad_Slug', 400],
    ['item unknown', '/api/content/item/shoe/nope', 404],
  ]
  for (const [name, path, expected] of cases) {
    const r = await get(path)
    check(name, r.status === expected, `${r.status} ≠ ${expected}`)
  }
  const generic = await fetch(`http://127.0.0.1:${PORT}/api/content/sanitize`, { method: 'POST', body: '<p>x</p>' })
  check('no generic sanitize endpoint', generic.status === 404 || generic.status === 405, String(generic.status))

  check('nothing forwarded to Supabase (Authorization / cookies)', leaked === 0, `${leaked} requests`)
}

async function ready() {
  for (let i = 0; i < 120; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/api/content/page/about`)
      if (r.status === 200) return
    } catch {
      /* not up yet */
    }
    await new Promise((r) => setTimeout(r, 1000))
  }
  throw new Error('app did not start')
}

await new Promise<void>((resolve) => mock.listen(MOCK_PORT, '127.0.0.1', resolve))
const app = spawn('npx', ['nuxt', 'dev', '--port', String(PORT), '--host', '127.0.0.1'], {
  env: { ...process.env, NUXT_PUBLIC_SUPABASE_URL: `http://127.0.0.1:${MOCK_PORT}`, NUXT_PUBLIC_SUPABASE_KEY: KEY },
  stdio: 'ignore',
  detached: true,
})
try {
  await ready()
  await run()
} catch (error) {
  failed++
  console.error(error)
} finally {
  if (app.pid) process.kill(-app.pid, 'SIGTERM')
  mock.close()
}
console.log(failed ? `${failed}/${total} content-api checks FAILED` : `${total}/${total} content-api checks OK`)
process.exit(failed ? 1 : 0)
