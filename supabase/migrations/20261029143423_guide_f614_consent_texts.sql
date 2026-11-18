-- F6.14 (D35) · Suscriptores, parte 5: guide.consent_texts guarda el texto exacto de cada versión del consentimiento
-- de la newsletter (la ficha lo cita en «Ver el texto exacto»). Append-only (solo se cierra valid_to de la vigente),
-- solo SELECT de admin. La escribe el trigger de site_settings: cambiar el texto sin subir consent_version da error;
-- subirla cierra la versión vigente e inserta la nueva. Relleno: la versión actual con el texto actual y las
-- anteriores como «no conservado» (preserved = false, sin texto). Idempotente.

create table if not exists guide.consent_texts (
  version    integer primary key,
  text_es    text,
  text_en    text,
  preserved  boolean not null default true,
  valid_from timestamptz not null default now(),
  valid_to   timestamptz,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint consent_texts_version_check check (version >= 1),
  constraint consent_texts_text_es_check check (text_es is null or char_length(text_es) between 1 and 2000),
  constraint consent_texts_text_en_check check (text_en is null or char_length(text_en) between 1 and 2000),
  constraint consent_texts_preserved_check check (preserved = (text_es is not null)),
  constraint consent_texts_valid_range_check check (valid_to is null or valid_to >= valid_from)
);
create index if not exists consent_texts_created_by_idx on guide.consent_texts (created_by);
create unique index if not exists consent_texts_one_open_idx on guide.consent_texts ((true)) where valid_to is null;

alter table guide.consent_texts enable row level security;
revoke all on guide.consent_texts from public, anon, authenticated;
grant select on guide.consent_texts to authenticated;
drop policy if exists consent_texts_select on guide.consent_texts;
create policy consent_texts_select on guide.consent_texts for select to authenticated
  using ((select guide.is_admin()));

create or replace function guide.consent_texts_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and old.valid_to is null and new.valid_to is not null
     and (to_jsonb(new) - 'valid_to') = (to_jsonb(old) - 'valid_to') then
    return new;
  end if;
  raise exception 'consent_texts is append-only' using errcode = '42501';
end;
$$;
drop trigger if exists consent_texts_guard on guide.consent_texts;
create trigger consent_texts_guard before update or delete on guide.consent_texts
  for each row execute function guide.consent_texts_guard();
drop trigger if exists consent_texts_no_truncate on guide.consent_texts;
create trigger consent_texts_no_truncate before truncate on guide.consent_texts
  for each statement execute function guide.consent_texts_guard();

-- Relleno (solo si la tabla está vacía).
do $$
declare
  v_s guide.site_settings%rowtype;
  v_v integer;
begin
  if exists (select 1 from guide.consent_texts) then
    return;
  end if;
  select * into v_s from guide.site_settings where id = 1;
  if not found then
    return;
  end if;
  -- Versiones anteriores: su texto no se guardó. Desde la creación del schema (2026-10-04) hasta el último cambio de
  -- ajustes (cuando se subió la versión).
  for v_v in 1 .. v_s.consent_version - 1 loop
    insert into guide.consent_texts (version, text_es, text_en, preserved, valid_from, valid_to)
    values (v_v, null, null, false, timestamptz '2026-10-04 00:00:00+00',
            greatest(timestamptz '2026-10-04 00:00:00+00', v_s.updated_at));
  end loop;
  insert into guide.consent_texts (version, text_es, text_en, preserved, valid_from, valid_to)
  values (v_s.consent_version, v_s.newsletter_consent_text_es, case when btrim(v_s.newsletter_consent_text_en) <> '' then v_s.newsletter_consent_text_en end, true,
          greatest(timestamptz '2026-10-04 00:00:00+00', v_s.updated_at), null);
end $$;

create or replace function guide.site_settings_consent_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.consent_version < old.consent_version then
    raise exception 'consent_version_cannot_decrease' using errcode = '22023';
  end if;
  if new.consent_version = old.consent_version then
    if new.newsletter_consent_text_es is distinct from old.newsletter_consent_text_es
       or new.newsletter_consent_text_en is distinct from old.newsletter_consent_text_en then
      raise exception 'consent_text_requires_version_bump' using errcode = '22023',
        hint = 'Changing the newsletter consent text requires increasing consent_version.';
    end if;
    return new;
  end if;
  if exists (select 1 from guide.consent_texts c where c.version >= new.consent_version) then
    raise exception 'consent_version_already_used' using errcode = '22023';
  end if;
  update guide.consent_texts set valid_to = now() where valid_to is null;
  insert into guide.consent_texts (version, text_es, text_en, preserved, valid_from, created_by)
  values (new.consent_version, new.newsletter_consent_text_es, case when btrim(new.newsletter_consent_text_en) <> '' then new.newsletter_consent_text_en end, true,
          now(), (select auth.uid()));
  return new;
end;
$$;
revoke all on function guide.site_settings_consent_version() from public, anon, authenticated;
revoke all on function guide.consent_texts_guard() from public, anon, authenticated;

drop trigger if exists site_settings_consent_version on guide.site_settings;
create trigger site_settings_consent_version before update on guide.site_settings
  for each row execute function guide.site_settings_consent_version();
