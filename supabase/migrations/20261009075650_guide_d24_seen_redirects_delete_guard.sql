-- D24 (F6) · Panel: última visita a Opiniones por cuenta, redirecciones automáticas de slugs
-- publicados y bloqueo del borrado de fichas con opiniones. Idempotente.

-- ═════════════ 1. Última visita a Opiniones (guide.admins.reviews_seen_at) ═════════════

alter table guide.admins add column if not exists reviews_seen_at timestamptz;

-- Marcar la visita no es actividad editorial: el registro solo sigue altas, bajas y cambios de identidad.
drop trigger if exists admins_log_activity on guide.admins;
create trigger admins_log_activity
  after insert or delete or update of user_id, email on guide.admins
  for each row execute function guide.log_activity('user_id', 'email', 'true');

-- Sin UPDATE directo sobre admins: la única escritura es esta RPC, y solo sobre la fila de quien llama.
-- Devuelve la marca ANTERIOR (null = nunca), para resaltar lo nuevo desde la última visita en una sola llamada.
create or replace function guide.mark_reviews_seen()
returns timestamptz
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_uid  uuid := (select auth.uid());
  v_prev timestamptz;
begin
  if v_uid is null or not guide.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
  select a.reviews_seen_at into v_prev from guide.admins a where a.user_id = v_uid for update;
  update guide.admins set reviews_seen_at = now() where user_id = v_uid;
  return v_prev;
end;
$$;
revoke execute on function guide.mark_reviews_seen() from public, anon;
grant execute on function guide.mark_reviews_seen() to authenticated, service_role;

-- ═════════════ 2. Redirecciones de slugs (guide.slug_redirects) ═════════════
-- Cada fila apunta a la ENTIDAD (no a otro slug): resolver da siempre el slug actual, sin cadenas ni bucles.
-- kind: 'article' | 'article_category' | 'page' (con locale) | 'item' (sin locale; slug único por categoría).

create table if not exists guide.slug_redirects (
  id                  bigint generated always as identity primary key,
  kind                text not null,
  locale              guide.locale,
  item_category       text,
  old_slug            guide.slug not null,
  article_id          uuid references guide.articles (id) on delete cascade,
  article_category_id uuid references guide.article_categories (id) on delete cascade,
  page_id             uuid references guide.pages (id) on delete cascade,
  item_id             uuid,
  created_at          timestamptz not null default now(),
  constraint slug_redirects_item_fk foreign key (item_id, item_category)
    references guide.items (id, category) on update cascade on delete cascade,
  constraint slug_redirects_kind_check check (kind in ('article', 'article_category', 'page', 'item')),
  constraint slug_redirects_target_check check (
    num_nonnulls(article_id, article_category_id, page_id, item_id) = 1
    and case kind
      when 'article'          then article_id is not null and locale is not null and item_category is null
      when 'article_category' then article_category_id is not null and locale is not null and item_category is null
      when 'page'             then page_id is not null and locale is not null and item_category is null
      when 'item'             then item_id is not null and item_category is not null and locale is null
    end
  ),
  constraint slug_redirects_key unique nulls not distinct (kind, locale, item_category, old_slug)
);
alter table guide.slug_redirects enable row level security;

create index if not exists slug_redirects_article_id_idx on guide.slug_redirects (article_id) where article_id is not null;
create index if not exists slug_redirects_article_category_id_idx on guide.slug_redirects (article_category_id) where article_category_id is not null;
create index if not exists slug_redirects_page_id_idx on guide.slug_redirects (page_id) where page_id is not null;
create index if not exists slug_redirects_item_idx on guide.slug_redirects (item_id, item_category) where item_id is not null;

-- Lectura pública solo vía resolve_redirect(). El admin puede ver y borrar (panel); nadie inserta ni edita a mano.
grant select, delete on guide.slug_redirects to authenticated;
grant all on guide.slug_redirects to service_role;

drop policy if exists slug_redirects_select on guide.slug_redirects;
create policy slug_redirects_select on guide.slug_redirects
  for select to authenticated
  using ((select guide.is_admin()));

drop policy if exists slug_redirects_delete on guide.slug_redirects;
create policy slug_redirects_delete on guide.slug_redirects
  for delete to authenticated
  using ((select guide.is_admin()));

