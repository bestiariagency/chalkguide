-- F2.10 · Correcciones de leona-lia (docs/security/F2.10-guide-review.md): H1, H4 y H5 en opiniones/perfiles.
-- H1: el autor no puede borrar una opinión oculta (si no, la reabría borrando y reenviando).
-- H4: display_name saneado (sin etiquetas ni controles, máx. 40) en BD y al copiarlo de Google.
-- H5: user_id de user_reviews y user_profiles deja de ser público; el nombre visible se desnormaliza en author_name.

-- ───────────── H4: saneo de nombres ─────────────
create or replace function guide.sanitize_display_name(p_name text)
returns text
language plpgsql
immutable
set search_path = ''
as $$
declare
  v text;
begin
  v := regexp_replace(coalesce(p_name, ''), '[[:cntrl:]<>"`\\]', '', 'g');
  v := btrim(regexp_replace(v, '\s+', ' ', 'g'));
  v := btrim(left(v, 40));
  if char_length(v) < 2 then
    return null;
  end if;
  return v;
end;
$$;
revoke execute on function guide.sanitize_display_name(text) from public;

do $$ begin
  alter table guide.user_profiles
    add constraint user_profiles_display_name_safe check (display_name !~ '[[:cntrl:]<>"`\\]');
exception when duplicate_object then null; end $$;

-- ───────────── H5: nombre del autor desnormalizado en la opinión ─────────────
alter table guide.user_reviews add column if not exists author_name text not null default 'Escalador/a';
do $$ begin
  alter table guide.user_reviews
    add constraint user_reviews_author_name_safe
    check (char_length(author_name) between 2 and 40 and author_name !~ '[[:cntrl:]<>"`\\]');
exception when duplicate_object then null; end $$;

-- Si el usuario cambia su nombre, se actualiza en sus opiniones.
create or replace function guide.user_profiles_sync_author_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update guide.user_reviews set author_name = new.display_name
  where user_id = new.user_id and author_name is distinct from new.display_name;
  return null;
end;
$$;
revoke execute on function guide.user_profiles_sync_author_name() from public;

drop trigger if exists user_profiles_sync_author_name on guide.user_profiles;
create trigger user_profiles_sync_author_name after update of display_name on guide.user_profiles
  for each row execute function guide.user_profiles_sync_author_name();

-- Lectura pública por columnas: sin user_id.
revoke select on guide.user_reviews from anon, authenticated;
grant select (id, item_id, category, author_name, body, locale, status, edited_at, moderated_at, created_at, updated_at)
  on guide.user_reviews to anon, authenticated;

-- Perfiles: solo el propio (y admin). El público ve author_name en la opinión.
revoke select on guide.user_profiles from anon;
drop policy if exists user_profiles_select on guide.user_profiles;
create policy user_profiles_select on guide.user_profiles for select to authenticated
  using (user_id = (select auth.uid()) or (select guide.is_admin()));

-- Vista pública cómoda (permite select=* en PostgREST).
create or replace view guide.user_reviews_public with (security_invoker = true) as
select r.id, r.item_id, r.category, r.author_name, r.body, r.locale, r.status, r.edited_at, r.created_at
from guide.user_reviews r;
grant select on guide.user_reviews_public to anon, authenticated, service_role;

-- La exportación usa author_name (el admin tampoco lee user_id).
create or replace view guide.export_user_reviews with (security_invoker = true) as
select ur.id, ur.item_id, i.name as item_name, ur.category, ur.author_name as display_name, ur.status, ur.locale, ur.body,
  (select jsonb_object_agg(c.key, sc.score)
     from guide.user_review_scores sc join guide.criteria c on c.id = sc.criterion_id
    where sc.review_id = ur.id) as scores,
  ur.created_at, ur.edited_at, ur.moderated_at
from guide.user_reviews ur
join guide.items i on i.id = ur.item_id
where (select guide.is_admin());

-- ───────────── H1: no borrar la propia opinión oculta ─────────────
drop policy if exists user_reviews_delete on guide.user_reviews;
create policy user_reviews_delete on guide.user_reviews for delete to authenticated
  using ((user_id = (select auth.uid()) and status <> 'hidden') or (select guide.is_admin()));

