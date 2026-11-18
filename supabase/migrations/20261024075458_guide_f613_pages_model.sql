-- F6.13 (D34) · Páginas, parte 1: modelo de guide.pages.
-- Cinco claves cerradas e inmutables, sin INSERT/DELETE para clientes; slugs fijos (las rutas viven en
-- i18n/localized-routes.ts) y fuera de la lista blanca de borradores; has_en = título + cuerpo EN; legales solo texto,
-- siempre noindex y sin OG propia; revised_on (solo legales, lo fija la publicación); PT423 sobre lo publicado con las
-- exenciones atadas a la fila (apply:<page_id>) o a mantenimiento estricto (postgres + BYPASSRLS, como D33-1).
-- Idempotente.

-- ── Columna revised_on ────────────────────────────────────────────────────────────────────────────────────────────
alter table guide.pages add column if not exists revised_on date;
comment on column guide.pages.revised_on is
  'Última actualización visible de las legales (D34). La fija la publicación (primera vez o publish_draft con p_revision); nunca el cliente.';

-- ── has_en sin slug_en (D34, §10.5-1) ─────────────────────────────────────────────────────────────────────────────
alter table guide.pages alter column has_en set expression as
  ((title_en is not null) and (body_html_en is not null) and (body_html_en <> ''::text));
alter table guide.pages drop constraint if exists pages_en_coherent;

-- ── Datos: legales siempre noindex (antes del CHECK) y fila transparency sin publicar ────────────────────────────────
update guide.pages set noindex = true
where key in ('legal_notice', 'privacy', 'cookies') and not noindex;

insert into guide.pages (id, key, title_es, slug_es, slug_en, body_json_es, body_html_es, published)
values ('d0d0d0d0-0003-4000-8000-000000000005', 'transparency', 'Transparencia', 'transparencia', 'transparency',
        '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Texto provisional. La página de transparencia se redactará en F7.4b."}]}]}'::jsonb,
        '<p>Texto provisional. La página de transparencia se redactará en F7.4b.</p>', false)
on conflict (key) do nothing;

-- ── CHECKs puros (sin funciones que lean datos: draft_check_payload los evalúa con fila + parche) ──────────────────
alter table guide.pages drop constraint if exists pages_key_check;
alter table guide.pages drop constraint if exists pages_key_closed;
alter table guide.pages add constraint pages_key_closed
  check (key in ('about', 'transparency', 'privacy', 'cookies', 'legal_notice'));

alter table guide.pages drop constraint if exists pages_legal_fixed;
alter table guide.pages add constraint pages_legal_fixed
  check (key not in ('legal_notice', 'privacy', 'cookies') or (noindex and og_media_id is null));

