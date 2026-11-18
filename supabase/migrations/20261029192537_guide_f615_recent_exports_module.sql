-- F6.15 (D37) · Exportar, parte 2b: la exportación se lanza desde un modal en cada módulo, y «Últimas exportaciones»
-- pasa a ser la última de ese módulo. admin_recent_exports acepta un p_module opcional (en lista cerrada). Como
-- cambia la firma, se borra la de un solo argumento.
-- Idempotente.

drop function if exists guide.admin_recent_exports(integer);

create or replace function guide.admin_recent_exports(p_limit integer default 5, p_module text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_limit is null or p_limit < 1 or p_limit > 50 then
    raise exception 'invalid limit' using errcode = '22023';
  end if;
  if p_module is not null and p_module not in ('articles', 'items', 'user_reviews', 'subscribers', 'events') then
    raise exception 'invalid module' using errcode = '22023';
  end if;
  return (
    select coalesce(jsonb_agg(jsonb_build_object(
             'id', l.id, 'occurred_at', l.occurred_at, 'view', l.entity_table,
             'module', regexp_replace(l.entity_table, '^export_', ''),
             'format', l.details ->> 'format', 'row_count', (l.details ->> 'row_count')::integer,
             'truncated', coalesce((l.details ->> 'truncated')::boolean, false),
             'personal_data', coalesce((l.details ->> 'personal_data')::boolean, l.entity_table = 'export_subscribers'),
             'purpose', l.details ->> 'purpose', 'filters', l.details -> 'filters', 'columns', l.details -> 'columns')
           order by l.occurred_at desc, l.id desc), '[]'::jsonb)
    from (select * from guide.activity_log
          where action = 'export' and (p_module is null or entity_table = 'export_' || p_module)
          order by occurred_at desc, id desc limit p_limit) l
  );
end;
$$;

revoke all on function guide.admin_recent_exports(integer, text) from public, anon, service_role;
grant execute on function guide.admin_recent_exports(integer, text) to authenticated;
