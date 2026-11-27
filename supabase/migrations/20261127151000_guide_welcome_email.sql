-- Newsletter › Email de bienvenida (README §21; docs/security/F4.6-brevo-spec.md, apéndice «Email de bienvenida»).
-- Paso 2/2.
--   · guide.newsletter_welcome: fila única con la versión publicada (columnas por idioma, CHECK de §21.3) y el borrador
--     de cambios (patrón D23: base_updated_at + PT409) en la misma fila. Sin grants de tabla: solo RPC.
--   · Validación compartida (CHECK, guardar, publicar y prueba): welcome_link_ok, welcome_body_stats, welcome_normalize,
--     welcome_errors. Cuerpo = JSON de Tiptap con lista blanca doc/paragraph/text/bulletList/listItem/hardBreak y marcas
--     bold/italic/link (https o ruta del sitio).
--   · Encolado solo en confirm_newsletter (doble opt-in): una vez por fila (subscribers.welcome_sent_at), sin PII en el
--     outbox. Reactivaciones de admin e importaciones no existen (D35) y, si existieran, no encolan.
--   · svc_welcome_prepare (service_role) y cierre en svc_outbox_done (welcome_sent_at + evento welcome_sent).
--   · C4 extendido: un welcome_email con lock caducado no se reclama (pudo salir ya).
--   · Cupo: welcome y pruebas cuentan en newsletter_sent_today.
--   · RPC admin: admin_get_welcome_email, admin_welcome_save_draft, admin_welcome_discard_draft, admin_welcome_publish,
--     admin_welcome_set_enabled, admin_welcome_test_prepare (la usa la EF newsletter-welcome-test con el JWT del admin).
-- Idempotente. Cero cambios en public.

-- ───────────── 1. Validación (inmutable) ─────────────

