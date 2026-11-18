-- F6.19 punto 5 (O6 de F6.8; docs/security/F6.19-panel-review.md). Idempotente.
-- Con borrador pendiente, un artículo vivo no sale de la web por la puerta de atrás: además de pasar a 'draft',
-- tampoco puede pasar a 'scheduled' con fecha futura ni mover solo published_at al futuro. Hay que usar
-- unpublish_article (aplica el borrador) o descartar el borrador antes. Mismas exenciones que antes
-- (mantenimiento como postgres y unpublish_article). El trigger escucha también published_at.
create or replace function guide.articles_unpublish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if ((old.status in ('scheduled', 'published') and new.status = 'draft')
      or (guide.article_is_live(old.status, old.published_at)
          and not guide.article_is_live(new.status, new.published_at)))
     and not guide.alt_guard_bypassed() and not guide.alt_unpublish_bypassed(old.id)
     and exists (select 1 from guide.content_drafts d where d.entity = 'article' and d.entity_id = old.id) then
    raise exception 'pending draft'
      using errcode = 'PT423',
            detail = 'use unpublish_article',
            hint = 'Unpublish through unpublish_article (applies the pending draft), or discard the draft first.';
  end if;
  return new;
end;
$$;

drop trigger if exists articles_unpublish_guard on guide.articles;
create trigger articles_unpublish_guard
  before update of status, published_at on guide.articles
  for each row execute function guide.articles_unpublish_guard();

revoke execute on function guide.articles_unpublish_guard() from public, anon, authenticated, service_role;
