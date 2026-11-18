-- F2.9 · Cierre de RLS: verificación que falla si algo quedó abierto en el schema guide.
-- No cambia datos; re-ejecutable.

-- Ninguna función de guide ejecutable por PUBLIC (los grants son explícitos por rol).
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as fn
    from pg_proc p
    where p.pronamespace = 'guide'::regnamespace
  loop
    execute format('revoke execute on function %s from public', r.fn);
  end loop;
end $$;

do $$
declare
  v_bad text;
begin
  -- 1. Toda tabla con RLS activado.
  select string_agg(c.relname, ', ') into v_bad
  from pg_class c
  where c.relnamespace = 'guide'::regnamespace and c.relkind = 'r' and not c.relrowsecurity;
  if v_bad is not null then
    raise exception 'RLS desactivado en: %', v_bad;
  end if;

  -- 2. Toda tabla con al menos una policy.
  select string_agg(c.relname, ', ') into v_bad
  from pg_class c
  where c.relnamespace = 'guide'::regnamespace and c.relkind = 'r'
    and not exists (select 1 from pg_policy p where p.polrelid = c.oid);
  if v_bad is not null then
    raise exception 'Tablas sin policies: %', v_bad;
  end if;

  -- 3. anon nunca escribe directamente en tablas de guide.
  select string_agg(distinct table_name, ', ') into v_bad
  from information_schema.role_table_grants
  where table_schema = 'guide' and grantee = 'anon'
    and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE');
  if v_bad is not null then
    raise exception 'anon con escritura en: %', v_bad;
  end if;

  -- 4. anon no lee tablas internas.
  select string_agg(distinct table_name, ', ') into v_bad
  from information_schema.role_table_grants
  where table_schema = 'guide' and grantee = 'anon' and privilege_type = 'SELECT'
    and table_name in ('admins', 'activity_log', 'content_media_refs', 'subscribers', 'gym_waitlist',
                       'media_usage', 'media_library', 'export_articles', 'export_items',
                       'export_user_reviews', 'export_subscribers', 'export_events');
  if v_bad is not null then
    raise exception 'anon puede leer tablas internas: %', v_bad;
  end if;

  -- 5. Todas las vistas con security_invoker.
  select string_agg(c.relname, ', ') into v_bad
  from pg_class c
  where c.relnamespace = 'guide'::regnamespace and c.relkind = 'v'
    and not coalesce(c.reloptions @> array['security_invoker=true'], false);
  if v_bad is not null then
    raise exception 'Vistas sin security_invoker: %', v_bad;
  end if;

  -- 6. Todas las funciones con search_path fijado.
  select string_agg(p.proname, ', ') into v_bad
  from pg_proc p
  where p.pronamespace = 'guide'::regnamespace
    and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) cfg where cfg like 'search_path=%');
  if v_bad is not null then
    raise exception 'Funciones sin search_path: %', v_bad;
  end if;
end $$;
