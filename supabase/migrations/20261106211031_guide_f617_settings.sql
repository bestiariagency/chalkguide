-- F6.17 · Ajustes (/administrador/ajustes, docs/design/admin/ajustes.html).
-- site_settings ya es una sola fila (pk id + CHECK id = 1, sin INSERT/DELETE para anon ni authenticated) y ya valida
-- nombre, lema, SEO por defecto, email, opiniones, autor (D51) y la imagen OG con alt_es y alt_en (site_settings_require_alt,
-- FK on delete restrict). Faltaba:
--   1. Redes con URL https válidas (antes bastaba con que social_links fuera un objeto).
--   2. Topes en pie, bloque de newsletter, textos de consentimiento y email (antes sin límite).
--   3. Guardado atómico con detección de conflicto entre pestañas y subida automática de la versión de consentimiento
--      (admin_update_settings).
--   4. «Tu cuenta › Sesiones abiertas»: lista de las sesiones propias sin IP ni ids (admin_my_sessions).

-- ───────────── 1. Redes: {clave: "https://…"} ─────────────
-- Claves abiertas (sumar una red no exige migración) pero acotadas; valores https con host, sin espacios, comillas ni
-- userinfo (el front los usa como href). Inmutable y sin leer datos: vale en un CHECK.
create or replace function guide.social_links_valid(p jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p is null or jsonb_typeof(p) <> 'object' then false
    when (select count(*) from jsonb_object_keys(p)) > 8 then false
    else not exists (
      select 1 from jsonb_each(p) e(k, v)
      where not coalesce(
        e.k ~ '^[a-z][a-z0-9_]{1,23}$'
        and jsonb_typeof(e.v) = 'string'
        and char_length(e.v #>> '{}') <= 300
        and (e.v #>> '{}') ~ '^https://[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+([/?#][^[:space:]<>"''\\]*)?$',
        false))
  end;
$$;
revoke execute on function guide.social_links_valid(jsonb) from public, anon;
grant execute on function guide.social_links_valid(jsonb) to authenticated;

-- ───────────── 2. Topes ─────────────
alter table guide.site_settings
  drop constraint if exists site_settings_social_links_valid,
  add constraint site_settings_social_links_valid check (guide.social_links_valid(social_links)),
  drop constraint if exists site_settings_footer_text_es_check,
  add constraint site_settings_footer_text_es_check check (char_length(footer_text_es) <= 300),
  drop constraint if exists site_settings_footer_text_en_check,
  add constraint site_settings_footer_text_en_check check (char_length(footer_text_en) <= 300),
  drop constraint if exists site_settings_newsletter_title_es_check,
  add constraint site_settings_newsletter_title_es_check check (char_length(newsletter_title_es) <= 120),
  drop constraint if exists site_settings_newsletter_title_en_check,
  add constraint site_settings_newsletter_title_en_check check (char_length(newsletter_title_en) <= 120),
  drop constraint if exists site_settings_newsletter_body_es_check,
  add constraint site_settings_newsletter_body_es_check check (char_length(newsletter_body_es) <= 400),
  drop constraint if exists site_settings_newsletter_body_en_check,
  add constraint site_settings_newsletter_body_en_check check (char_length(newsletter_body_en) <= 400),
  -- Mismo tope que consent_texts; el es es obligatorio y no puede quedar en blanco.
  drop constraint if exists site_settings_newsletter_consent_text_es_check,
  add constraint site_settings_newsletter_consent_text_es_check
    check (char_length(btrim(newsletter_consent_text_es)) between 1 and 2000),
  drop constraint if exists site_settings_newsletter_consent_text_en_check,
  add constraint site_settings_newsletter_consent_text_en_check check (char_length(newsletter_consent_text_en) <= 2000),
  drop constraint if exists site_settings_contact_email_length_check,
  add constraint site_settings_contact_email_length_check check (char_length(contact_email) <= 254);

-- ───────────── 3. Guardado atómico ─────────────
-- p_changes: {columna: valor nuevo}; p_base: {columna: valor que cargó la pestaña} para las mismas claves.
-- Conflicto solo si otra pestaña cambió una de esas columnas (las demás, p. ej. las fotos del hero desde Páginas, no
-- molestan): PT409 'settings_conflict' con detail {keys, current} y no se escribe nada.
-- '' en un texto opcional se guarda como null. Si cambia el consentimiento (es o en), consent_version sube en 1 y el
-- trigger site_settings_consent_version cierra la versión vigente y crea la nueva en consent_texts.
-- id, updated_at y consent_version no se aceptan. Una sola sentencia UPDATE: todo o nada, con los CHECK y triggers.
-- INVOKER: los GRANT de columna y la policy site_settings_update (is_admin) siguen mandando.
create or replace function guide.admin_update_settings(p_changes jsonb, p_base jsonb)
returns guide.site_settings
language plpgsql
security invoker
set search_path = ''
as $$
declare
  c_locked   constant text[] := array['id', 'updated_at', 'consent_version'];
  c_required constant text[] := array['site_name', 'newsletter_consent_text_es'];
  v_row      guide.site_settings;
  v_new      guide.site_settings;
  v_cur      jsonb;
  v_patch    jsonb := '{}'::jsonb;
  v_bad      text[];
  v_conflict text[];
  v_key      text;
  v_val      jsonb;
  v_base     jsonb;
  v_now      jsonb;
  v_is_text  boolean;
  v_sets     text;
begin
  if not (select guide.is_admin()) then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  if p_changes is null or jsonb_typeof(p_changes) <> 'object'
     or p_base is null or jsonb_typeof(p_base) <> 'object' then
    raise exception 'invalid_payload' using errcode = '22023';
  end if;

  select array_agg(k order by k) into v_bad
  from jsonb_object_keys(p_changes) k
  where k = any (c_locked)
     or not exists (select 1 from pg_attribute a
                    where a.attrelid = 'guide.site_settings'::regclass and a.attname = k
                      and a.attnum > 0 and not a.attisdropped);
  if v_bad is not null then
    raise exception 'unknown_setting' using errcode = '22023',
      detail = jsonb_build_object('keys', to_jsonb(v_bad))::text;
  end if;
  select array_agg(k order by k) into v_bad
  from jsonb_object_keys(p_changes) k where not (p_base ? k);
  if v_bad is not null then
    raise exception 'base_missing' using errcode = '22023',
      detail = jsonb_build_object('keys', to_jsonb(v_bad))::text;
  end if;

  select * into v_row from guide.site_settings where id = 1 for update;
  if not found then
    raise exception 'settings_missing' using errcode = 'P0002';
  end if;
  v_cur := to_jsonb(v_row);

  for v_key, v_val in select * from jsonb_each(p_changes) loop
    v_base := p_base -> v_key;
    v_now  := v_cur -> v_key;
    select a.atttypid = 'text'::regtype into v_is_text
    from pg_attribute a where a.attrelid = 'guide.site_settings'::regclass and a.attname = v_key;
    if v_is_text and not (v_key = any (c_required)) then
      if jsonb_typeof(v_val) = 'string' and btrim(v_val #>> '{}') = '' then v_val := 'null'::jsonb; end if;
      if jsonb_typeof(v_base) = 'string' and btrim(v_base #>> '{}') = '' then v_base := 'null'::jsonb; end if;
      if jsonb_typeof(v_now) = 'string' and btrim(v_now #>> '{}') = '' then v_now := 'null'::jsonb; end if;
    end if;
    if v_base is distinct from v_now then
      v_conflict := array_append(v_conflict, v_key);
    elsif v_val is distinct from v_now then
      v_patch := v_patch || jsonb_build_object(v_key, v_val);
    end if;
  end loop;

  if v_conflict is not null then
    raise exception 'settings_conflict' using errcode = 'PT409',
      detail = jsonb_build_object(
        'keys', to_jsonb(v_conflict),
        'current', (select jsonb_object_agg(k, v_cur -> k) from unnest(v_conflict) k),
        'updated_at', v_row.updated_at)::text;
  end if;

  if v_patch = '{}'::jsonb then
    return v_row;
  end if;
  if v_patch ? 'newsletter_consent_text_es' or v_patch ? 'newsletter_consent_text_en' then
    v_patch := v_patch || jsonb_build_object('consent_version', v_row.consent_version + 1);
  end if;

  v_new := jsonb_populate_record(v_row, v_patch);
  select string_agg(format('%I = ($1).%I', k, k), ', ') into v_sets from jsonb_object_keys(v_patch) k;
  execute format('update guide.site_settings set %s where id = 1 returning *', v_sets) into v_row using v_new;
  if v_row.id is null then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  return v_row;
end;
$$;
revoke execute on function guide.admin_update_settings(jsonb, jsonb) from public, anon;
grant execute on function guide.admin_update_settings(jsonb, jsonb) to authenticated;

-- ───────────── 4. Sesiones propias ─────────────
-- DEFINER para leer auth.sessions (sin GRANT a la API). Solo el admin y solo sus filas; sin id de sesión, IP, tokens
-- ni factores. «Cerrar las demás» se hace en el cliente con auth.signOut({ scope: 'others' }).
create or replace function guide.admin_my_sessions()
returns table (is_current boolean, user_agent text, created_at timestamptz, last_active_at timestamptz)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (select guide.is_admin()) then
    raise exception 'not_admin' using errcode = '42501';
  end if;
  return query
    select s.id::text is not distinct from (select auth.jwt() ->> 'session_id'),
           left(s.user_agent, 300),
           s.created_at,
           greatest(s.created_at, s.updated_at, s.refreshed_at at time zone 'UTC')
    from auth.sessions s
    where s.user_id = (select auth.uid())
      and (s.not_after is null or s.not_after > now())
    order by 1 desc, 4 desc nulls last
    limit 20;
end;
$$;
revoke execute on function guide.admin_my_sessions() from public, anon;
grant execute on function guide.admin_my_sessions() to authenticated;
