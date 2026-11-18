-- D62 · Panel de Autores (README admin §17.8). Sin cambios de schema en tablas.
-- 1) guide.admin_author_article_counts: recuentos de artículos por autor (total y vivos con article_is_live).
--    Una fila por autor de guide.authors (0 si no firma nada) y una fila con author_id NULL = autor del sitio
--    (site_settings, D51). Vista security_invoker: la RLS de articles se aplica al que consulta y además
--    se filtra por is_admin(), así que un no-admin recibe 0 filas. Solo authenticated.
-- 2) guide.admin_reorder_authors(p_ids): guarda el orden completo en una sola llamada, como
--    reorder_article_categories (lista completa, sin nulos ni duplicados, ids conocidos). INVOKER: la escritura
--    pasa por la RLS de update de authors (solo admin).

create or replace view guide.admin_author_article_counts with (security_invoker = true) as
select au.id as author_id,
       count(a.id)::integer as articles_total,
       (count(a.id) filter (where guide.article_is_live(a.status, a.published_at)))::integer as articles_live
from guide.authors au
left join guide.articles a on a.author_id = au.id
where (select guide.is_admin())
group by au.id
union all
select null::uuid,
       count(a.id)::integer,
       (count(a.id) filter (where guide.article_is_live(a.status, a.published_at)))::integer
from guide.articles a
where a.author_id is null and (select guide.is_admin());

revoke all on guide.admin_author_article_counts from public, anon, authenticated, service_role;
grant select on guide.admin_author_article_counts to authenticated;

create or replace function guide.admin_reorder_authors(p_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if p_ids is null or array_position(p_ids, null) is not null then
    raise exception 'ids required' using errcode = '22023';
  end if;
  if (select count(distinct u) from unnest(p_ids) u) <> cardinality(p_ids) then
    raise exception 'duplicate ids' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(p_ids) u(id) where not exists (select 1 from guide.authors au where au.id = u.id)) then
    raise exception 'unknown author' using errcode = '22023';
  end if;
  if (select count(*) from guide.authors) <> cardinality(p_ids) then
    raise exception 'list must include every author' using errcode = '22023';
  end if;

  update guide.authors au
  set sort_order = x.ord::integer
  from unnest(p_ids) with ordinality as x(id, ord)
  where au.id = x.id and au.sort_order is distinct from x.ord::integer;
end;
$$;

revoke all on function guide.admin_reorder_authors(uuid[]) from public, anon, service_role;
grant execute on function guide.admin_reorder_authors(uuid[]) to authenticated;