create or replace function guide.welcome_link_ok(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is not null and char_length(p) <= 2000 and (
    p ~ '^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?([/?#][^[:space:]"''<>\\]*)?$'
    or p ~ '^/([A-Za-z0-9._~%-][A-Za-z0-9._~/%-]*)?$');
$$;

-- Línea de texto plano: sin caracteres de control (ni saltos de línea) y con tope.
create or replace function guide.welcome_line_ok(p text, p_max integer)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is null or (char_length(p) between 1 and p_max and p !~ '[[:cntrl:]]');
$$;

create or replace function guide.welcome_signature_ok(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is null or (char_length(p) between 1 and 120 and translate(p, E'\n', '') !~ '[[:cntrl:]]'
                       and array_length(string_to_array(p, E'\n'), 1) <= 2);
$$;

create or replace function guide.welcome_items_ok(p text[])
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p is not null and coalesce(cardinality(p), 0) <= 6
     and not exists (select 1 from unnest(p) i where not guide.welcome_line_ok(i, 140) or i is null or btrim(i) = '');
$$;

-- {longitud del texto, nodo/marca no permitida, enlace no válido, nº de nodos}. Recorre todo el árbol.
create or replace function guide.welcome_body_stats(p_node jsonb, p_depth integer default 0)
returns integer[]
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_len integer := 0;
  v_bad integer := 0;
  v_url integer := 0;
  v_n   integer := 1;
  r     integer[];
  c     jsonb;
  m     jsonb;
  t     text;
begin
  if p_depth > 12 or jsonb_typeof(p_node) is distinct from 'object' then
    return array[0, 1, 0, 1];
  end if;
  t := p_node ->> 'type';
  if t is null or t not in ('doc', 'paragraph', 'text', 'bulletList', 'listItem', 'hardBreak')
     or (p_depth = 0) is distinct from (t = 'doc') then
    v_bad := 1;
  end if;
  if exists (select 1 from jsonb_object_keys(p_node) k where k not in ('type', 'content', 'text', 'marks', 'attrs')) then
    v_bad := 1;
  end if;
  if t = 'text' then
    if jsonb_typeof(p_node -> 'text') is distinct from 'string' or p_node ? 'content' then
      v_bad := 1;
    else
      v_len := char_length(p_node ->> 'text');
    end if;
  elsif p_node ? 'text' or p_node ? 'marks' then
    v_bad := 1;
  end if;
  if p_node ? 'marks' then
    if jsonb_typeof(p_node -> 'marks') is distinct from 'array' or jsonb_array_length(p_node -> 'marks') > 3 then
      v_bad := 1;
    else
      for m in select e from jsonb_array_elements(p_node -> 'marks') e loop
        if jsonb_typeof(m) is distinct from 'object' or coalesce(m ->> 'type', '') not in ('bold', 'italic', 'link') then
          v_bad := 1;
        elsif m ->> 'type' = 'link' and not guide.welcome_link_ok(m -> 'attrs' ->> 'href') then
          v_url := 1;
        end if;
      end loop;
    end if;
  end if;
  if p_node ? 'content' then
    if jsonb_typeof(p_node -> 'content') is distinct from 'array' or t in ('text', 'hardBreak')
       or jsonb_array_length(p_node -> 'content') > 500 then
      v_bad := 1;
    else
      for c in select e from jsonb_array_elements(p_node -> 'content') e loop
        r := guide.welcome_body_stats(c, p_depth + 1);
        v_len := v_len + r[1];
        v_bad := greatest(v_bad, r[2]);
        v_url := greatest(v_url, r[3]);
        v_n := v_n + r[4];
        exit when v_n > 2000;
      end loop;
    end if;
  end if;
  return array[v_len, v_bad, v_url, v_n];
end;
$$;

create or replace function guide.welcome_body_ok(p jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare r integer[];
begin
  if p is null or octet_length(p::text) > 32768 then
    return false;
  end if;
  r := guide.welcome_body_stats(p);
  return r[1] between 1 and 1500 and r[2] = 0 and r[3] = 0 and r[4] <= 2000;
end;
$$;

-- ───────────── 2. Tabla (fila única) ─────────────

create table if not exists guide.newsletter_welcome (
  id                     smallint primary key default 1,
  enabled                boolean not null default false,
  subject_es             text not null,
  preheader_es           text,
  title_es               text not null,
  body_es                jsonb not null,
  list_title_es          text,
  list_items_es          text[] not null default '{}',
  button_text_es         text,
  button_url_es          text,
  signature_es           text,
  subject_en             text,
  preheader_en           text,
  title_en               text,
  body_en                jsonb,
  list_title_en          text,
  list_items_en          text[] not null default '{}',
  button_text_en         text,
  button_url_en          text,
  signature_en           text,
  published_at           timestamptz,
  published_by           uuid references auth.users (id) on delete set null,
  updated_at             timestamptz not null default now(),
  enabled_changed_at     timestamptz,
  enabled_changed_by     uuid references auth.users (id) on delete set null,
  draft                  jsonb,
  draft_base_updated_at  timestamptz,
  draft_updated_at       timestamptz,
  draft_updated_by       uuid references auth.users (id) on delete set null,
  constraint newsletter_welcome_singleton check (id = 1),
  constraint newsletter_welcome_es check (
    subject_es is not null and guide.welcome_line_ok(subject_es, 80)
    and guide.welcome_line_ok(preheader_es, 110)
    and title_es is not null and guide.welcome_line_ok(title_es, 80)
    and guide.welcome_body_ok(body_es)
    and guide.welcome_line_ok(list_title_es, 40) and guide.welcome_items_ok(list_items_es)
    and guide.welcome_line_ok(button_text_es, 40)
    and (button_url_es is null or guide.welcome_link_ok(button_url_es))
    and (button_text_es is null or button_url_es is not null)
    and guide.welcome_signature_ok(signature_es)),
  -- D3: el inglés va completo (asunto, título y cuerpo) o vacío del todo.
  constraint newsletter_welcome_en check (
    case when subject_en is null then
      title_en is null and body_en is null and preheader_en is null and list_title_en is null
      and list_items_en = '{}' and button_text_en is null and button_url_en is null and signature_en is null
    else
      guide.welcome_line_ok(subject_en, 80) and guide.welcome_line_ok(preheader_en, 110)
      and title_en is not null and guide.welcome_line_ok(title_en, 80)
      and guide.welcome_body_ok(body_en)
      and guide.welcome_line_ok(list_title_en, 40) and guide.welcome_items_ok(list_items_en)
      and guide.welcome_line_ok(button_text_en, 40)
      and (button_url_en is null or guide.welcome_link_ok(button_url_en))
      and (button_text_en is null or button_url_en is not null)
      and guide.welcome_signature_ok(signature_en)
    end),
  constraint newsletter_welcome_enabled check (not enabled or published_at is not null),
  constraint newsletter_welcome_draft check (
    (draft is null) = (draft_base_updated_at is null) and (draft is null) = (draft_updated_at is null)
    and (draft is null or (jsonb_typeof(draft) = 'object' and octet_length(draft::text) <= 65536)))
);

comment on table guide.newsletter_welcome is
  'Email de bienvenida de la newsletter (README §21). Fila única: versión publicada + borrador de cambios (D23). Solo RPC admin y svc_welcome_prepare.';

alter table guide.newsletter_welcome enable row level security;
revoke all on guide.newsletter_welcome from public, anon, authenticated, service_role;

-- Seed: texto de docs/copy/email-bienvenida.md. Nunca publicado ni activo (estado «Sin activar»).
insert into guide.newsletter_welcome (
  id, subject_es, preheader_es, title_es, body_es, list_title_es, list_items_es, button_text_es, button_url_es, signature_es,
  subject_en, preheader_en, title_en, body_en, list_title_en, list_items_en, button_text_en, button_url_en, signature_en)
values (
  1,
  'Ya formas parte de ChalkGuide',
  'Suscripción confirmada. Cada semana: agenda de escalada, noticias con fuente y el último artículo.',
  'Te damos la bienvenida a ChalkGuide',
  '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Nos alegra que formes parte de la familia de escaladores de ChalkGuide. Aquí no hay ruido: una carta a la semana, con lo que de verdad merece tu tiempo."}]},{"type":"paragraph","content":[{"type":"text","text":"Si respondes a este correo, me llega a mí, a Xavi, y lo leo. Cuéntame qué echas en falta."}]}]}'::jsonb,
  'Qué te llega',
  array['La agenda de eventos de escalada en Barcelona y Cataluña de las próximas semanas.',
        'Noticias del mundillo, siempre con su fuente.',
        'El último artículo del blog.',
        'Una carta por semana, sin seguimiento de aperturas ni clics. Te das de baja con un clic desde cualquier carta.'],
  'Leer el blog',
  '/blog',
  E'Un abrazo,\nXavi, ChalkGuide',
  'You''re in: welcome to ChalkGuide',
  'Subscription confirmed. Every week: climbing events, news with sources and the latest article.',
  'Welcome to ChalkGuide',
  '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"We''re glad you''ve joined the ChalkGuide climbing family. No noise here: one letter a week, with what''s genuinely worth your time."}]},{"type":"paragraph","content":[{"type":"text","text":"If you reply to this email, it reaches me, Xavi, and I read it. Tell me what you''re missing."}]}]}'::jsonb,
  'What you''ll get',
  array['The climbing events calendar for Barcelona and Catalonia over the coming weeks.',
        'Climbing news, always with its source.',
        'The latest blog article.',
        'One letter a week, with no open or click tracking. Unsubscribe in one click from any letter.'],
  'Read the blog',
  '/en/blog',
  E'Best,\nXavi, ChalkGuide')
on conflict (id) do nothing;

-- ───────────── 3. Forma del contenido (borrador, publicado, prueba) ─────────────

-- Contrato del front: {"es": {...}, "en": {...} | null} con las claves
-- subject, preheader, title, body, list_title, list_items, button_text, button_url, signature.
create or replace function guide.welcome_published_payload(w guide.newsletter_welcome)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'es', jsonb_build_object('subject', w.subject_es, 'preheader', w.preheader_es, 'title', w.title_es, 'body', w.body_es,
                             'list_title', w.list_title_es, 'list_items', to_jsonb(w.list_items_es),
                             'button_text', w.button_text_es, 'button_url', w.button_url_es, 'signature', w.signature_es),
    'en', case when w.subject_en is null then null else
          jsonb_build_object('subject', w.subject_en, 'preheader', w.preheader_en, 'title', w.title_en, 'body', w.body_en,
                             'list_title', w.list_title_en, 'list_items', to_jsonb(w.list_items_en),
                             'button_text', w.button_text_en, 'button_url', w.button_url_en, 'signature', w.signature_en)
          end);
$$;

-- Estructura del borrador (al guardar): tipos y topes holgados; los límites de §21.3 se exigen al publicar.
create or replace function guide.welcome_draft_check(p jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  c_keys constant text[] := array['subject', 'preheader', 'title', 'body', 'list_title', 'list_items', 'button_text',
                                  'button_url', 'signature'];
  v_loc text;
  v     jsonb;
  k     text;
begin
  if p is null or jsonb_typeof(p) <> 'object' or octet_length(p::text) > 65536
     or exists (select 1 from jsonb_object_keys(p) x where x not in ('es', 'en'))
     or jsonb_typeof(p -> 'es') is distinct from 'object'
     or (p ? 'en' and jsonb_typeof(p -> 'en') not in ('object', 'null')) then
    raise exception 'invalid welcome payload' using errcode = '22023';
  end if;
  foreach v_loc in array array['es', 'en'] loop
    v := p -> v_loc;
    continue when v is null or jsonb_typeof(v) = 'null';
    for k in select x from jsonb_object_keys(v) x loop
      if k <> all (c_keys) then
        raise exception 'invalid welcome payload' using errcode = '22023';
      end if;
      if k = 'body' then
        if jsonb_typeof(v -> k) not in ('object', 'null') or octet_length((v -> k)::text) > 32768 then
          raise exception 'invalid welcome payload' using errcode = '22023';
        end if;
      elsif k = 'list_items' then
        if jsonb_typeof(v -> k) not in ('array', 'null')
           or (jsonb_typeof(v -> k) = 'array' and (jsonb_array_length(v -> k) > 12
               or exists (select 1 from jsonb_array_elements(v -> k) e
                          where jsonb_typeof(e) <> 'string' or char_length(e #>> '{}') > 2000))) then
          raise exception 'invalid welcome payload' using errcode = '22023';
        end if;
      elsif jsonb_typeof(v -> k) not in ('string', 'null') or char_length(v ->> k) > 2000 then
        raise exception 'invalid welcome payload' using errcode = '22023';
      end if;
    end loop;
  end loop;
end;
$$;

-- Normaliza: recorta, '' → null, ítems vacíos fuera, cuerpo sin texto → null; EN sin asunto, título ni cuerpo → null (D3).
create or replace function guide.welcome_normalize(p jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_out jsonb := '{}'::jsonb;
  v_loc text;
  v     jsonb;
  n     jsonb;
  k     text;
begin
  foreach v_loc in array array['es', 'en'] loop
    v := p -> v_loc;
    if v is null or jsonb_typeof(v) <> 'object' then
      v_out := v_out || jsonb_build_object(v_loc, case when v_loc = 'es' then '{}'::jsonb end);
      continue;
    end if;
    n := '{}'::jsonb;
    foreach k in array array['subject', 'preheader', 'title', 'list_title', 'button_text', 'button_url'] loop
      n := n || jsonb_build_object(k, nullif(btrim(v ->> k), ''));
    end loop;
    n := n || jsonb_build_object('signature',
                                 nullif(btrim(regexp_replace(replace(coalesce(v ->> 'signature', ''), E'\r', ''),
                                                             '[ \t]+\n', E'\n', 'g'), E' \t\n'), ''));
    n := n || jsonb_build_object('list_items', coalesce(
      (select jsonb_agg(btrim(e #>> '{}') order by o) from jsonb_array_elements(
         case when jsonb_typeof(v -> 'list_items') = 'array' then v -> 'list_items' else '[]'::jsonb end)
         with ordinality x(e, o)
       where jsonb_typeof(e) = 'string' and btrim(e #>> '{}') <> ''), '[]'::jsonb));
    n := n || jsonb_build_object('body', case
      when jsonb_typeof(v -> 'body') = 'object' and (guide.welcome_body_stats(v -> 'body'))[1] > 0
           and octet_length((v -> 'body')::text) <= 32768 then v -> 'body' end);
    if v_loc = 'en' and n ->> 'subject' is null and n ->> 'title' is null and n -> 'body' = 'null'::jsonb then
      n := null;
    end if;
    v_out := v_out || jsonb_build_object(v_loc, n);
  end loop;
  return v_out;
end;
$$;

-- Errores al publicar (sobre el contenido normalizado): [{locale, field, code}]. Códigos: required, too_long,
-- invalid (caracteres de control o cuerpo con nodos fuera de la lista blanca), bad_url, too_many, too_many_lines,
-- en_partial. Vacío = se puede publicar.
create or replace function guide.welcome_errors(p jsonb)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_err jsonb := '[]'::jsonb;
  v_loc text;
  v     jsonb;
  s     integer[];
  k     text;
  lim   integer;
begin
  foreach v_loc in array array['es', 'en'] loop
    v := p -> v_loc;
    continue when v_loc = 'en' and (v is null or jsonb_typeof(v) = 'null');
    if v_loc = 'en' and (v ->> 'subject' is null or v ->> 'title' is null or v -> 'body' = 'null'::jsonb
                         or v -> 'body' is null) then
      v_err := v_err || jsonb_build_object('locale', 'en', 'field', null, 'code', 'en_partial');
    end if;
    foreach k in array array['subject', 'title'] loop
      if v ->> k is null then
        v_err := v_err || jsonb_build_object('locale', v_loc, 'field', k, 'code', 'required');
      end if;
    end loop;
    foreach k in array array['subject', 'preheader', 'title', 'list_title', 'button_text'] loop
      lim := case k when 'preheader' then 110 when 'list_title' then 40 when 'button_text' then 40 else 80 end;
      if char_length(v ->> k) > lim then
        v_err := v_err || jsonb_build_object('locale', v_loc, 'field', k, 'code', 'too_long');
      elsif v ->> k ~ '[[:cntrl:]]' then
        v_err := v_err || jsonb_build_object('locale', v_loc, 'field', k, 'code', 'invalid');
      end if;
    end loop;
    if v -> 'body' is null or v -> 'body' = 'null'::jsonb then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'body', 'code', 'required');
    else
      s := guide.welcome_body_stats(v -> 'body');
      if s[2] > 0 then
        v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'body', 'code', 'invalid');
      end if;
      if s[3] > 0 then
        v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'body', 'code', 'bad_url');
      end if;
      if s[1] > 1500 or s[4] > 2000 then
        v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'body', 'code', 'too_long');
      end if;
    end if;
    if jsonb_array_length(coalesce(v -> 'list_items', '[]'::jsonb)) > 6 then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'list_items', 'code', 'too_many');
    end if;
    if exists (select 1 from jsonb_array_elements(coalesce(v -> 'list_items', '[]'::jsonb)) e
               where char_length(e #>> '{}') > 140) then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'list_items', 'code', 'too_long');
    elsif exists (select 1 from jsonb_array_elements(coalesce(v -> 'list_items', '[]'::jsonb)) e
                  where (e #>> '{}') ~ '[[:cntrl:]]') then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'list_items', 'code', 'invalid');
    end if;
    if v ->> 'button_text' is not null and v ->> 'button_url' is null then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'button_url', 'code', 'required');
    elsif v ->> 'button_url' is not null and not guide.welcome_link_ok(v ->> 'button_url') then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'button_url', 'code', 'bad_url');
    end if;
    if char_length(v ->> 'signature') > 120 then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'signature', 'code', 'too_long');
    elsif array_length(string_to_array(v ->> 'signature', E'\n'), 1) > 2 then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'signature', 'code', 'too_many_lines');
    elsif translate(v ->> 'signature', E'\n', '') ~ '[[:cntrl:]]' then
      v_err := v_err || jsonb_build_object('locale', v_loc, 'field', 'signature', 'code', 'invalid');
    end if;
  end loop;
  return v_err;
end;
$$;

-- Contenido de un idioma tal como lo pinta la EF (email.ts › welcomeEmail).
create or replace function guide.welcome_locale_content(w guide.newsletter_welcome, p_locale guide.locale)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select case when p_locale = 'en' and w.subject_en is not null
    then guide.welcome_published_payload(w) -> 'en'
    else guide.welcome_published_payload(w) -> 'es' end;
$$;

do $$
declare v_fn text;
begin
  foreach v_fn in array array[
    'guide.welcome_link_ok(text)', 'guide.welcome_line_ok(text, integer)', 'guide.welcome_signature_ok(text)',
    'guide.welcome_items_ok(text[])', 'guide.welcome_body_stats(jsonb, integer)', 'guide.welcome_body_ok(jsonb)',
    'guide.welcome_published_payload(guide.newsletter_welcome)', 'guide.welcome_draft_check(jsonb)',
    'guide.welcome_normalize(jsonb)', 'guide.welcome_errors(jsonb)',
    'guide.welcome_locale_content(guide.newsletter_welcome, guide.locale)'] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', v_fn);
  end loop;
end $$;

-- ───────────── 4. Suscriptores, outbox, eventos y cupo ─────────────

alter table guide.subscribers add column if not exists welcome_sent_at timestamptz;
comment on column guide.subscribers.welcome_sent_at is
  'Email de bienvenida enviado (una vez por fila, §21). Lo fija solo svc_outbox_done con el actor brevo:<id>.';

alter table guide.subscriber_consent_events drop constraint if exists subscriber_consent_events_event_check;
alter table guide.subscriber_consent_events add constraint subscriber_consent_events_event_check check (event = any (array[
  'subscribe', 'confirm', 'unsubscribe', 'bounce', 'expire', 'erase', 'confirm_sent', 'welcome_sent']));

alter table guide.email_outbox drop constraint if exists email_outbox_last_error_check;
alter table guide.email_outbox add constraint email_outbox_last_error_check check (last_error is null or last_error = any (array[
  'brevo_4xx', 'brevo_404', 'brevo_429', 'brevo_5xx', 'timeout', 'network', 'quota', 'email_cap',
  'global_cap', 'not_allowed_test', 'stale_state', 'config', 'max_attempts', 'lock_expired', 'disabled', 'duplicate']));

-- L4: el messageId de la bienvenida también se guarda para casar bounces y quejas transaccionales.
alter table guide.email_outbox drop constraint if exists email_outbox_message_kind;
alter table guide.email_outbox add constraint email_outbox_message_kind check (
  brevo_message_id is null or kind in ('confirm_email', 'welcome_email'));

create unique index if not exists email_outbox_welcome_uq on guide.email_outbox (subscriber_id)
  where kind = 'welcome_email' and status in ('pending', 'processing');

alter table guide.newsletter_rate drop constraint if exists newsletter_rate_bucket_check;
alter table guide.newsletter_rate add constraint newsletter_rate_bucket_check check (
  bucket ~ '^(ip|ipnojs):[0-9a-f]{64}$' or bucket ~ '^wtest:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

-- Guarda: el actor brevo:<id> también puede fijar welcome_sent_at (nada más cambia).
create or replace function guide.subscribers_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_op    text := coalesce(current_setting('guide.consent_op', true), '');
  v_actor text := coalesce(current_setting('guide.consent_actor', true), '');
  v_brevo boolean := v_actor like 'brevo:%';
  c_brevo_cols constant text[] := array['status', 'unsubscribed_at', 'unsubscribe_source', 'brevo_contact_id', 'brevo_sync_status',
                                        'brevo_sync_error', 'synced_at', 'confirm_token_hash', 'confirm_expires_at',
                                        'confirm_sent_at', 'confirm_sends', 'confirm_resend_used', 'welcome_sent_at',
                                        'updated_at'];
begin
  if old.status = 'erased' then
    raise exception 'erased subscriber is frozen' using errcode = '42501';
  end if;
  if new.status = 'erased' and v_op is distinct from 'erase:' || old.id::text then
    raise exception 'erase only through admin_erase_subscriber' using errcode = '42501';
  end if;
  if new.email is distinct from old.email and new.status <> 'erased' then
    raise exception 'subscriber email is immutable' using errcode = '42501';
  end if;
  -- §21: welcome_sent_at solo lo fija el actor brevo (svc_outbox_done) y nunca se borra.
  if new.welcome_sent_at is distinct from old.welcome_sent_at
     and (not v_brevo or old.welcome_sent_at is not null or new.welcome_sent_at is null) then
    raise exception 'welcome_sent_at is set only by the worker' using errcode = '42501';
  end if;

  -- F4.6 (B14): actor brevo:<id> de las svc_*, atado a la fila. Solo columnas de sincronización y confirmación, y
  -- solo bajadas de estado (nunca activa, reactiva ni cambia idioma).
  if v_brevo then
    if v_actor <> 'brevo:' || old.id::text then
      raise exception 'brevo actor bound to another row' using errcode = '42501';
    end if;
    if (to_jsonb(new) - c_brevo_cols) is distinct from (to_jsonb(old) - c_brevo_cols) then
      raise exception 'brevo actor column not allowed' using errcode = '42501';
    end if;
    if new.status is distinct from old.status
       and (old.status::text || '>' || new.status::text)
           <> all (array['active>unsubscribed', 'active>bounced', 'pending>bounced', 'pending>unsubscribed']) then
      raise exception 'brevo actor status not allowed' using errcode = '42501';
    end if;
    if new.status is not distinct from old.status
       and (new.unsubscribed_at, new.unsubscribe_source) is distinct from (old.unsubscribed_at, old.unsubscribe_source) then
      raise exception 'brevo actor column not allowed' using errcode = '42501';
    end if;
  end if;

  if new.status is distinct from old.status and not (
       (old.status = 'pending'      and new.status in ('active', 'unsubscribed', 'expired', 'erased'))
    or (old.status = 'pending'      and new.status = 'bounced' and v_brevo)   -- L4: solo con actor brevo
    or (old.status = 'active'       and new.status in ('unsubscribed', 'bounced', 'erased'))
    or (old.status = 'unsubscribed' and new.status in ('pending', 'erased'))
    or (old.status = 'bounced'      and new.status in ('pending', 'unsubscribed', 'erased'))
    or (old.status = 'expired'      and new.status in ('pending', 'erased'))
  ) then
    raise exception 'invalid subscriber status transition' using errcode = '22023',
      detail = old.status::text || ' -> ' || new.status::text;
  end if;

  -- Re-alta (nuevo pending): contadores de confirmación de esta alta a cero. El tope por email de 30 días (B9) se
  -- cuenta en subscriber_consent_events y no se reinicia. welcome_sent_at no se reinicia: una bienvenida por fila.
  if new.status = 'pending' and (new.status is distinct from old.status or new.consent_at is distinct from old.consent_at) then
    new.confirm_sends := 0;
    new.confirm_resend_used := false;
    new.confirm_sent_at := null;
  end if;

  -- Espejo N3: entrar en active o salir con contacto en Brevo deja la sincronización pendiente (la hace el outbox).
  if new.status = 'erased' then
    new.brevo_sync_status := 'not_synced';
    new.brevo_sync_error := null;
  elsif new.status is distinct from old.status and (new.status = 'active' or old.brevo_contact_id is not null) then
    new.brevo_sync_status := 'pending';
    new.brevo_sync_error := null;
  end if;
  return new;
end;
$$;
revoke all on function guide.subscribers_guard() from public, anon, authenticated, service_role;

-- Envíos de hoy (Europe/Madrid): confirmaciones + bienvenidas + pruebas de bienvenida + campañas.
create or replace function guide.newsletter_sent_today()
returns integer
language sql
stable
set search_path = ''
as $$
  with d as (select date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid' as t)
  select (select count(*)::integer from guide.subscriber_consent_events e, d
          where e.event in ('confirm_sent', 'welcome_sent') and e.occurred_at >= d.t)
       + coalesce((select sum(r.hits)::integer from guide.newsletter_rate r, d
                   where r.bucket like 'wtest:%' and r.span = 'hour' and r.window_start >= d.t), 0)
       + coalesce((select sum((x.value ->> 'count')::integer)::integer
                   from guide.newsletter_issues i, d, jsonb_each(coalesce(i.brevo_campaign_ids, '{}'::jsonb)) x
                   where jsonb_typeof(x.value) = 'object' and x.value ->> 'state' = 'sent'
                     and (x.value ->> 'sent_at')::timestamptz >= d.t), 0);
$$;
revoke all on function guide.newsletter_sent_today() from public, anon, authenticated, service_role;

create or replace function guide.newsletter_quota_today()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  c_limit   constant integer := 300;
  c_reserve constant integer := 30;
  v_day     timestamptz := date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
  v_conf    integer;
  v_welc    integer;
  v_used    integer;
  v_es      integer;
  v_en      integer;
begin
  perform guide.assert_admin();
  select count(*) filter (where e.event = 'confirm_sent'), count(*) filter (where e.event = 'welcome_sent')
  into v_conf, v_welc
  from guide.subscriber_consent_events e where e.event in ('confirm_sent', 'welcome_sent') and e.occurred_at >= v_day;
  v_welc := v_welc + coalesce((select sum(r.hits)::integer from guide.newsletter_rate r
                               where r.bucket like 'wtest:%' and r.span = 'hour' and r.window_start >= v_day), 0);
  v_used := guide.newsletter_sent_today();
  select count(*) filter (where s.locale = 'es'), count(*) filter (where s.locale = 'en')
  into v_es, v_en
  from guide.subscribers s where s.status = 'active';
  return jsonb_build_object(
    'limit', c_limit, 'warn_from', 250, 'reserve', c_reserve, 'approximate', true,
    'confirmations_today', v_conf, 'welcome_today', v_welc, 'newsletter_sent_today', v_used - v_conf - v_welc,
    'used_today', v_used,
    'recipients_es', v_es, 'recipients_en', v_en, 'recipients', v_es + v_en,
    'after_issue', v_used + v_es + v_en,
    'fits', v_used + c_reserve + v_es <= c_limit and c_reserve + v_en <= c_limit,
    'will_split', v_used + c_reserve + v_es + v_en > c_limit,
    'split_recommended', v_es + v_en > 250);
end;
$$;
revoke all on function guide.newsletter_quota_today() from public, anon, authenticated, service_role;
grant execute on function guide.newsletter_quota_today() to authenticated;

-- ───────────── 5. Encolado al confirmar (único sitio) ─────────────

create or replace function guide.confirm_newsletter(p_token text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id      uuid;
  v_status  guide.subscriber_status;
  v_expires timestamptz;
  v_locale  guide.locale;
  v_page    text;
  v_slug    text;
  v_art     text;
  v_pillar  text;
  v_welcome timestamptz;
begin
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then
    return 'invalid';
  end if;
  select s.id, s.status, s.confirm_expires_at, s.locale, s.consent_page, s.welcome_sent_at
  into v_id, v_status, v_expires, v_locale, v_page, v_welcome
  from guide.subscribers s
  where s.confirm_token_hash = pg_catalog.sha256(convert_to(p_token, 'UTF8'))
  for update;
  if v_id is null then
    return 'invalid';
  end if;
  if v_status = 'active' then
    return 'ok';                       -- segundo clic en el mismo enlace
  end if;
  if v_status <> 'pending' then
    return 'invalid';
  end if;
  if v_expires < now() then
    return 'expired';
  end if;
  update guide.subscribers
  set status = 'active', confirmed_at = now(),
      related_status       = case when related_status = 'pending' then 'granted' else related_status end,
      related_confirmed_at = case when related_status = 'pending' then now() else related_confirmed_at end
  where id = v_id;

  -- §21: bienvenida solo tras el doble opt-in, si está publicada y activa, y una vez por fila. Sin PII en el outbox.
  -- Un trabajo previo que pudo salir (done, o failed/lock_expired) también cuenta como enviado.
  if v_welcome is null
     and exists (select 1 from guide.newsletter_welcome w where w.id = 1 and w.enabled and w.published_at is not null)
     and not exists (select 1 from guide.email_outbox o
                     where o.kind = 'welcome_email' and o.subscriber_id = v_id
                       and (o.status in ('pending', 'processing', 'done') or o.last_error = 'lock_expired')) then
    insert into guide.email_outbox (kind, subscriber_id) values ('welcome_email', v_id)
    on conflict (subscriber_id) where kind = 'welcome_email' and status in ('pending', 'processing') do nothing;
  end if;

  -- D69: newsletter_confirmed (solo capa propia; nunca a Google ni Meta).
  begin
    v_slug := substring(lower(coalesce(v_page, '')) from '^(?:/en)?/blog/([a-z0-9-]+)/?$');
    if v_slug is not null then
      select a.slug_es, c.slug_es into v_art, v_pillar
      from guide.articles a
      left join guide.article_categories c on c.id = a.category_id
      where a.slug_es = v_slug or a.slug_en = v_slug
      limit 1;
    end if;
    perform guide.analytics_record('newsletter_confirmed', coalesce(v_page, '/newsletter/confirmed'), v_locale::text,
                                   case when v_art is not null then 'article' end, v_art, v_pillar, null, null, null,
                                   date_trunc('hour', now()));
  exception when others then
    null;
  end;
  return 'ok';
end;
$$;
revoke all on function guide.confirm_newsletter(text) from public, anon, authenticated, service_role;
grant execute on function guide.confirm_newsletter(text) to anon, authenticated;

-- ───────────── 6. Worker: claim (C4), preparar, cerrar, bounces y reintento ─────────────

create or replace function guide.svc_outbox_claim(p_limit integer, p_lock_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v jsonb;
begin
  perform guide.svc_assert();
  if p_lock_id is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  -- C4: un email (confirmación o bienvenida) con lock caducado pudo enviarse ya; no se reintenta solo.
  update guide.email_outbox o
  set status = 'failed', last_error = 'lock_expired', lock_id = null, locked_at = null, done_at = now()
  where o.status = 'processing' and o.kind in ('confirm_email', 'welcome_email') and o.locked_at < now() - interval '10 minutes';
  -- Un trabajo colgado que ya agotó intentos no se vuelve a tomar.
  update guide.email_outbox o
  set status = 'failed', last_error = 'max_attempts', lock_id = null, locked_at = null, done_at = now()
  where o.status = 'processing' and o.locked_at < now() - interval '10 minutes' and o.attempts >= 7;

  with c as (
    select o.id from guide.email_outbox o
    where ((o.status = 'pending' and o.next_attempt_at <= now())
           or (o.status = 'processing' and o.kind not in ('confirm_email', 'welcome_email')
               and o.locked_at < now() - interval '10 minutes'))
      and not (o.kind = 'confirm_email' and exists (
                 select 1 from guide.email_outbox p
                 where p.kind = 'confirm_email' and p.subscriber_id = o.subscriber_id and p.id <> o.id
                   and p.status = 'processing' and p.locked_at >= now() - interval '10 minutes'))
    order by o.id
    limit least(greatest(coalesce(p_limit, 20), 1), 20)
    for update of o skip locked
  ), u as (
    update guide.email_outbox o
    set attempts = o.attempts + case when o.status = 'processing' then 1 else 0 end,
        status = 'processing', locked_at = now(), lock_id = p_lock_id
    from c where o.id = c.id
    returning o.id, o.kind, o.subscriber_id, o.brevo_contact_id
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'kind', u.kind, 'subscriber_id', u.subscriber_id,
                                               'brevo_contact_id', u.brevo_contact_id) order by u.id), '[]'::jsonb)
  into v from u;
  return v;
end;
$$;
revoke all on function guide.svc_outbox_claim(integer, uuid) from public, anon, authenticated, service_role;
grant execute on function guide.svc_outbox_claim(integer, uuid) to service_role;

-- Única función que entrega al worker el email y el token de baja de un destinatario de bienvenida.
create or replace function guide.svc_welcome_prepare(p_outbox_id bigint, p_lock_id uuid, p_allowlist text[])
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  o       guide.email_outbox;
  s       record;
  w       guide.newsletter_welcome;
  v_today timestamptz := date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
begin
  perform guide.svc_assert();
  o := guide.outbox_locked(p_outbox_id, p_lock_id);
  if o.kind <> 'welcome_email' then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  select x.id, x.status, x.email, x.locale, x.unsubscribe_token, x.welcome_sent_at into s
  from guide.subscribers x where x.id = o.subscriber_id for update;
  if not found or s.status <> 'active' or s.email is null then
    perform guide.outbox_close(o.id, 'skipped', 'stale_state');
    return jsonb_build_object('result', 'skip');
  end if;
  if s.welcome_sent_at is not null then
    perform guide.outbox_close(o.id, 'skipped', 'duplicate');
    return jsonb_build_object('result', 'skip');
  end if;
  select * into w from guide.newsletter_welcome where id = 1;
  if not found or not w.enabled or w.published_at is null then
    perform guide.outbox_close(o.id, 'skipped', 'disabled');
    return jsonb_build_object('result', 'skip');
  end if;
  if coalesce(cardinality(p_allowlist), 0) > 0
     and not (s.email = any (array(select lower(btrim(a)) from unnest(p_allowlist) a))) then
    perform guide.outbox_close(o.id, 'skipped', 'not_allowed_test');
    return jsonb_build_object('result', 'skip');
  end if;
  -- Cupo diario (300) menos la reserva de confirmaciones (30): si no cabe, al día siguiente.
  if guide.newsletter_sent_today() + 30 >= 300 then
    update guide.email_outbox
    set status = 'pending', lock_id = null, locked_at = null, last_error = 'global_cap',
        next_attempt_at = v_today + interval '1 day' + interval '5 minutes'
    where id = o.id;
    return jsonb_build_object('result', 'defer');
  end if;
  return jsonb_build_object(
    'result', 'ok', 'email', s.email, 'locale', s.locale, 'unsubscribe_token', s.unsubscribe_token,
    'fallback', s.locale = 'en' and w.subject_en is null,
    'content', guide.welcome_locale_content(w, s.locale));
end;
$$;
revoke all on function guide.svc_welcome_prepare(bigint, uuid, text[]) from public, anon, authenticated, service_role;
grant execute on function guide.svc_welcome_prepare(bigint, uuid, text[]) to service_role;

create or replace function guide.svc_outbox_done(p_outbox_id bigint, p_lock_id uuid, p_result text, p_code text,
                                                 p_brevo_contact_id bigint, p_message_id text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  o       guide.email_outbox;
  s       record;
  v_out   text := 'done';
  v_found boolean;
begin
  perform guide.svc_assert();
  o := guide.outbox_locked(p_outbox_id, p_lock_id);
  if p_result is null or p_result not in ('done', 'skipped') or (p_result = 'skipped' and p_code is null)
     or (p_code is not null and p_code not in ('brevo_404', 'not_allowed_test', 'stale_state', 'email_cap', 'config',
                                               'disabled', 'duplicate')) then
    raise exception 'invalid argument' using errcode = '22023';
  end if;

  if p_result = 'skipped' then
    perform guide.outbox_close(o.id, 'skipped', p_code);
    return 'skipped';
  end if;

  if o.kind in ('confirm_email', 'welcome_email') then
    if p_message_id is null or char_length(p_message_id) > 200 or p_message_id !~ '^<?[A-Za-z0-9._%+=@-]+>?$' then
      raise exception 'invalid argument' using errcode = '22023';
    end if;
    update guide.email_outbox set brevo_message_id = p_message_id where id = o.id;
  end if;

  if o.kind = 'confirm_email' then
    select x.id, x.status, x.locale, x.confirm_sends into s from guide.subscribers x where x.id = o.subscriber_id for update;
    v_found := found;
    if v_found and s.status = 'pending' then
      perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
      update guide.subscribers set confirm_sends = least(s.confirm_sends + 1, 2), confirm_sent_at = now() where id = s.id;
      perform set_config('guide.consent_actor', '', true);
    end if;
    if v_found then
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor)
      values (s.id, 'confirm_sent', 'brevo', s.locale, 'service');
    end if;

  elsif o.kind = 'welcome_email' then
    -- §21: marca de «bienvenida enviada» (ficha y deduplicado). Una fila suprimida entretanto no se toca.
    select x.id, x.status, x.locale, x.welcome_sent_at into s from guide.subscribers x where x.id = o.subscriber_id for update;
    if found and s.status <> 'erased' then
      if s.welcome_sent_at is null then
        perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
        update guide.subscribers set welcome_sent_at = now() where id = s.id;
        perform set_config('guide.consent_actor', '', true);
      end if;
      insert into guide.subscriber_consent_events (subscriber_id, event, source, locale, actor)
      values (s.id, 'welcome_sent', 'brevo', s.locale, 'service');
    end if;

  elsif o.kind = 'brevo_sync' then
    if p_brevo_contact_id is null or p_brevo_contact_id <= 0 then
      raise exception 'invalid argument' using errcode = '22023';
    end if;
    select x.id, x.status into s from guide.subscribers x where x.id = o.subscriber_id for update;
    if found and s.status = 'active' then
      perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
      update guide.subscribers
      set brevo_contact_id = p_brevo_contact_id, brevo_sync_status = 'synced', brevo_sync_error = null, synced_at = now()
      where id = s.id;
      perform set_config('guide.consent_actor', '', true);
    else
      insert into guide.email_outbox (kind, brevo_contact_id) values ('brevo_delete', p_brevo_contact_id)
      on conflict (brevo_contact_id) where status = 'pending' and kind = 'brevo_delete' do nothing;
      v_out := 'deleted_stale';
    end if;

  else
    for s in select x.id from guide.subscribers x
             where x.brevo_contact_id = o.brevo_contact_id and x.status not in ('active', 'erased')
             for update
    loop
      perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
      update guide.subscribers set brevo_contact_id = null, brevo_sync_status = 'not_synced', brevo_sync_error = null,
                                   synced_at = now()
      where id = s.id;
    end loop;
    perform set_config('guide.consent_actor', '', true);
  end if;

  update guide.email_outbox
  set status = 'done', last_error = p_code, lock_id = null, locked_at = null, done_at = now()
  where id = o.id;
  return v_out;
end;
$$;
revoke all on function guide.svc_outbox_done(bigint, uuid, text, text, bigint, text) from public, anon, authenticated, service_role;
grant execute on function guide.svc_outbox_done(bigint, uuid, text, text, bigint, text) to service_role;

-- L4: bounces y quejas transaccionales también de la bienvenida (mismo messageId + email).
create or replace function guide.svc_apply_brevo_tx_event(p_event text, p_message_id text, p_email text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  s        record;
  v_to     guide.subscriber_status;
begin
  perform guide.svc_assert();
  if p_event is null or p_event not in ('hardBounce', 'spam', 'blocked') or p_message_id is null or p_email is null
     or char_length(p_message_id) > 200 then
    return 'ignored';
  end if;
  select x.id, x.status into s
  from guide.email_outbox o join guide.subscribers x on x.id = o.subscriber_id
  where o.kind in ('confirm_email', 'welcome_email') and o.brevo_message_id = p_message_id
    and x.email = lower(btrim(p_email)) and x.status in ('pending', 'active')
  limit 1
  for update of x;
  if not found then
    return 'ignored';
  end if;
  v_to := case when p_event = 'spam' then 'unsubscribed' else 'bounced' end;
  perform set_config('guide.consent_actor', 'brevo:' || s.id::text, true);
  update guide.subscribers
  set status = v_to,
      unsubscribed_at = case when v_to = 'unsubscribed' then now() end,
      unsubscribe_source = case when v_to = 'unsubscribed' then 'complaint' end,
      confirm_token_hash = null, confirm_expires_at = null
  where id = s.id;
  perform set_config('guide.consent_actor', '', true);
  return 'applied';
end;
$$;
revoke all on function guide.svc_apply_brevo_tx_event(text, text, text) from public, anon, authenticated, service_role;
grant execute on function guide.svc_apply_brevo_tx_event(text, text, text) to service_role;

-- Reintentar fallidos: una bienvenida con lock caducado (pudo salir) no se reintenta, ni si ya hay otra en curso.
create or replace function guide.admin_email_retry_failed()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v integer;
begin
  perform guide.assert_admin();
  update guide.email_outbox
  set status = 'pending', attempts = 0, last_error = null, done_at = null, next_attempt_at = now()
  where status = 'failed'
    and not (kind in ('confirm_email', 'brevo_sync')
             and exists (select 1 from guide.email_outbox p where p.kind = email_outbox.kind
                         and p.subscriber_id = email_outbox.subscriber_id and p.status = 'pending'))
    and not (kind = 'brevo_delete'
             and exists (select 1 from guide.email_outbox p where p.kind = 'brevo_delete'
                         and p.brevo_contact_id = email_outbox.brevo_contact_id and p.status = 'pending'))
    and not (kind = 'welcome_email'
             and (last_error = 'lock_expired' or subscriber_id is null
                  or exists (select 1 from guide.email_outbox p where p.kind = 'welcome_email'
                             and p.subscriber_id = email_outbox.subscriber_id and p.id <> email_outbox.id
                             and p.status in ('pending', 'processing', 'done'))));
  get diagnostics v = row_count;
  return v;
end;
$$;
revoke all on function guide.admin_email_retry_failed() from public, anon, authenticated, service_role;
grant execute on function guide.admin_email_retry_failed() to authenticated;

create or replace function guide.admin_email_health()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today timestamptz := date_trunc('day', now() at time zone 'Europe/Madrid') at time zone 'Europe/Madrid';
  v       jsonb;
begin
  perform guide.assert_admin();
  select jsonb_build_object(
    'outbox', coalesce((select jsonb_agg(jsonb_build_object('kind', t.kind, 'status', t.status, 'code', t.last_error, 'n', t.n)
                                         order by t.kind, t.status, t.last_error)
                        from (select o.kind, o.status, o.last_error, count(*) n from guide.email_outbox o
                              group by o.kind, o.status, o.last_error) t), '[]'::jsonb),
    'oldest_pending_at', (select min(o.created_at) from guide.email_outbox o where o.status in ('pending', 'processing')),
    'failed_deletes', (select count(*) from guide.email_outbox o where o.kind = 'brevo_delete' and o.status = 'failed'),
    'confirm_sent_today', (select count(*) from guide.subscriber_consent_events e
                           where e.event = 'confirm_sent' and e.occurred_at >= v_today),
    'confirm_cap_per_day', 100,
    'last_confirm_sent_at', (select max(e.occurred_at) from guide.subscriber_consent_events e where e.event = 'confirm_sent'),
    'welcome_sent_today', (select count(*) from guide.subscriber_consent_events e
                           where e.event = 'welcome_sent' and e.occurred_at >= v_today),
    'welcome_enabled', coalesce((select w.enabled from guide.newsletter_welcome w where w.id = 1), false),
    'active_es', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'es'),
    'active_en', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'en'),
    'active_unsynced', (select count(*) from guide.subscribers s where s.status = 'active' and s.brevo_sync_status <> 'synced'))
  into v;
  return v;
end;
$$;
revoke all on function guide.admin_email_health() from public, anon, authenticated, service_role;
grant execute on function guide.admin_email_health() to authenticated;

-- ───────────── 7. RPC del panel (solo admin) ─────────────

create or replace function guide.admin_get_welcome_email()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  w      guide.newsletter_welcome;
  v_hits integer;
begin
  perform guide.assert_admin();
  select * into w from guide.newsletter_welcome where id = 1;
  if not found then
    raise exception 'welcome email not found' using errcode = 'P0002';
  end if;
  select coalesce(sum(r.hits), 0)::integer into v_hits from guide.newsletter_rate r
  where r.bucket = 'wtest:' || (select auth.uid())::text and r.span = 'hour' and r.window_start = date_trunc('hour', now());
  return jsonb_build_object(
    'enabled', w.enabled, 'enabled_changed_at', w.enabled_changed_at,
    'published_at', w.published_at, 'updated_at', w.updated_at,
    'published', guide.welcome_published_payload(w),
    'draft', w.draft, 'draft_base_updated_at', w.draft_base_updated_at, 'draft_updated_at', w.draft_updated_at,
    'active_es', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'es'),
    'active_en', (select count(*) from guide.subscribers s where s.status = 'active' and s.locale = 'en'),
    'sent_total', (select count(*) from guide.subscribers s where s.welcome_sent_at is not null and s.status <> 'erased'),
    'test_sends_left', greatest(5 - v_hits, 0),
    'limits', jsonb_build_object('subject', 80, 'preheader', 110, 'title', 80, 'body', 1500, 'list_title', 40,
                                 'list_items', 6, 'list_item', 140, 'button_text', 40, 'signature', 120,
                                 'signature_lines', 2, 'test_per_hour', 5));
end;
$$;

-- Guardar borrador (D23): sin borrador, p_base_updated_at = updated_at de lo publicado; con borrador, su base (o null).
create or replace function guide.admin_welcome_save_draft(p_payload jsonb, p_base_updated_at timestamptz default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  w guide.newsletter_welcome;
begin
  perform guide.assert_admin();
  perform guide.welcome_draft_check(p_payload);
  select * into w from guide.newsletter_welcome where id = 1 for update;
  if not found then
    raise exception 'welcome email not found' using errcode = 'P0002';
  end if;
  if w.draft is null then
    if p_base_updated_at is null or p_base_updated_at <> w.updated_at then
      raise exception 'draft conflict' using errcode = 'PT409';
    end if;
    update guide.newsletter_welcome
    set draft = p_payload, draft_base_updated_at = w.updated_at, draft_updated_at = now(),
        draft_updated_by = (select auth.uid())
    where id = 1 returning * into w;
  else
    if p_base_updated_at is not null and p_base_updated_at <> w.draft_base_updated_at then
      raise exception 'draft conflict' using errcode = 'PT409';
    end if;
    update guide.newsletter_welcome
    set draft = p_payload, draft_updated_at = now(), draft_updated_by = (select auth.uid())
    where id = 1 returning * into w;
  end if;
  return jsonb_build_object('base_updated_at', w.draft_base_updated_at, 'updated_at', w.draft_updated_at);
end;
$$;

create or replace function guide.admin_welcome_discard_draft()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform guide.assert_admin();
  update guide.newsletter_welcome
  set draft = null, draft_base_updated_at = null, draft_updated_at = null, draft_updated_by = null
  where id = 1 and draft is not null;
  return found;
end;
$$;

-- Publicar (y, si p_enable, activar). Errores de §21.3/§21.8 como lista, sin escribir nada. Sin borrador solo se
-- puede publicar la primera vez (el texto del seed). No reenvía nada a quien ya está suscrito.
create or replace function guide.admin_welcome_publish(p_enable boolean default false)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  w     guide.newsletter_welcome;
  v     jsonb;
  v_err jsonb;
  es    jsonb;
  en    jsonb;
begin
  perform guide.assert_admin();
  select * into w from guide.newsletter_welcome where id = 1 for update;
  if not found then
    raise exception 'welcome email not found' using errcode = 'P0002';
  end if;
  if w.draft is null and w.published_at is not null then
    raise exception 'draft not found' using errcode = 'P0002';
  end if;
  if w.draft is not null and w.draft_base_updated_at is distinct from w.updated_at then
    raise exception 'draft conflict' using errcode = 'PT409';
  end if;
  if w.draft is not null then
    perform guide.welcome_draft_check(w.draft);
  end if;
  v := guide.welcome_normalize(coalesce(w.draft, guide.welcome_published_payload(w)));
  v_err := guide.welcome_errors(v);
  if jsonb_array_length(v_err) > 0 then
    return jsonb_build_object('ok', false, 'errors', v_err);
  end if;
  es := v -> 'es';
  en := case when jsonb_typeof(v -> 'en') = 'object' then v -> 'en' end;
  update guide.newsletter_welcome set
    subject_es = es ->> 'subject', preheader_es = es ->> 'preheader', title_es = es ->> 'title', body_es = es -> 'body',
    list_title_es = es ->> 'list_title',
    list_items_es = array(select jsonb_array_elements_text(es -> 'list_items')),
    button_text_es = es ->> 'button_text', button_url_es = es ->> 'button_url', signature_es = es ->> 'signature',
    subject_en = en ->> 'subject', preheader_en = en ->> 'preheader', title_en = en ->> 'title', body_en = en -> 'body',
    list_title_en = en ->> 'list_title',
    list_items_en = coalesce(array(select jsonb_array_elements_text(en -> 'list_items')), '{}'),
    button_text_en = en ->> 'button_text', button_url_en = en ->> 'button_url', signature_en = en ->> 'signature',
    published_at = now(), published_by = (select auth.uid()), updated_at = now(),
    enabled = enabled or coalesce(p_enable, false),
    enabled_changed_at = case when not enabled and coalesce(p_enable, false) then now() else enabled_changed_at end,
    enabled_changed_by = case when not enabled and coalesce(p_enable, false) then (select auth.uid()) else enabled_changed_by end,
    draft = null, draft_base_updated_at = null, draft_updated_at = null, draft_updated_by = null
  where id = 1 returning * into w;
  return jsonb_build_object('ok', true, 'published_at', w.published_at, 'updated_at', w.updated_at, 'enabled', w.enabled);
end;
$$;

-- Interruptor inmediato (no pasa por el borrador). Activar exige una versión publicada.
create or replace function guide.admin_welcome_set_enabled(p_enabled boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  w guide.newsletter_welcome;
begin
  perform guide.assert_admin();
  if p_enabled is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  select * into w from guide.newsletter_welcome where id = 1 for update;
  if not found then
    raise exception 'welcome email not found' using errcode = 'P0002';
  end if;
  if p_enabled and w.published_at is null then
    raise exception 'welcome email not published' using errcode = '22023';
  end if;
  if w.enabled is distinct from p_enabled then
    update guide.newsletter_welcome
    set enabled = p_enabled, enabled_changed_at = now(), enabled_changed_by = (select auth.uid())
    where id = 1 returning * into w;
  end if;
  return jsonb_build_object('enabled', w.enabled, 'enabled_changed_at', w.enabled_changed_at);
end;
$$;

-- «Enviarme una prueba»: valida lo que hay en pantalla, aplica 5/h por admin y el cupo, y devuelve el email de la
-- sesión (auth.users del propio auth.uid(); nunca otro destinatario). La llama la EF newsletter-welcome-test con el JWT
-- del admin; no pasa por NEWSLETTER_TEST_ALLOWLIST. Cada llamada aceptada cuenta en el cupo del día.
create or replace function guide.admin_welcome_test_prepare(p_locale guide.locale, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid    uuid := (select auth.uid());
  v_email  text;
  v        jsonb;
  c        jsonb;
  v_fb     boolean;
  v_hits   integer;
  v_bucket text;
  v_hour   timestamptz := date_trunc('hour', now());
begin
  perform guide.assert_admin();
  if p_locale is null then
    raise exception 'invalid argument' using errcode = '22023';
  end if;
  perform guide.welcome_draft_check(p_payload);
  v := guide.welcome_normalize(p_payload);
  v_fb := p_locale = 'en' and jsonb_typeof(v -> 'en') is distinct from 'object';
  c := case when v_fb then v -> 'es' else v -> p_locale::text end;
  if c ->> 'subject' is null or c ->> 'title' is null or c -> 'body' is null or c -> 'body' = 'null'::jsonb
     or (guide.welcome_body_stats(c -> 'body'))[2] > 0 then
    return jsonb_build_object('result', 'incomplete');
  end if;
  v_bucket := 'wtest:' || v_uid::text;
  select r.hits into v_hits from guide.newsletter_rate r
  where r.bucket = v_bucket and r.span = 'hour' and r.window_start = v_hour for update;
  if coalesce(v_hits, 0) >= 5 then
    return jsonb_build_object('result', 'rate_limited',
                              'retry_after_s', ceil(extract(epoch from (v_hour + interval '1 hour' - now())))::integer);
  end if;
  if guide.newsletter_sent_today() + 30 >= 300 then
    return jsonb_build_object('result', 'quota');
  end if;
  select nullif(lower(btrim(u.email)), '') into v_email from auth.users u where u.id = v_uid;
  if v_email is null then
    return jsonb_build_object('result', 'no_email');
  end if;
  insert into guide.newsletter_rate (bucket, span, window_start, hits) values (v_bucket, 'hour', v_hour, 1)
  on conflict (bucket, span, window_start) do update set hits = guide.newsletter_rate.hits + 1;
  return jsonb_build_object('result', 'ok', 'email', v_email, 'locale', p_locale, 'fallback', v_fb, 'content', c);
end;
$$;

do $$
declare v_fn text;
begin
  foreach v_fn in array array[
    'guide.admin_get_welcome_email()', 'guide.admin_welcome_save_draft(jsonb, timestamptz)',
    'guide.admin_welcome_discard_draft()', 'guide.admin_welcome_publish(boolean)',
    'guide.admin_welcome_set_enabled(boolean)', 'guide.admin_welcome_test_prepare(guide.locale, jsonb)'] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', v_fn);
    execute format('grant execute on function %s to authenticated', v_fn);
  end loop;
end $$;

-- Ficha del suscriptor: fecha de la bienvenida (§21.1).
create or replace function guide.admin_get_subscriber(p_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  s guide.subscribers%rowtype;
begin
  perform guide.assert_admin();
  select * into s from guide.subscribers where id = p_id and status <> 'erased';
  if not found then
    raise exception 'subscriber not found' using errcode = 'P0002';
  end if;
  return jsonb_build_object(
    'subscriber', jsonb_build_object(
      'id', s.id, 'email', s.email, 'status', s.status, 'locale', s.locale,
      'consent_at', s.consent_at, 'consent_source', s.consent_source, 'consent_version', s.consent_version,
      'consent_page', s.consent_page, 'confirmed_at', s.confirmed_at, 'confirm_expires_at', s.confirm_expires_at,
      'unsubscribed_at', s.unsubscribed_at, 'unsubscribe_source', s.unsubscribe_source,
      'has_account', s.user_id is not null,
      'brevo_sync_status', s.brevo_sync_status, 'brevo_sync_error', s.brevo_sync_error, 'synced_at', s.synced_at,
      'welcome_sent_at', s.welcome_sent_at,
      'created_at', s.created_at, 'updated_at', s.updated_at,
      'expires_at', case when s.status = 'pending' then s.consent_at + interval '7 days' end,
      'anonymize_at', guide.subscriber_anonymize_at(s.status, s.consent_at, s.unsubscribed_at, s.updated_at,
                                                    s.related_status, s.related_withdrawn_at),
      'related_status', s.related_status, 'related_consent_at', s.related_consent_at,
      'related_consent_source', s.related_consent_source, 'related_consent_version', s.related_consent_version,
      'related_confirmed_at', s.related_confirmed_at, 'related_withdrawn_at', s.related_withdrawn_at,
      'related_withdraw_source', s.related_withdraw_source),
    'events', (
      select coalesce(jsonb_agg(jsonb_build_object(
          'occurred_at', e.occurred_at, 'event', e.event, 'source', e.source, 'consent_version', e.consent_version,
          'locale', e.locale, 'page', e.page, 'actor', e.actor, 'reason', e.reason, 'purpose', e.purpose)
        order by e.occurred_at desc, e.id desc), '[]'::jsonb)
      from guide.subscriber_consent_events e where e.subscriber_id = s.id),
    'consent_texts', (
      select coalesce(jsonb_object_agg(c.version::text, jsonb_build_object(
          'text_es', c.text_es, 'text_en', c.text_en, 'preserved', c.preserved,
          'valid_from', c.valid_from, 'valid_to', c.valid_to)), '{}'::jsonb)
      from guide.consent_texts c
      where c.purpose = 'newsletter'
        and (c.version = s.consent_version
             or c.version in (select e.consent_version from guide.subscriber_consent_events e
                              where e.subscriber_id = s.id and e.purpose = 'newsletter' and e.consent_version is not null))),
    'related_consent_texts', (
      select coalesce(jsonb_object_agg(c.version::text, jsonb_build_object(
          'text_es', c.text_es, 'text_en', c.text_en, 'preserved', c.preserved,
          'valid_from', c.valid_from, 'valid_to', c.valid_to)), '{}'::jsonb)
      from guide.consent_texts c
      where c.purpose = 'related_products'
        and (c.version = s.related_consent_version
             or c.version in (select e.consent_version from guide.subscriber_consent_events e
                              where e.subscriber_id = s.id and e.purpose = 'related_products'
                                and e.consent_version is not null)))
  );
end;
$$;
revoke all on function guide.admin_get_subscriber(uuid) from public, anon, authenticated, service_role;
grant execute on function guide.admin_get_subscriber(uuid) to authenticated;
