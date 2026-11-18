// F6.11b · Limpieza diaria de las fotos de opiniones (D31/D32).
//
// Desplegada con verify_jwt = false: la única puerta es la cabecera `x-cleanup-secret`, comparada en tiempo constante
// con REVIEW_PHOTOS_CLEANUP_SECRET (≥ 32 caracteres; sin él responde 401 y no hace nada). La llama a diario el job
// de pg_cron `guide-review-photos-cleanup` (guide.run_review_photos_cleanup), que lee el mismo secreto de Vault.
// 1. guide.review_photos_cleanup_collect (solo service_role) purga las fotos rechazadas hace más de 30 días y
//    devuelve los objetos que sobran: subidas sin fila (> 60 min), originales de fotos aprobadas, copias públicas
//    sin fila (> 60 min) y los originales de las rechazadas purgadas.
// 2. Los borra por la API de Storage (nunca por SQL). Lo que falle vuelve a salir en la pasada siguiente.
// No registra rutas ni datos personales: solo recuentos.
//
// Secretos: SUPABASE_URL y SUPABASE_SERVICE_ROLE_KEY los inyecta Supabase; REVIEW_PHOTOS_CLEANUP_SECRET lo crea Xavi
// (Edge Functions → Secrets), con el mismo valor que el secreto de Vault `review_photos_cleanup_secret`.
import { createClient } from 'npm:@supabase/supabase-js@2'

const BUCKETS = new Set(['review-photo-uploads', 'review-photos'])
const BATCH = 500
const MAX_ROUNDS = 5
const REMOVE_CHUNK = 100

type Candidate = { bucket_id: string; storage_path: string; kind: string }

function safeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a)
  const eb = new TextEncoder().encode(b)
  if (ea.length !== eb.length) return false
  let diff = 0
  for (let i = 0; i < ea.length; i++) diff |= (ea[i] ?? 0) ^ (eb[i] ?? 0)
  return diff === 0
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  const secret = Deno.env.get('REVIEW_PHOTOS_CLEANUP_SECRET') ?? ''
  const given = req.headers.get('x-cleanup-secret') ?? ''
  if (secret.length < 32 || !safeEqual(given, secret)) return json({ error: 'unauthorized' }, 401)

  const url = Deno.env.get('SUPABASE_URL')
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !key) return json({ error: 'misconfigured' }, 500)

  const db = createClient(url, key, { auth: { persistSession: false }, db: { schema: 'guide' } })

  const removed: Record<string, number> = {}
  let failed = 0

  for (let round = 0; round < MAX_ROUNDS; round++) {
    const { data, error } = await db.rpc('review_photos_cleanup_collect', { p_limit: BATCH })
    if (error) return json({ error: 'collect_failed', removed, failed }, 500)
    const rows = (data ?? []) as Candidate[]
    if (rows.length === 0) break

    const byBucket = new Map<string, string[]>()
    for (const r of rows) {
      if (!BUCKETS.has(r.bucket_id)) continue
      const list = byBucket.get(r.bucket_id) ?? []
      list.push(r.storage_path)
      byBucket.set(r.bucket_id, list)
      removed[r.kind] = (removed[r.kind] ?? 0) + 1
    }

    for (const [bucket, paths] of byBucket) {
      for (let i = 0; i < paths.length; i += REMOVE_CHUNK) {
        const chunk = paths.slice(i, i + REMOVE_CHUNK)
        const { error: rmError } = await db.storage.from(bucket).remove(chunk)
        if (rmError) failed += chunk.length
      }
    }

    // Si algo falla, no insistir en esta ejecución: saldría otra vez en la ronda siguiente.
    if (failed > 0 || rows.length < BATCH) break
  }

  console.log(JSON.stringify({ event: 'review_photos_cleanup', removed, failed }))
  return json({ removed, failed })
})
