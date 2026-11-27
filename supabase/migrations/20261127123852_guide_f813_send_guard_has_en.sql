-- 8.13 · Corrección de la exención send:<id>:<lock> del guard de newsletter_issues: has_en es una columna generada y en
-- un BEFORE trigger NEW todavía no la trae calculada, así que se excluye de la comparación (como en la rama del agente).
-- Idempotente (create or replace). Sin cambios de grants.

create or replace function guide.newsletter_issues_before_write()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  c_content constant text[] := array['subject_es', 'subject_en', 'preheader_es', 'preheader_en', 'intro_es', 'intro_en'];
  c_send    constant text[] := array['status', 'send_lock_id', 'send_locked_at', 'send_attempts', 'send_next_at', 'sent_at',
                                     'sent_counts', 'error_code', 'brevo_campaign_ids', 'updated_at'];
  v_op    text := coalesce(current_setting('guide.newsletter_op', true), '');
  v_admin boolean := guide.is_admin();
  v_maint boolean := guide.item_live_exempt(null);
  v_bad   integer;
begin
  if tg_op = 'DELETE' then
    if v_maint then
      return old;
    end if;
    if not v_admin then
      raise exception 'newsletter_write_forbidden' using errcode = '42501';
    end if;
    if old.status not in ('draft', 'cancelled') then
      raise exception 'newsletter is locked' using errcode = 'PT423', detail = 'delete';
    end if;
    return old;
  end if;

  -- 8.13 (B14, L11): exención de envío atada a la fila y al lock. Solo columnas de envío y solo
  -- scheduled→sending, sending→sending|sent|failed. El contenido sigue inmutable.
  if tg_op = 'UPDATE' and v_op like 'send:%' then
    if not (coalesce(v_op = 'send:' || old.id::text || ':' || new.send_lock_id::text, false)
            or coalesce(v_op = 'send:' || old.id::text || ':' || old.send_lock_id::text, false)) then
      raise exception 'newsletter_send_op_mismatch' using errcode = '42501';
    end if;
    -- has_en es generada: en un BEFORE trigger NEW aún no la tiene calculada.
    if (to_jsonb(new) - c_send - 'has_en') is distinct from (to_jsonb(old) - c_send - 'has_en') then
      raise exception 'newsletter_field_immutable' using errcode = '42501';
    end if;
    if (old.status::text || '>' || new.status::text)
       <> all (array['scheduled>sending', 'sending>sending', 'sending>sent', 'sending>failed']) then
      raise exception 'newsletter_invalid_transition' using errcode = '55000',
        detail = old.status::text || '>' || new.status::text;
    end if;
    return new;
  end if;

  new.subject_es   := nullif(btrim(new.subject_es), '');
  new.subject_en   := nullif(btrim(new.subject_en), '');
  new.preheader_es := nullif(btrim(new.preheader_es), '');
  new.preheader_en := nullif(btrim(new.preheader_en), '');
  new.intro_es     := nullif(btrim(new.intro_es), '');
  new.intro_en     := nullif(btrim(new.intro_en), '');

  if v_maint then
    return new;
  end if;

  if not v_admin then
    if tg_op = 'INSERT' then
      if new.status <> 'draft' or new.approved_at is not null or new.scheduled_for is not null
         or new.sent_at is not null or new.sent_counts is not null or new.brevo_campaign_ids is not null
         or new.error_code is not null or new.send_lock_id is not null or new.send_attempts <> 0
         or new.send_next_at is not null then
        raise exception 'newsletter_write_forbidden' using errcode = '42501';
      end if;
      new.id := gen_random_uuid();
      new.composed_by := 'agent';
      new.composed_at := now();
      new.created_at := now();
      new.updated_at := now();
      return new;
    end if;
    if old.status <> 'draft' or new.status <> 'draft'
       or (to_jsonb(new) - c_content - 'intro_by_agent' - 'updated_at' - 'has_en')
          is distinct from (to_jsonb(old) - c_content - 'intro_by_agent' - 'updated_at' - 'has_en') then
      raise exception 'newsletter_write_forbidden' using errcode = '42501';
    end if;
    if not old.intro_by_agent
       and num_nonnulls(old.subject_es, old.subject_en, old.preheader_es, old.preheader_en, old.intro_es, old.intro_en) > 0 then
      raise exception 'newsletter_intro_owned' using errcode = '42501';
    end if;
    new.intro_by_agent := true;
    new.updated_at := now();
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'draft' then
      raise exception 'newsletter_invalid_transition' using errcode = '55000', detail = 'insert>' || new.status::text;
    end if;
    new.composed_by := 'admin';
    new.composed_at := now();
    new.intro_by_agent := false;
    new.approved_at := null;
    new.approved_by := null;
    new.scheduled_for := null;
    new.sent_at := null;
    new.sent_counts := null;
    new.error_code := null;
    new.brevo_campaign_ids := null;
    new.send_lock_id := null;
    new.send_locked_at := null;
    new.send_attempts := 0;
    new.send_next_at := null;
    return new;
  end if;

  if new.id is distinct from old.id or new.week_start is distinct from old.week_start
     or new.created_at is distinct from old.created_at or new.composed_by is distinct from old.composed_by
     or new.sent_at is distinct from old.sent_at or new.sent_counts is distinct from old.sent_counts
     or new.error_code is distinct from old.error_code or new.brevo_campaign_ids is distinct from old.brevo_campaign_ids
     or new.send_lock_id is distinct from old.send_lock_id or new.send_locked_at is distinct from old.send_locked_at
     or new.send_attempts is distinct from old.send_attempts or new.send_next_at is distinct from old.send_next_at then
    raise exception 'newsletter_field_immutable' using errcode = '42501';
  end if;

  if (new.subject_es, new.subject_en, new.preheader_es, new.preheader_en, new.intro_es, new.intro_en)
     is distinct from
     (old.subject_es, old.subject_en, old.preheader_es, old.preheader_en, old.intro_es, old.intro_en) then
    if old.status <> 'draft' or new.status <> 'draft' then
      raise exception 'newsletter_not_draft' using errcode = '55000';
    end if;
    new.intro_by_agent := false;
  end if;
  if new.intro_by_agent and not old.intro_by_agent then
    new.intro_by_agent := false;
  end if;

  if new.status is distinct from old.status then
    -- B23 / L11: cancelar solo desde scheduled; sending → cancelled da 55000.
    if (old.status::text || '>' || new.status::text) <> all (array[
          'draft>scheduled', 'scheduled>draft', 'draft>cancelled', 'scheduled>cancelled', 'cancelled>draft']) then
      raise exception 'newsletter_invalid_transition' using errcode = '55000',
        detail = old.status::text || '>' || new.status::text;
    end if;
    if old.status = 'scheduled' and now() >= old.scheduled_for - interval '1 minute' then
      raise exception 'newsletter_locked' using errcode = '55000';
    end if;
    if new.status = 'scheduled' then
      if new.subject_es is null or new.intro_es is null then
        raise exception 'newsletter_incomplete' using errcode = '23514';
      end if;
      if not exists (select 1 from guide.newsletter_issue_items i where i.issue_id = new.id) then
        raise exception 'newsletter_empty' using errcode = '23514';
      end if;
      select count(*) into v_bad
      from guide.newsletter_issue_items i
      where i.issue_id = new.id
        and not (case i.kind
          when 'news' then exists (select 1 from guide.news n where n.id = i.ref_id and n.status = 'published')
          when 'event' then exists (select 1 from guide.events e where e.id = i.ref_id and e.status = 'approved')
          else exists (select 1 from guide.articles a where a.id = i.ref_id
                       and guide.article_is_live(a.status, a.published_at))
        end);
      if v_bad > 0 then
        raise exception 'newsletter_item_not_public' using errcode = '23514';
      end if;
      if not coalesce((guide.newsletter_quota_today() ->> 'fits')::boolean, false) then
        raise exception 'newsletter_quota' using errcode = '23514';
      end if;
      new.approved_at := now();
      new.approved_by := (select auth.uid());
      new.scheduled_for := now() + interval '1 hour';
    else
      new.approved_at := null;
      new.approved_by := null;
      new.scheduled_for := null;
    end if;
  else
    new.approved_at := old.approved_at;
    new.approved_by := old.approved_by;
    new.scheduled_for := old.scheduled_for;
  end if;
  return new;
end;
$$;
