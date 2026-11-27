-- D87 · Registro mínimo de consentimientos de cookies (docs/security/D86-cookie-consent-front-review.md, «Pregunta 6»).
-- Prueba art. 7.1 RGPD / política de consentimiento de Google: qué se eligió, con qué revisión del banner y cuándo.
-- Sin IP, user agent, user_id ni path: ninguna columna lo admite y el RPC no lee request.headers. consent_id es el
-- consentId aleatorio de vanilla-cookieconsent (seudónimo: solo se liga a alguien si aporta su cookie).
-- categories guarda solo las opcionales aceptadas ('analytics', 'ads'), ordenadas y sin repetir; 'necessary' es
-- implícita y no se guarda ({} = solo necesarias, es decir, rechazo). Conservación: 36 meses (purga horaria por pg_cron).
-- Idempotente.

-- ───────────── Tablas ─────────────
create table if not exists guide.cookie_consent_log (
  id          bigint generated always as identity primary key,
  consent_id  uuid not null,
  action      text not null,
  categories  text[] not null default '{}',
  revision    integer not null,
  locale      guide.locale not null,
  created_at  timestamptz not null default date_trunc('minute', now()),
  constraint cookie_consent_log_action_check check (action in ('first', 'change')),
  constraint cookie_consent_log_categories_check check (
    categories <@ array['analytics', 'ads']::text[]
    and array_position(categories, null) is null
    and cardinality(categories) <= 2),
  constraint cookie_consent_log_revision_check check (revision between 0 and 100000),
  constraint cookie_consent_log_created_minute_check check (created_at = date_trunc('minute', created_at))
);
create index if not exists cookie_consent_log_consent_idx on guide.cookie_consent_log (consent_id, created_at);
create index if not exists cookie_consent_log_created_idx on guide.cookie_consent_log (created_at);

-- Contador global por minuto ('*') y por día UTC ('*day'). Sin identificador de cliente.
create table if not exists guide.cookie_consent_rate (
  bucket timestamptz not null,
  name   text not null,
  n      integer not null default 0,
  primary key (bucket, name),
  constraint cookie_consent_rate_name_check check (name in ('*', '*day'))
);

alter table guide.cookie_consent_log enable row level security;
alter table guide.cookie_consent_rate enable row level security;

-- Sin policies ni GRANT: escribe solo log_cookie_consent y lee solo el admin por RPC (ambas como dueño).
revoke all on table guide.cookie_consent_log, guide.cookie_consent_rate from public, anon, authenticated, service_role;
revoke all on sequence guide.cookie_consent_log_id_seq from public, anon, authenticated, service_role;

comment on table guide.cookie_consent_log is
  'D87. Prueba de consentimiento de cookies: consent_id (seudónimo de la cookie), acción, categorías opcionales aceptadas, revisión y locale. Sin IP, UA, usuario ni path. Escritura: guide.log_cookie_consent. 36 meses.';
comment on column guide.cookie_consent_log.categories is
  'Solo opcionales aceptadas (analytics, ads), ordenadas. necessary es implícita y no se guarda; {} = rechazo.';
comment on table guide.cookie_consent_rate is
  'D87. Contador global por minuto (*) y por día UTC (*day) para el tope de guide.log_cookie_consent.';

