# Orquestación · ChalkGuide

Estándar de cómo SúperXavi (CLAUDE.md) planifica y delega, y de cómo caballo-bojac arma planes.

## Flujo

1. **Entender**: objetivo, alcance, criterio de "hecho". Si hay ambigüedad de producto, preguntar a Xavi.
2. **Planificar**: tarea pequeña → plan mental. Tarea grande o ambigua → caballo-bojac.
3. **Ejecutar**: delegar paso a paso respetando dependencias (backend antes que frontend que lo consume).
   Pasos independientes pueden ir en paralelo.
4. **Revisar**: leona-lia / buho-pixel / loro-lola según la matriz.
5. **Cerrar**: zorro-foxter + build/lint/typecheck en verde. Resumen corto a Xavi.

## Matriz de delegación

| Si la tarea toca… | Ejecuta | Revisa |
| --- | --- | --- |
| `app/pages`, `app/components`, `app/composables`, `app/layouts`, `app/services` | coneja-lucky | buho-pixel (si es UI pública) |
| `i18n/locales/*.json`, artículos, newsletter, prompts editoriales | loro-lola | lince-max si hay peso SEO |
| Schema `guide`, migraciones, RLS, RPC, Edge Functions, tipos generados | jabali-javi | **leona-lia** |
| Specs de diseño, tokens de `@theme` (propuesta) | buho-pixel | Xavi |
| `useSeoMeta`, JSON-LD, sitemap, robots, analítica | lince-max | — |
| `netlify.toml`, `nuxt.config.ts` (runtime/routeRules/nitro), env, secretos, cron | osset-op | leona-lia si hay secretos |
| Cierre de cualquier feature | zorro-foxter | — |

## Cómo se arma un plan (caballo-bojac)

1. Objetivo y alcance + supuestos/ambigüedades a confirmar.
2. Pasos pequeños y verificables, en orden, con dependencias.
3. Cada paso con su agente según la matriz.
4. Recordatorios: leona-lia si toca BD; buho-pixel si cambia UI pública; loro-lola si hay textos;
   zorro-foxter al final.
5. Criterios de "hecho" comprobables.

## Plan de ejecución

El orden de trabajo, el estado de cada tarea y las decisiones abiertas viven en `docs/PLAN.md`
(F0–F9). SúperXavi lo mantiene al día. Para tareas de diseño: propuesta → ping-pong con Xavi →
aprobación → implementación.

## Fases del producto (para priorizar)

- **Fase 1 (0–6 meses)**: rocódromos, resoladores, comparador de pies de gato, artículos, login con
  Google, opiniones y captura de newsletter.
- **Fase 2 (6–12)**: agente de novedades, agenda, noticias y newsletter semanal (F8 v2, adelantada por Xavi; ver `docs/PLAN.md` §F8 y D70–D76).
- **Fase 3 (12+)**: "Encuentra compañero" (Chalk app) en cada ficha y lista de espera por rocódromo.

No adelantes trabajo de fases futuras salvo que Xavi lo pida; sí deja el modelo preparado para crecer.

## Agente de novedades (F8 v2, trabajo repartido)

- Rutina cloud de Claude Code (D70), lunes y jueves; escribe solo borradores vía RPC `guide.ingest_*` con token hasheado (D72), sin `service_role`.
- jabali-javi: tablas (`news`, `news_sources`, `ingest_runs`, `ingest_tokens`, `newsletter_issues`), RPC, cron de salud y Edge Function `newsletter-send` (Brevo).
- osset-op: rutina programada, token en su entorno, rotación, cron de envío y secretos (clave de Brevo solo en Supabase secrets).
- loro-lola: prompt de la rutina, fuentes semilla y plantilla de newsletter.
- leona-lia: ingesta, envío y que `anon` nunca vea borradores.
- Instagram solo se lee por la API oficial (Graph API, Business Discovery; D82): token de solo lectura, cuentas Creator/Business. Nada de scraping, login automatizado ni control de cuentas. X queda fuera (D83).
