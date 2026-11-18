-- Corrección de hallazgos de leona-lia (docs/security/D17-D18-review.md).
-- B1: un display_name con '@' (o sus variantes ＠ U+FF20 y ﹫ U+FE6B) hacía que short_display_name
--     devolviera null y el trigger conservara el valor original, así que por PostgREST se podía guardar
--     un nombre completo o un email y publicarlo como author_name. Ahora se rechaza (23514) en el trigger
--     y en los CHECK de user_profiles.display_name y user_reviews.author_name.
-- I3: authenticated pasa de UPDATE de tabla en user_reviews a UPDATE solo de (status, moderated_at),
--     las únicas columnas que escribe guide.moderate_user_review (SECURITY INVOKER, assert_admin()).
--     submit_user_review y user_profiles_sync_author_name son SECURITY DEFINER (owner postgres): no les afecta.

-- B1 · trigger
create or replace function guide.user_profiles_short_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.display_name ~ '[@＠﹫]' then
    raise exception 'display_name must not contain @' using errcode = '23514';
  end if;
  new.display_name := coalesce(guide.short_display_name(new.display_name), new.display_name);
  return new;
end;
$$;
revoke execute on function guide.user_profiles_short_name() from public, anon, authenticated;

-- B1 · CHECK de respaldo (ninguna fila actual contiene '@')
alter table guide.user_profiles drop constraint if exists user_profiles_display_name_no_at;
alter table guide.user_profiles
  add constraint user_profiles_display_name_no_at check (display_name !~ '[@＠﹫]');

alter table guide.user_reviews drop constraint if exists user_reviews_author_name_no_at;
alter table guide.user_reviews
  add constraint user_reviews_author_name_no_at check (author_name !~ '[@＠﹫]');

-- I3 · grant de columna para moderar
revoke update on guide.user_reviews from authenticated;
grant update (status, moderated_at) on guide.user_reviews to authenticated;
