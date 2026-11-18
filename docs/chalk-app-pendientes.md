# Pendientes para Chalk app (detectados desde ChalkGuide)

> Hallazgos en el schema `public` del Supabase compartido (`eqtjlafxtrzbjazhhyin`), que pertenece a
> Chalk app. ChalkGuide no los corrige: se llevan a ese proyecto cuando toque.
> Origen: revisión de seguridad F2.10 (`docs/security/F2.10-guide-review.md`) y revisiones posteriores.

**Última actualización:** 2026-10-05

## 1. Ya aplicado desde aquí (copiar al repo de Chalk app)

### X1 · Escalada a admin vía `public.profiles.is_admin` · ✅ corregido 2026-10-05

- **Problema:** la policy `own profile write` (UPDATE `auth.uid() = id`) y los GRANTs de columna
  permitían a cualquier usuario ponerse `is_admin = true` en su fila. Con eso,
  `get_profiles_with_email()` le devolvía los emails de todos los usuarios, y también tenía acceso a
  `admin_roles`, `app_config`, `get_admin_profile()` y `set_admin_by_email()`.
- **Fix aplicado** con autorización de Xavi, como migración `20261005052654_public_profiles_protect_is_admin`:
  trigger `profiles_protect_is_admin`. Si el rol es `anon`/`authenticated`, en INSERT fuerza
  `is_admin = false` y en UPDATE lanza 42501 si cambia. `set_admin_by_email()` sigue funcionando
  porque corre como propietario.
- **Verificado** con rollback: autoescalada bloqueada, edición normal de perfil ok y promoción
  legítima ok. No había admins ilegítimos (3 `is_admin` = 3 `admin_roles`).
- **Acción en Chalk app:** añadir el SQL a sus migraciones (`docs/security/X1-fix-public-profiles.sql`)
  y comprobar que ningún flujo de la app envía `is_admin` en un update de perfil.

## 2. Pendiente de corregir en Chalk app

| # | Severidad | Problema | Sugerencia |
| --- | --- | --- | --- |
| A1 | Alta | Cada usuario puede editar en su propia fila `subscription_status`, `subscription_until`, `certified` y `gym_certificate` (misma causa que X1). Cualquiera puede regalarse la suscripción de pago o marcarse como certificado. | Extender el trigger de X1 a esas columnas, o revocar UPDATE por columna a `anon`/`authenticated` y escribirlas solo desde el webhook de pagos o una función SECURITY DEFINER. Antes, revisar qué flujos de la app las escriben desde el cliente. |
| A2 | Media | `public read profiles` (SELECT `true` para `public`): cualquiera, incluso sin login, lee todos los perfiles, incluidos `fcm_token`, `is_admin`, `subscription_*` y `gender`. | Exponer solo columnas públicas (vista o GRANT por columna) y dejar `fcm_token`/`subscription_*` legibles solo por el propio usuario. Revisar `visible_to`/`show_gender`, que hoy no se aplican en RLS. |
| A3 | Media | `anon` tiene GRANT de INSERT/UPDATE sobre `public.profiles` (las policies lo frenan hoy, pero sobra). | `revoke insert, update on public.profiles from anon`. |
| A4 | Baja | Las funciones SECURITY DEFINER `get_admin_profile`, `get_profiles_with_email` y `set_admin_by_email` no fijan `search_path`. | Añadir `set search_path = ''` y calificar los objetos con su schema. |
| A5 | Baja | Auth: protección de contraseñas filtradas desactivada (aviso de `get_advisors`). | Activarla en Authentication → Policies. Afecta a ambos proyectos (para bien). |
| A6 | Info | Otros avisos de `get_advisors` sobre `public`. | Revisarlos desde el proyecto de la app. |

## 3. Efectos de ChalkGuide sobre Chalk app (a tener en cuenta)

- **Auth compartida.** Los lectores que entren con Google en la guía crean un `auth.users` y, por
  el trigger `handle_new_user`, un `public.profiles` vacío (decisión P4/D11). La app deberá pedir
  los datos que falten (nivel, rocódromo…) la primera vez que esa persona entre en ella.
- **Registro por email activo.** No se desactiva desde la guía porque afectaría a la app (D2).
- **Rocódromos duplicados.** La guía tiene sus fichas en `guide.gyms`. En la fase 3 ("Encuentra
  compañero", F9.2) habrá que vincularlas con `public.gyms` de la app, con aprobación.
- **Extensión `unaccent` compartida (D21, 2026-10-08).** ChalkGuide instaló `unaccent` en el schema
  `extensions`, y las configuraciones de búsqueda `guide.spanish_unaccent` y `guide.english_unaccent`
  dependen de ella (y de esas configuraciones, las columnas `guide.articles.search_es/search_en`).
  **No ejecutar `drop extension unaccent cascade`** desde Chalk app: rompería en cascada la búsqueda del
  blog. Si la app también usa `unaccent()`, puede hacerlo sin problema. Si alguna vez hay que moverla
  o recrearla, avisa antes a ChalkGuide (ver `docs/data-model.md` §8, D21).