-- ───────────── Mi opinión (sin exponer user_id) ─────────────
create or replace function guide.get_my_review(p_item_id uuid)
returns table (id uuid, status guide.review_status, body text, locale guide.locale, scores jsonb,
               created_at timestamptz, edited_at timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select r.id, r.status, r.body, r.locale,
    coalesce((select jsonb_object_agg(sc.criterion_id::text, sc.score)
              from guide.user_review_scores sc where sc.review_id = r.id), '{}'::jsonb),
    r.created_at, r.edited_at
  from guide.user_reviews r
  where r.item_id = p_item_id and r.user_id = (select auth.uid());
$$;
revoke execute on function guide.get_my_review(uuid) from public, anon;
grant execute on function guide.get_my_review(uuid) to authenticated, service_role;

-- ───────────── submit_user_review: nombre saneado y author_name ─────────────
-- Mantiene: una opinión 'hidden' sigue 'hidden' al editarla (no se reabre por upsert ni edición).
create or replace function guide.submit_user_review(
  p_item_id uuid,
  p_scores  jsonb,
  p_body    text default null,
  p_locale  guide.locale default 'es'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid       uuid := (select auth.uid());
  v_category  text;
  v_body      text := nullif(btrim(p_body), '');
  v_expected  integer;
  v_given     integer;
  v_valid     integer;
  v_premod    boolean;
  v_review_id uuid;
  v_name      text;
begin
  if v_uid is null then
    raise exception 'authentication required' using errcode = '42501';
  end if;

  select i.category into v_category
  from guide.items i
  join guide.item_categories c on c.key = i.category
  where i.id = p_item_id and i.published and c.is_active and c.allows_user_reviews;
  if v_category is null then
    raise exception 'item not reviewable' using errcode = '22023';
  end if;

  if v_body is not null and char_length(v_body) > 1000 then
    raise exception 'body too long' using errcode = '22023';
  end if;

  if p_scores is null or jsonb_typeof(p_scores) <> 'object' then
    raise exception 'invalid scores' using errcode = '22023';
  end if;
  select count(*) into v_expected from guide.criteria where category = v_category and is_active;
  select count(*) into v_given from jsonb_object_keys(p_scores);
  select count(*) into v_valid
  from jsonb_each(p_scores) s
  join guide.criteria c on c.id::text = s.key and c.category = v_category and c.is_active
  cross join lateral (
    select case when jsonb_typeof(s.value) = 'number' then (s.value)::numeric end as n
  ) v
  where v.n between 1 and 5 and v.n = trunc(v.n);
  if v_expected = 0 or v_given <> v_expected or v_valid <> v_expected then
    raise exception 'invalid scores' using errcode = '22023';
  end if;

  select coalesce(user_reviews_premoderation, false) into v_premod from guide.site_settings where id = 1;
  v_premod := coalesce(v_premod, false);

  -- Perfil: nombre de Google saneado; nunca el email.
  select guide.sanitize_display_name(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name'))
    into v_name
  from auth.users u where u.id = v_uid;
  insert into guide.user_profiles (user_id, display_name)
  values (v_uid, coalesce(v_name, 'Escalador/a'))
  on conflict (user_id) do nothing;
  select p.display_name into v_name from guide.user_profiles p where p.user_id = v_uid;

  select r.id into v_review_id
  from guide.user_reviews r
  where r.item_id = p_item_id and r.user_id = v_uid
  for update;

  if v_review_id is null then
    insert into guide.user_reviews (item_id, category, user_id, author_name, body, locale, status)
    values (p_item_id, v_category, v_uid, v_name, v_body, p_locale,
            case when v_premod then 'pending'::guide.review_status else 'visible'::guide.review_status end)
    returning id into v_review_id;
  else
    update guide.user_reviews
    set body = v_body,
        locale = p_locale,
        author_name = v_name,
        edited_at = now(),
        status = case
                   when status = 'hidden' then 'hidden'::guide.review_status
                   when v_premod then 'pending'::guide.review_status
                   else 'visible'::guide.review_status
                 end
    where id = v_review_id;
    delete from guide.user_review_scores where review_id = v_review_id;
  end if;

  insert into guide.user_review_scores (review_id, criterion_id, category, score)
  select v_review_id, s.key::uuid, v_category, ((s.value)::numeric)::smallint
  from jsonb_each(p_scores) s;

  return v_review_id;
end;
$$;
revoke execute on function guide.submit_user_review(uuid, jsonb, text, guide.locale) from public, anon;
grant execute on function guide.submit_user_review(uuid, jsonb, text, guide.locale) to authenticated, service_role;