-- Trigger AFTER INSERT/UPDATE OF slug en articles, article_categories, pages e items.
--  · Un slug vivo gana: al asignarse un slug (alta, cambio o vuelta atrás A→B→A) se borra cualquier redirección
--    con ese slug, sea de la propia entidad o de otra.
--  · Si la entidad era pública ANTES del cambio (y, en en, tenía versión inglesa), el slug antiguo se guarda.
-- SECURITY DEFINER: escribe en slug_redirects, que no tiene policies de escritura.
create or replace function guide.track_slug_redirects()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new      jsonb := to_jsonb(new);
  v_old      jsonb;
  v_kind     text;
  v_id       uuid := (v_new ->> 'id')::uuid;
  v_was_live boolean;
  v_loc      text;
  v_new_slug text;
  v_old_slug text;
begin
  if tg_op = 'UPDATE' then v_old := to_jsonb(old); end if;

  if tg_table_name = 'items' then
    delete from guide.slug_redirects r
    where r.kind = 'item' and r.item_category = new.category and r.old_slug = new.slug;
    -- Cambio de categoría: la URL cambia de sección; no se redirige (las redirecciones existentes la siguen por FK).
    if tg_op = 'UPDATE' and old.published and old.category = new.category and old.slug is distinct from new.slug then
      insert into guide.slug_redirects (kind, item_category, old_slug, item_id)
      values ('item', new.category, old.slug, new.id)
      on conflict on constraint slug_redirects_key
      do update set item_id = excluded.item_id, created_at = now();
    end if;
    return null;
  end if;

  v_kind := case tg_table_name
    when 'articles' then 'article'
    when 'article_categories' then 'article_category'
    when 'pages' then 'page'
  end;
  if v_kind is null then
    raise exception 'track_slug_redirects: unsupported table %', tg_table_name;
  end if;

  if tg_op = 'UPDATE' then
    v_was_live := case v_kind
      when 'article' then guide.article_is_live((v_old ->> 'status')::guide.article_status,
                                                (v_old ->> 'published_at')::timestamptz)
      when 'page' then (v_old ->> 'published')::boolean
      else true -- las categorías del blog son siempre públicas
    end;
  end if;

  foreach v_loc in array array['es', 'en'] loop
    v_new_slug := v_new ->> ('slug_' || v_loc);
    if v_new_slug is not null then
      delete from guide.slug_redirects r
      where r.kind = v_kind and r.locale = v_loc::guide.locale and r.old_slug = v_new_slug;
    end if;

    if tg_op = 'UPDATE' then
      v_old_slug := v_old ->> ('slug_' || v_loc);
      if v_old_slug is not null and v_old_slug is distinct from v_new_slug and v_was_live
         and (v_loc = 'es' or coalesce((v_old ->> 'has_en')::boolean, false)) then
        insert into guide.slug_redirects (kind, locale, old_slug, article_id, article_category_id, page_id)
        values (v_kind, v_loc::guide.locale, v_old_slug,
                case when v_kind = 'article' then v_id end,
                case when v_kind = 'article_category' then v_id end,
                case when v_kind = 'page' then v_id end)
        on conflict on constraint slug_redirects_key
        do update set article_id = excluded.article_id, article_category_id = excluded.article_category_id,
                      page_id = excluded.page_id, created_at = now();
      end if;
    end if;
  end loop;
  return null;
end;
$$;
revoke execute on function guide.track_slug_redirects() from public, anon, authenticated;

drop trigger if exists articles_track_slug_redirects on guide.articles;
create trigger articles_track_slug_redirects
  after insert or update of slug_es, slug_en on guide.articles
  for each row execute function guide.track_slug_redirects();

drop trigger if exists article_categories_track_slug_redirects on guide.article_categories;
create trigger article_categories_track_slug_redirects
  after insert or update of slug_es, slug_en on guide.article_categories
  for each row execute function guide.track_slug_redirects();

drop trigger if exists pages_track_slug_redirects on guide.pages;
create trigger pages_track_slug_redirects
  after insert or update of slug_es, slug_en on guide.pages
  for each row execute function guide.track_slug_redirects();

