-- F2.6 · RPC públicas (validadas, SECURITY DEFINER) y RPC del panel (SECURITY INVOKER + assert_admin).

-- ═════════════ Públicas ═════════════

-- Alta/edición de la opinión propia (única vía de escritura de user_reviews/user_review_scores).
-- p_scores: {"<criterion_id>": 1..5, ...} con exactamente los criterios activos de la categoría.
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

  -- Perfil público mínimo (nombre de Google si existe; nunca el email).
  select left(btrim(coalesce(u.raw_user_meta_data ->> 'full_name', u.raw_user_meta_data ->> 'name', '')), 40)
    into v_name
  from auth.users u where u.id = v_uid;
  if v_name is null or char_length(v_name) < 2 then
    v_name := 'Escalador/a';
  end if;
  insert into guide.user_profiles (user_id, display_name)
  values (v_uid, v_name)
  on conflict (user_id) do nothing;

  select id into v_review_id
  from guide.user_reviews
  where item_id = p_item_id and user_id = v_uid
  for update;

  if v_review_id is null then
    insert into guide.user_reviews (item_id, category, user_id, body, locale, status)
    values (p_item_id, v_category, v_uid, v_body, p_locale,
            case when v_premod then 'pending'::guide.review_status else 'visible'::guide.review_status end)
    returning id into v_review_id;
  else
    update guide.user_reviews
    set body = v_body,
        locale = p_locale,
        edited_at = now(),
        -- Editar no reaparece una opinión ocultada por el admin.
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

-- Alta de newsletter con consentimiento explícito (RGPD). Doble opt-in: queda 'pending'
-- hasta que la Edge Function de Brevo (F4.6) confirme. Respuesta neutra: no revela si el email existía.
create or replace function guide.subscribe_newsletter(
  p_email   text,
  p_locale  guide.locale,
  p_source  text,
  p_consent boolean,
  p_page    text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email   text := lower(btrim(p_email));
  v_page    text := case when p_page ~ '^/' then left(p_page, 300) end;
  v_version integer;
begin
  if p_consent is not true then
    raise exception 'consent required' using errcode = '22023';
  end if;
  if v_email is null or char_length(v_email) > 254 or v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'invalid email' using errcode = '22023';
  end if;
  if p_source is null or p_source not in ('footer', 'article', 'item_page', 'home', 'popup') then
    raise exception 'invalid source' using errcode = '22023';
  end if;

  select consent_version into v_version from guide.site_settings where id = 1;

  insert into guide.subscribers (email, status, locale, consent_at, consent_source, consent_version, consent_page, user_id)
  values (v_email, 'pending', coalesce(p_locale, 'es'), now(), p_source, coalesce(v_version, 1), v_page, (select auth.uid()))
  on conflict (email) do update
    set status             = 'pending',
        locale             = excluded.locale,
        consent_at         = excluded.consent_at,
        consent_source     = excluded.consent_source,
        consent_version    = excluded.consent_version,
        consent_page       = excluded.consent_page,
        confirmed_at       = null,
        unsubscribed_at    = null,
        unsubscribe_source = null,
        user_id            = coalesce(guide.subscribers.user_id, excluded.user_id)
    -- Un suscriptor activo no se toca; pending/unsubscribed/bounced renuevan consentimiento.
    where guide.subscribers.status <> 'active';
end;
$$;
revoke execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) from public;
grant execute on function guide.subscribe_newsletter(text, guide.locale, text, boolean, text) to anon, authenticated, service_role;

-- Baja por enlace (token del email). Respuesta neutra.
create or replace function guide.unsubscribe_newsletter(p_token uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_token is null then
    return;
  end if;
  update guide.subscribers
  set status = 'unsubscribed', unsubscribed_at = now(), unsubscribe_source = 'link'
  where unsubscribe_token = p_token and status <> 'unsubscribed';
end;
$$;
revoke execute on function guide.unsubscribe_newsletter(uuid) from public;
grant execute on function guide.unsubscribe_newsletter(uuid) to anon, authenticated, service_role;

-- ═════════════ Panel (admin) ═════════════

create or replace function guide.delete_article_category(p_id uuid, p_reassign_to uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_offset integer;
begin
  perform guide.assert_admin();
  if p_id = p_reassign_to then
    raise exception 'target must differ' using errcode = '22023';
  end if;
  if not exists (select 1 from guide.article_categories where id = p_reassign_to) then
    raise exception 'target category not found' using errcode = '22023';
  end if;
  select coalesce(max(sort_order), 0) + 1 into v_offset from guide.articles where category_id = p_reassign_to;
  update guide.articles
  set category_id = p_reassign_to, sort_order = sort_order + v_offset
  where category_id = p_id;
  delete from guide.article_categories where id = p_id;
end;
$$;

create or replace function guide.reorder_article_categories(p_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.article_categories c
  set sort_order = x.ord::integer
  from unnest(p_ids) with ordinality as x(id, ord)
  where c.id = x.id;
end;
$$;

create or replace function guide.reorder_articles(p_category_id uuid, p_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if exists (
    select 1 from unnest(p_ids) as u(id)
    left join guide.articles a on a.id = u.id and a.category_id = p_category_id
    where a.id is null
  ) then
    raise exception 'articles must belong to the category' using errcode = '22023';
  end if;
  update guide.articles a
  set sort_order = x.ord::integer
  from unnest(p_ids) with ordinality as x(id, ord)
  where a.id = x.id;
end;
$$;

create or replace function guide.reorder_criteria(p_category text, p_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  if exists (
    select 1 from unnest(p_ids) as u(id)
    left join guide.criteria c on c.id = u.id and c.category = p_category
    where c.id is null
  ) then
    raise exception 'criteria must belong to the category' using errcode = '22023';
  end if;
  update guide.criteria c
  set sort_order = x.ord::integer
  from unnest(p_ids) with ordinality as x(id, ord)
  where c.id = x.id;
end;
$$;

create or replace function guide.reorder_item_media(p_item_id uuid, p_media_ids uuid[])
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.item_media m
  set sort_order = x.ord::integer
  from unnest(p_media_ids) with ordinality as x(id, ord)
  where m.item_id = p_item_id and m.media_id = x.id;
end;
$$;

create or replace function guide.moderate_user_review(p_id uuid, p_status guide.review_status)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.user_reviews
  set status = p_status, moderated_at = now(), moderated_by = (select auth.uid())
  where id = p_id;
end;
$$;

create or replace function guide.approve_event(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.events
  set status = 'approved', approved_at = now(), approved_by = (select auth.uid())
  where id = p_id;
end;
$$;

create or replace function guide.reject_event(p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.events
  set status = 'rejected', approved_at = null, approved_by = null
  where id = p_id;
end;
$$;

-- Normaliza programados vencidos. La llama la tarea programada de F4 (service_role) antes del build hook.
create or replace function guide.publish_due_articles()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_count integer;
begin
  update guide.articles
  set status = 'published'
  where status = 'scheduled' and published_at <= now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Grants del panel
do $$
declare f text;
begin
  foreach f in array array[
    'guide.delete_article_category(uuid, uuid)',
    'guide.reorder_article_categories(uuid[])',
    'guide.reorder_articles(uuid, uuid[])',
    'guide.reorder_criteria(text, uuid[])',
    'guide.reorder_item_media(uuid, uuid[])',
    'guide.moderate_user_review(uuid, guide.review_status)',
    'guide.approve_event(uuid)',
    'guide.reject_event(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated, service_role', f);
  end loop;
end $$;

revoke execute on function guide.publish_due_articles() from public, anon, authenticated;
grant execute on function guide.publish_due_articles() to service_role;
