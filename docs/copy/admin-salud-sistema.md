# Panel · bloque «Sistema» (D88)

Copia de las claves de `admin.pending.system.*` y `admin.health.*` en `i18n/locales/es.json`. Solo español: el panel no tiene versión en inglés y `en.json` no tiene bloque `admin`. Fuente: `docs/design/admin/README.md` §20.8 y `salud-topes.html`.

## Convenciones

- Texto mínimo (D80): una línea fuerte, una de contexto y, si hay destino ausente, una ayuda corta.
- Las cifras salen de `details`, nunca escritas a mano: `{cap}`, `{today}`, `{n}`, `{day}` («18 nov»), `{time}` («10:50», hora de Madrid), `{age}` («6 h», «2 días»), `{task}`, `{job}`.
- `{job}` va en minúscula (`admin.health.job.*`).
- Plurales con `|` (vue-i18n): `{n} minuto … | {n} minutos …`.
- La línea de contexto de «tope de hoy» se arma en código: `capToday.context` + ` · ` + `capToday.withBursts` (si hay ráfagas) + ` · ` + `checkedAt` o `checkedAtYesterday`. Igual para el resto: `checkedAt` va siempre al final.
- Prefijos `sr.*` solo para lectores de pantalla (`sr-only`); llevan espacio final.
- `{task}`: `guide-cookie-consent-purge` o `guide-analytics-purge`, en `code`.

## Textos

| Clave | Texto |
| --- | --- |
| `admin.pending.system.label` | Sistema |
| `admin.health.helpButton` | Cómo arreglarlo |
| `admin.health.checkedAt` | comprobado a las {time} |
| `admin.health.checkedAtYesterday` | comprobado ayer a las {time} |
| `admin.health.sr.fail` / `warn` / `unknown` | Fallo:  / Aviso:  / Sin confirmar:  |
| `admin.health.job.consent` / `analytics` | consentimientos de cookies / analítica |

### Consentimientos (`cookie_consent`)

| Clave | Texto |
| --- | --- |
| `consent.capToday.strong` | No se registran todos los consentimientos de cookies |
| `consent.capToday.context` | Hoy: tope de {cap} alcanzado |
| `consent.capToday.withBursts` | {n} minuto al tope en la última hora \| {n} minutos al tope en la última hora |
| `consent.capToday.help` | Los visitantes no lo notan, pero los consentimientos por encima del tope no quedan registrados y no se recuperan. Revisa el origen en Supabase antes de subir el tope. |
| `consent.bursts.strong` | Ráfagas en el registro de consentimientos |
| `consent.bursts.context` | {n} minuto(s) al tope de {cap} en la última hora · posible bot |
| `consent.bursts.help` | En esos minutos no se registraron consentimientos reales. Si sigue, revisa el origen del tráfico en Supabase. |
| `consent.capYesterday.strong` | Ayer no se registraron todos los consentimientos de cookies |
| `consent.capYesterday.context` | {day}: tope de {cap} alcanzado · hoy, normal ({today}) |
| `consent.capYesterday.help` | Los consentimientos de ayer por encima del tope no se recuperan. El aviso se va solo si hoy no se repite. |

### Analítica (`analytics`)

| Clave | Texto |
| --- | --- |
| `analytics.capToday.strong` | Las cifras de hoy no son fiables |
| `analytics.capDay.strong` | Las cifras del {day} no son fiables |
| `analytics.cap.context` | Tope de {cap} eventos alcanzado · ese día las visitas salen por debajo de las reales |
| `analytics.cap.help` | Los eventos por encima del tope no se guardan. Si fue un pico real, se puede subir el tope; si fue un bot, no hace falta hacer nada. |

### Sin confirmar y parada (tono tranquilo)

| Clave | Texto |
| --- | --- |
| `unknown.strong` | No se ha podido confirmar el estado de {job} |
| `unknown.context` | Último aviso a las {time} · sin comprobar desde hace {age} |
| `unknown.help` | Puede ser un simple retraso: se comprueba cada hora. Si mañana sigue igual, saldrá como comprobación parada. |
| `stopped.strong` | Comprobación de {job} parada |
| `stopped.context.consent` | Sin comprobar desde hace {age} · no se vigila el tope ni se purga el registro |
| `stopped.context.analytics` | Sin comprobar desde hace {age} · no se vigila el tope ni se purgan los eventos |
| `stopped.contextNever.consent` | Nunca comprobada · no se vigila el tope ni se purga el registro |
| `stopped.contextNever.analytics` | Nunca comprobada · no se vigila el tope ni se purgan los eventos |
| `stopped.help` | Comprueba en Supabase que la tarea programada {task} sigue activa. |

`stopped.contextNever.*` sustituye a `stopped.context.*` cuando la tarea no ha llegado a ejecutarse nunca (no hay `{age}`). Usa la misma `stopped.help`.

### Error de lectura y fallo genérico (D88)

| Clave | Texto |
| --- | --- |
| `readError.strong` | No se ha podido leer el estado del sistema |
| `readError.context` | Recarga la página. Si sigue igual, puede ser un problema de permisos en Supabase. |
| `generic.strong` | Ha fallado la comprobación de {job} |
| `generic.context` | Aviso sin reconocer: {alerts} · `checkedAt` |
| `generic.help` | El panel no sabe explicar este aviso. Mira el detalle de la tarea en Supabase. |

`{alerts}` es el código del aviso tal cual llega, sin traducir. Si el 500 llega sin alertas, en su lugar va `sin código` (clave `generic.noCode`; validado, sin cambios en el código). `checkedAt` se añade en código (convención de arriba). `readError` no lleva ayuda ni `checkedAt`: no hay estado que fechar.

### Movidos desde código (D88, sin cambios de texto)

| Clave | Texto |
| --- | --- |
| `ingest.strong` | La rutina de novedades no está recogiendo |
| `ingest.context` | Mira el motivo y qué hacer en Ingesta |
| `cleanup.strong` | Ha fallado la limpieza nocturna de fotos |
| `cleanup.context` | Las fotos rechazadas o caducadas pueden no borrarse |
| `cleanup.help` | Comprueba que la limpieza sigue programada y que su secreto coincide en Edge Function secrets y en Vault. |

Hoy estos cuatro textos viven escritos en `app/utils/admin-dashboard-pending.ts` (líneas ~102, ~179 y ~204). Ajustan bien al bloque; coneja-lucky los cambia a claves.

## Fuera de este bloque

Las cuatro claves `admin.stats.visits.incomplete.*` de §20.8 (chip, leyenda, nota de tabla) no se han escrito: dependen de conectar «Visitas» y no son del bloque Sistema.
