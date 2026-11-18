# Revisión de seguridad · Cierre a medianoche en horarios de rocódromos

- Migración: `supabase/migrations/20261106170124_guide_gyms_hours_midnight.sql`
- Proyecto: `eqtjlafxtrzbjazhhyin` (aplicada como `20261106170124:guide_gyms_hours_midnight`)
- Revisora: leona-lia
- Fecha: 2026-11-06
- Veredicto: **APROBADO**

## Alcance

La migración recrea `guide.opening_hours_valid(jsonb)` para que `24:00` se acepte solo como hora de cierre (fin del día, 1440 minutos). La firma, la volatilidad y los permisos no cambian. Aparte, y fuera de la migración, se escribió directamente el horario de Freebloc en `guide.gyms`.

## Comprobaciones

### Función, ACL y search_path

- La firma sigue siendo `guide.opening_hours_valid(p_hours jsonb) returns boolean`.
- Es `immutable` y SECURITY INVOKER (`prosecdef = false`).
- `proconfig = {search_path=""}`.
- `proacl = {postgres=X, authenticated=X, service_role=X}`: no hay EXECUTE para `PUBLIC` ni para `anon`. Coincide con la ACL anterior y con el `revoke`/`grant` del archivo.
- No existe ninguna función con ese nombre en `public`.

La función no lee tablas: solo opera sobre el `jsonb` de entrada, así que cumple la regla de que los CHECK de `guide` sean expresiones puras. Las funciones que dependen de ella son SECURITY INVOKER y no cambian: `guide.draft_allowed_columns(text)`, `guide.item_publish_blockers(uuid)` y `guide.import_row(...)`.

### CHECK

`gyms_opening_hours_valid` en `guide.gyms` existe, tiene `convalidated = true` y su definición es `CHECK (guide.opening_hours_valid(opening_hours))`. Recrear una función no vuelve a validar las filas existentes, así que se comprobaron a mano: las 13 filas de `guide.gyms` pasan con la versión nueva (0 inválidas).

### Pruebas de entrada (horarios raros)

Rechazados, como corresponde:

- `24:00` como apertura: `["24:00","24:00"]` y `["24:00","23:00"]`.
- Cierres de la forma 24:xx o fuera de rango: `24:01`, `24:59` y `25:00`.
- Tramos que cruzan la medianoche: `["22:00","02:00"]` y `["22:00","00:00"]`.
- Formatos parecidos: `"24:00\n"`, `" 24:00"`, `"24:0"`, `"24"`, `"2400"` y `"24:00:00"`.
- Estructura: tramo de 3 elementos, hora numérica en vez de cadena y clave de día desconocida.

Aceptados, como corresponde: `["07:00","24:00"]`, `["00:00","24:00"]`, `["9:00","24:00"]` (la hora de un dígito ya se aceptaba) y un día sin tramos (`[]`).

El regex de cierre `^(([01]?[0-9]|2[0-3]):[0-5][0-9]|24:00)$` solo añade el literal exacto `24:00`. El de apertura no cambia y no admite la hora 24. La comparación en minutos sigue impidiendo los tramos que cruzan la medianoche.

### Escritura directa en Freebloc

La fila de `guide.gyms` con `item_id = ea181db5-3139-42e4-ba2c-2fbe0d4d127d` contiene 07:00-24:00 de lunes a domingo, y `opening_hours_note_es` y `opening_hours_note_en` a NULL. El ítem sigue con `published = false` y `published_at = null`. No se publicó nada solo (regla 6).

### Schema public

La migración solo toca `guide.opening_hours_valid`. No hay ninguna sentencia sobre tablas, policies ni GRANTs de `public`.

### Advisors (security)

No hay ningún aviso sobre `opening_hours_valid`. Los que aparecen ya existían y no tienen que ver con esta migración: INFO `rls_enabled_no_policy` en `guide.user_review_photo_quota`, WARN de SECURITY DEFINER ejecutables por anon o authenticated en `guide.*` (ya revisados), `search_path` mutable en funciones de `public` (Chalk app, fuera de alcance) y la protección de contraseñas filtradas desactivada.

## Observaciones (no bloquean)

1. La función acepta tramos que se solapan el mismo día, por ejemplo `[["07:00","24:00"],["08:00","09:00"]]`. Ya pasaba antes y no es un problema de seguridad, sino de calidad de datos. Si se quiere cerrar, puede añadirse una comprobación de orden y no solape en una migración aparte.
2. La lógica pública de «abierto ahora» debe tratar `24:00` como 1440 minutos. Es tarea de frontend, no de seguridad; la autoridad sigue siendo el CHECK de la base de datos.

## Veredicto

**APROBADO.** No hay vetos abiertos.