-- Legales: solo texto (sin imagen, vídeo D26 ni tarjeta de ficha), en HTML y en el JSON de Tiptap, ES y EN.
alter table guide.pages drop constraint if exists pages_legal_text_only;
alter table guide.pages add constraint pages_legal_text_only
  check (key not in ('legal_notice', 'privacy', 'cookies') or (
    coalesce(body_html_es, '') !~* '<(img|iframe|video|audio|picture|source|embed|object)\M|<a\s[^>]*data-item-card'
    and coalesce(body_html_en, '') !~* '<(img|iframe|video|audio|picture|source|embed|object)\M|<a\s[^>]*data-item-card'
    and not coalesce(jsonb_path_exists(body_json_es,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard")'), false)
    and not coalesce(jsonb_path_exists(body_json_en,
          '$.** ? (@.type == "image" || @.type == "videoEmbed" || @.type == "itemCard")'), false)));

-- revised_on solo en legales; una legal publicada siempre la tiene. «No futura» va en el trigger (no es pura).
alter table guide.pages drop constraint if exists pages_revised_on_legal;
alter table guide.pages add constraint pages_revised_on_legal
  check ((revised_on is null or key in ('legal_notice', 'privacy', 'cookies'))
         and (not published or key not in ('legal_notice', 'privacy', 'cookies') or revised_on is not null));

-- ── Lista blanca de borradores: sin slugs ─────────────────────────────────────────────────────────────────────────
create or replace function guide.draft_allowed_columns(p_table text)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select case p_table
    when 'articles' then array[
      'category_id', 'title_es', 'title_en', 'slug_es', 'slug_en', 'excerpt_es', 'excerpt_en',
      'body_json_es', 'body_html_es', 'body_json_en', 'body_html_en', 'cover_media_id', 'is_featured',
      'seo_title_es', 'seo_title_en', 'seo_description_es', 'seo_description_en', 'og_media_id',
      'noindex', 'canonical_url']
    -- F6.13 (D34): sin slug_es/slug_en (rutas fijas en código); revised_on la fija la publicación, no el payload.
    when 'pages' then array[
      'title_es', 'title_en', 'body_json_es', 'body_html_es', 'body_json_en',
      'body_html_en', 'seo_title_es', 'seo_title_en', 'seo_description_es', 'seo_description_en',
      'og_media_id', 'noindex']
    when 'items' then array[
      'name', 'slug', 'summary_es', 'summary_en', 'cover_media_id', 'attributes', 'is_featured',
      'verified_at', 'source', 'source_url', 'seo_title_es', 'seo_title_en', 'seo_description_es',
      'seo_description_en', 'og_media_id', 'noindex']
    when 'gyms' then array[
      'address', 'city', 'district', 'postal_code', 'lat', 'lng', 'metro_stations', 'opening_hours',
      'opening_hours_note_es', 'opening_hours_note_en', 'website_url', 'instagram_url', 'phone',
      'price_registration_eur', 'price_day_eur', 'price_10_pass_eur', 'price_monthly_eur',
      'discounts_es', 'discounts_en', 'prices_verified_at', 'surface_m2', 'max_height_m', 'has_lead',
      'has_boulder', 'routes_count', 'autobelays_count', 'has_training_area', 'belay_test_required',
      'gear_rental', 'has_beginner_courses', 'has_cafe', 'serves_beer', 'has_kids_area', 'has_showers',
      'has_wifi', 'kids_min_age', 'grading_difficulty', 'setting_dynamism']
    when 'resolers' then array[
      'address', 'city', 'district', 'postal_code', 'lat', 'lng', 'website_url', 'instagram_url', 'phone',
      'price_per_pair_eur', 'price_rand_eur', 'turnaround_days_min', 'turnaround_days_max',
      'accepts_mail', 'mail_notes_es', 'mail_notes_en', 'rubber_brands', 'prices_verified_at', 'services']
    when 'shoes' then array[
      'brand', 'model', 'fit', 'profile', 'asymmetry', 'closure', 'rubber', 'rubber_thickness_mm',
      'stiffness', 'recommended_use', 'levels', 'price_min_eur', 'price_max_eur', 'price_checked_at',
      'affiliate_url', 'affiliate_program', 'owned_by_author', 'author_size_eu', 'author_street_size_eu',
      'author_size_note_es', 'author_size_note_en']
    when 'author_reviews' then array[
      'headline_es', 'headline_en', 'body_json_es', 'body_html_es', 'body_json_en', 'body_html_en',
      'visit_date', 'visit_type', 'disclosure_note_es', 'disclosure_note_en']
  end;
$$;

-- ── Exenciones (D33-1: mantenimiento = GUC + postgres + BYPASSRLS) ─────────────────────────────────────────────────
create or replace function guide.page_maintenance()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce(current_setting('guide.draft_op', true), '') = 'maintenance'
     and current_user = 'postgres'
     and coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false);
$$;

create or replace function guide.page_live_exempt(p_page_id uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select guide.page_maintenance()
      or (p_page_id is not null and coalesce(current_setting('guide.draft_op', true), '') = 'apply:' || p_page_id::text);
$$;

revoke all on function guide.page_maintenance() from public, anon;
revoke all on function guide.page_live_exempt(uuid) from public, anon;
grant execute on function guide.page_maintenance() to authenticated, service_role;
grant execute on function guide.page_live_exempt(uuid) to authenticated, service_role;

-- ── Trigger de escritura: clave/slugs inmutables, revised_on, PT423 ───────────────────────────────────────────────
create or replace function guide.pages_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  c_legal   constant text[] := array['legal_notice', 'privacy', 'cookies'];
  v_maint   boolean := guide.page_maintenance();
  v_today   date := (now() at time zone 'Europe/Madrid')::date;
  v_changed text[];
begin
  if tg_op = 'UPDATE' then
    if new.id is distinct from old.id then
      raise exception 'page id is immutable' using errcode = '22023';
    end if;
    if new.key is distinct from old.key then
      raise exception 'page key is immutable' using errcode = '22023',
        hint = 'The five pages are fixed (D34).';
    end if;
    if not v_maint and (new.slug_es, new.slug_en) is distinct from (old.slug_es, old.slug_en) then
      raise exception 'page slugs are fixed' using errcode = '22023',
        hint = 'Page routes live in i18n/localized-routes.ts (D34).';
    end if;
  end if;

  -- revised_on nunca llega del cliente: la fija la publicación (abajo). Mantenimiento puede corregirla, no a futuro.
  if (tg_op = 'INSERT' and new.revised_on is not null)
     or (tg_op = 'UPDATE' and new.revised_on is distinct from old.revised_on) then
    if new.revised_on > v_today then
      raise exception 'revised_on in the future' using errcode = '23514', constraint = 'pages_revised_on_not_future';
    end if;
    if not v_maint then
      raise exception 'revised_on is set on publish' using errcode = '42501',
        hint = 'Choose it with publish_draft(p_revision => ''today'' | ''keep'').';
    end if;
  end if;

  -- Publicada antes y después: el contenido solo cambia vía borrador de cambios (publish_draft fija apply:<id>).
  if tg_op = 'UPDATE' and old.published and new.published and not guide.page_live_exempt(old.id) then
    select array_agg(k order by k) into v_changed
    from unnest(guide.draft_allowed_columns('pages')) k
    where (to_jsonb(new) -> k) is distinct from (to_jsonb(old) -> k);
    if v_changed is not null then
      raise exception 'page is live'
        using errcode = 'PT423',
              detail = 'changed: ' || array_to_string(v_changed, ', '),
              hint = 'Edit a published page through save_draft/publish_draft, or unpublish it first (unpublish_page).';
    end if;
  end if;

  -- Última actualización de las legales: hoy en la primera publicación; en publish_draft, hoy si cambian título o
  -- cuerpo, salvo «Mantener la anterior» (guide.page_revision = '<id>:keep', solo dentro de apply:<id>).
  if new.key = any (c_legal) and new.published then
    if v_maint then
      new.revised_on := coalesce(new.revised_on, v_today);
    elsif tg_op = 'INSERT' or not old.published then
      new.revised_on := v_today;
    elsif (new.title_es, new.title_en, new.body_json_es, new.body_html_es, new.body_json_en, new.body_html_en)
          is distinct from (old.title_es, old.title_en, old.body_json_es, old.body_html_es, old.body_json_en, old.body_html_en) then
      if old.revised_on is not null
         and coalesce(current_setting('guide.page_revision', true), '') = old.id::text || ':keep'
         and coalesce(current_setting('guide.draft_op', true), '') = 'apply:' || old.id::text then
        new.revised_on := old.revised_on;
      else
        new.revised_on := v_today;
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists pages_before_write on guide.pages;
create trigger pages_before_write
  before insert or update on guide.pages
  for each row execute function guide.pages_before_write();

-- ── Despublicar: legales nunca; con borrador pendiente, solo vía unpublish_page ───────────────────────────────────
create or replace function guide.pages_unpublish_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if guide.page_maintenance() then
    return new;
  end if;
  if old.key in ('legal_notice', 'privacy', 'cookies') then
    raise exception 'legal_page_cannot_unpublish'
      using errcode = 'PT423',
            detail = old.key,
            hint = 'Published legal pages stay published (D34); correct them through a draft of changes.';
  end if;
  if not guide.alt_unpublish_bypassed(old.id)
     and exists (select 1 from guide.content_drafts d where d.entity = 'page' and d.entity_id = old.id) then
    raise exception 'pending draft'
      using errcode = 'PT423',
            detail = 'use unpublish_page',
            hint = 'Unpublish through unpublish_page (applies the pending draft), or discard the draft first.';
  end if;
  return new;
end;
$$;

drop trigger if exists pages_unpublish_guard on guide.pages;
create trigger pages_unpublish_guard
  before update on guide.pages
  for each row when (old.published and not new.published)
  execute function guide.pages_unpublish_guard();

-- ── Borrar: nunca (salvo mantenimiento estricto) ──────────────────────────────────────────────────────────────────
create or replace function guide.pages_before_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not guide.page_maintenance() then
    raise exception 'pages are fixed' using errcode = '42501',
      hint = 'The five pages cannot be deleted (D34).';
  end if;
  return old;
end;
$$;

drop trigger if exists pages_before_delete on guide.pages;
create trigger pages_before_delete
  before delete on guide.pages
  for each row execute function guide.pages_before_delete();

revoke all on function guide.pages_before_write() from public, anon, authenticated;
revoke all on function guide.pages_unpublish_guard() from public, anon, authenticated;
revoke all on function guide.pages_before_delete() from public, anon, authenticated;

-- ── Sin INSERT ni DELETE para clientes (ni admin) ─────────────────────────────────────────────────────────────────
drop policy if exists pages_insert on guide.pages;
drop policy if exists pages_delete on guide.pages;
revoke insert, delete, truncate on guide.pages from anon, authenticated;
