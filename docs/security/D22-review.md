# Revisión de seguridad D22 · dinamismo, nota de talla, color dominante, orígenes de newsletter y Edge Function de fotos dummy (leona-lia, 2026-10-08)

## A) Migraciones `20261008180508_guide_gym_dynamism_shoe_size_note_media_color` y `20261008181105_guide_subscribers_article_sources`: **APROBADO**

- CHECKs en catálogo: `gyms_setting_dynamism_range` (1–5); notas de talla (1–140, `_en` exige `_es`, vacías si no `owned_by_author`); `media_dominant_color_hex` (`^#[0-9a-f]{6}$`, bloquea inyección CSS); `consent_source` con `article_mid`/`article_end`.
- `subscribe_newsletter`: DEFINER, `search_path=''`, sin EXECUTE para PUBLIC; rechaza `admin_import` y valores fuera de lista desde anon.
- `guide_rls_leaks.sql`: ALL RLS TESTS PASSED (incluidos casos D22); sin restos. RLS en todas las tablas de `guide`. Advisors sin novedades. `public` sin tocar.

## B) Edge Function temporal `seed-dummy-media`: **APROBADO CON CONDICIONES**, `verify_jwt: false` + token

`verify_jwt: true` con la anon key no aporta seguridad (es pública); el control real es `x-seed-token`.
SSRF cerrado (URLs fijas, `redirect: 'error'`, origen/tipo/tamaño comprobados); la service role no sale en
respuestas; sin CORS; sobrescritura limitada a 9 rutas fijas `d0d0d0d0-000a-…`; dependencias fijadas.

Condiciones obligatorias:
1. Token CSPRNG ≥ 256 bits, solo en cabecera HTTPS; nunca en URL, repo, `.env`, PLAN ni logs.
2. Comprobar antes de desplegar que el prefijo `d0d0d0d0-000a-` está vacío en el bucket `media` y en `guide.media`.
3. Versión exacta de supabase-js.
4. Ventana mínima: desplegar, invocar una vez y redesplegar un stub que solo responde 410 (sin supabase-js, sin `Deno.env`, sin token). Xavi la borra desde el dashboard; queda pendiente en `PLAN.md` hasta entonces.
5. Verificar con `list_edge_functions` que la versión activa es el stub y que en `media` solo están esas 9 rutas.
