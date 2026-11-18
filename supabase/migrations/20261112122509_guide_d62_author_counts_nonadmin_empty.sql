-- D62: la fila del autor del sitio es un agregado sin group by y salía (0, 0) a un no-admin; con having, 0 filas.
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
where a.author_id is null
having (select guide.is_admin());

revoke all on guide.admin_author_article_counts from public, anon, authenticated, service_role;
grant select on guide.admin_author_article_counts to authenticated;