drop trigger if exists items_track_slug_redirects on guide.items;
create trigger items_track_slug_redirects
  after insert or update of slug, category on guide.items
  for each row execute function guide.track_slug_redirects();

-- Resuelve una URL antigua. p_kind: 'article' | 'article_category' | 'page' | clave de item_categories
-- ('gym', 'resoler', 'shoe'…). Devuelve el slug actual en ese locale o null. Nunca devuelve el slug de algo
-- no público (borrador, programado, oculto, o sin versión inglesa cuando p_locale = 'en') ni el propio p_slug.
create or replace function guide.resolve_redirect(p_kind text, p_locale text, p_slug text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_locale guide.locale;
  v_slug   text;
begin
  if p_locale is null or p_locale not in ('es', 'en') then
    raise exception 'invalid locale' using errcode = '22023';
  end if;
  if p_kind is null then
    raise exception 'invalid kind' using errcode = '22023';
  end if;
  if p_slug is null or length(p_slug) > 200 then
    return null;
  end if;
  v_locale := p_locale::guide.locale;

  if p_kind = 'article' then
    select case v_locale when 'es' then a.slug_es else a.slug_en end into v_slug
    from guide.slug_redirects r
    join guide.articles a on a.id = r.article_id
    where r.kind = 'article' and r.locale = v_locale and r.old_slug = p_slug
      and guide.article_is_live(a.status, a.published_at)
      and (v_locale = 'es' or a.has_en);
  elsif p_kind = 'article_category' then
    select case v_locale when 'es' then c.slug_es else c.slug_en end into v_slug
    from guide.slug_redirects r
    join guide.article_categories c on c.id = r.article_category_id
    where r.kind = 'article_category' and r.locale = v_locale and r.old_slug = p_slug
      and (v_locale = 'es' or c.has_en);
  elsif p_kind = 'page' then
    select case v_locale when 'es' then p.slug_es else p.slug_en end into v_slug
    from guide.slug_redirects r
    join guide.pages p on p.id = r.page_id
    where r.kind = 'page' and r.locale = v_locale and r.old_slug = p_slug
      and p.published
      and (v_locale = 'es' or p.has_en);
  elsif exists (select 1 from guide.item_categories ic where ic.key = p_kind) then
    select i.slug into v_slug
    from guide.slug_redirects r
    join guide.items i on i.id = r.item_id and i.category = r.item_category
    where r.kind = 'item' and r.item_category = p_kind and r.old_slug = p_slug
      and i.published;
  else
    raise exception 'invalid kind' using errcode = '22023';
  end if;

  if v_slug is null or v_slug = p_slug then
    return null;
  end if;
  return v_slug;
end;
$$;
revoke execute on function guide.resolve_redirect(text, text, text) from public;
grant execute on function guide.resolve_redirect(text, text, text) to anon, authenticated, service_role;

-- ═════════════ 3. Fichas con opiniones no se borran ═════════════
-- Error estable para el panel: SQLSTATE 23503, message 'item has user reviews'. Cuenta también las ocultas.
-- SECURITY DEFINER: la comprobación no depende de lo que la RLS deje ver a quien borra.
create or replace function guide.items_block_delete_with_reviews()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (select 1 from guide.user_reviews r where r.item_id = old.id) then
    raise exception 'item has user reviews'
      using errcode = '23503',
            detail = 'La ficha tiene opiniones de usuarios (incluidas las ocultas).',
            hint = 'Las fichas con opiniones no se borran: ocúltala o despublícala.';
  end if;
  return old;
end;
$$;
revoke execute on function guide.items_block_delete_with_reviews() from public, anon, authenticated;

drop trigger if exists items_block_delete_with_reviews on guide.items;
create trigger items_block_delete_with_reviews
  before delete on guide.items
  for each row execute function guide.items_block_delete_with_reviews();

-- Defensa en profundidad: la FK deja de borrar opiniones en cascada (antes ON DELETE CASCADE).
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conname = 'user_reviews_item_fk' and conrelid = 'guide.user_reviews'::regclass and confdeltype <> 'r'
  ) then
    alter table guide.user_reviews drop constraint user_reviews_item_fk;
    alter table guide.user_reviews
      add constraint user_reviews_item_fk foreign key (item_id, category)
      references guide.items (id, category) on delete restrict;
  end if;
end $$;