-- ───────────── Escritura (anon y authenticated) ─────────────
-- Topes: 120/min y 5.000/día UTC en total; 10 filas por consent_id y día UTC. Nunca falla.
create or replace function guide.log_cookie_consent(
  p_consent_id uuid, p_action text, p_categories text[], p_revision integer, p_locale text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_minute     constant integer := 120;
  c_day        constant integer := 5000;
  c_per_id_day constant integer := 10;
  v_bucket     timestamptz := date_trunc('minute', now());
  v_day        timestamptz := date_trunc('day', now(), 'UTC');
  v_cats       text[];
  v_n_min      integer;
  v_n_day      integer;
begin
  if p_consent_id is null or p_action is null or p_action not in ('first', 'change')
     or p_revision is null or p_revision < 0 or p_revision > 100000
     or p_locale is null or p_locale not in ('es', 'en')
     or p_categories is null or cardinality(p_categories) > 3 or array_position(p_categories, null) is not null
     or not (p_categories <@ array['necessary', 'analytics', 'ads']::text[]) then
    return;
  end if;

  select coalesce(array_agg(distinct c order by c), '{}') into v_cats
  from unnest(p_categories) c
  where c <> 'necessary';

  -- Orden fijo de filas ('*', '*day') para no crear interbloqueos. El intento que supera un tope no se escribe.
  with u as (
    insert into guide.cookie_consent_rate as r (bucket, name, n)
    values (v_bucket, '*', 1), (v_day, '*day', 1)
    on conflict (bucket, name) do update set n = r.n + 1
    returning r.name, r.n
  )
  select max(u.n) filter (where u.name = '*'), max(u.n) filter (where u.name = '*day')
  into v_n_min, v_n_day
  from u;

  if v_n_min > c_minute or v_n_day > c_day then
    return;
  end if;

  if (select count(*) from guide.cookie_consent_log l
      where l.consent_id = p_consent_id and l.created_at >= v_day) >= c_per_id_day then
    return;
  end if;

  begin
    insert into guide.cookie_consent_log (consent_id, action, categories, revision, locale, created_at)
    values (p_consent_id, p_action, v_cats, p_revision, p_locale::guide.locale, v_bucket);
  exception when others then
    -- El banner nunca debe romperse por el registro.
    return;
  end;
end;
$$;
revoke all on function guide.log_cookie_consent(uuid, text, text[], integer, text) from public, service_role;
grant execute on function guide.log_cookie_consent(uuid, text, text[], integer, text) to anon, authenticated;

-- ───────────── Lectura (solo admin) ─────────────
-- Historial de un consent_id (cuando alguien aporta su cookie). Orden cronológico.
create or replace function guide.admin_cookie_consent_lookup(p_consent_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_consent_id is null then
    raise exception 'consent_id required' using errcode = '22023';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object('created_at', l.created_at, 'action', l.action, 'categories', to_jsonb(l.categories),
                                        'revision', l.revision, 'locale', l.locale) order by l.created_at, l.id)
    from guide.cookie_consent_log l
    where l.consent_id = p_consent_id), '[]'::jsonb);
end;
$$;

-- Recuentos por revisión, acción, categorías y locale en un rango de días UTC (null = sin límite; el registro solo guarda 36 meses).
create or replace function guide.admin_cookie_consent_counts(p_from date default null, p_to date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_from is not null and p_to is not null and p_from > p_to then
    raise exception 'invalid range' using errcode = '22023';
  end if;
  return jsonb_build_object(
    'from', p_from, 'to', p_to, 'generated_at', now(),
    'total', (select count(*) from guide.cookie_consent_log l
              where (p_from is null or l.created_at >= p_from::timestamp at time zone 'UTC')
                and (p_to is null or l.created_at < (p_to + 1)::timestamp at time zone 'UTC')),
    'rows', coalesce((
      select jsonb_agg(jsonb_build_object('revision', g.revision, 'action', g.action, 'categories', to_jsonb(g.categories),
                                          'locale', g.locale, 'n', g.n)
                       order by g.revision desc, g.action, g.categories, g.locale)
      from (
        select l.revision, l.action, l.categories, l.locale, count(*) n
        from guide.cookie_consent_log l
        where (p_from is null or l.created_at >= p_from::timestamp at time zone 'UTC')
          and (p_to is null or l.created_at < (p_to + 1)::timestamp at time zone 'UTC')
        group by 1, 2, 3, 4
      ) g), '[]'::jsonb));
end;
$$;
revoke all on function guide.admin_cookie_consent_lookup(uuid) from public, anon, service_role;
revoke all on function guide.admin_cookie_consent_counts(date, date) from public, anon, service_role;
grant execute on function guide.admin_cookie_consent_lookup(uuid) to authenticated;
grant execute on function guide.admin_cookie_consent_counts(date, date) to authenticated;

-- ───────────── Conservación ─────────────
-- SECURITY INVOKER: solo pg_cron como postgres (como guide.purge_activity_log, D60). Sin EXECUTE para la API.
-- Borra el registro de más de 36 meses, los contadores por minuto de más de 1 hora y los '*day' de más de 2 días.
create or replace function guide.purge_cookie_consent_log()
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_deleted bigint;
begin
  delete from guide.cookie_consent_log l
  where l.created_at < now() - interval '36 months';
  get diagnostics v_deleted = row_count;

  delete from guide.cookie_consent_rate r
  where (r.name = '*' and r.bucket < now() - interval '1 hour')
     or (r.name = '*day' and r.bucket < date_trunc('day', now(), 'UTC') - interval '2 days');

  return v_deleted;
end;
$$;
revoke all on function guide.purge_cookie_consent_log() from public, anon, authenticated, service_role;

-- Cada hora a los :50 (los contadores por minuto no se acumulan). cron.schedule con el mismo nombre actualiza el job.
select cron.schedule('guide-cookie-consent-purge', '50 * * * *', $$select guide.purge_cookie_consent_log()$$);
