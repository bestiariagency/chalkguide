-- D33-1 (leona-lia): la guarda de discard_expired_event_drafts exige además current_user = 'postgres' (el dueño del job
-- de pg_cron). Así sigue cerrada aunque alguien conceda EXECUTE por error a otro rol con BYPASSRLS (service_role) desde
-- SQL directo, donde no hay claims. Idempotente.
create or replace function guide.discard_expired_event_drafts()
returns integer
language plpgsql
set search_path = ''
as $$
declare
  v_prev text := coalesce(current_setting('guide.draft_op', true), '');
  v_n    integer;
begin
  if current_user <> 'postgres'
     or not coalesce((select r.rolbypassrls from pg_catalog.pg_roles r where r.rolname = current_user), false)
     or coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb ? 'role' then
    raise exception 'maintenance only' using errcode = '42501';
  end if;
  perform set_config('guide.draft_op', 'maintenance', true);
  update guide.events e
  set status = 'rejected', reject_reason = 'expired'
  where e.status = 'draft'
    and guide.event_is_past(e.starts_at, e.ends_at, e.all_day);
  get diagnostics v_n = row_count;
  perform set_config('guide.draft_op', v_prev, true);
  return v_n;
end;
$$;
revoke all on function guide.discard_expired_event_drafts() from public, anon, authenticated, service_role;
