-- F2.3 · Superadmin (guide.admins + guide.is_admin) y registro de actividad.

create table if not exists guide.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  email      text not null,
  created_at timestamptz not null default now()
);
alter table guide.admins enable row level security;

-- Fuente única del rol admin. SECURITY DEFINER: lee guide.admins sin pasar por su RLS (sin recursión).
create or replace function guide.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from guide.admins a where a.user_id = (select auth.uid()));
$$;
revoke execute on function guide.is_admin() from public;
grant execute on function guide.is_admin() to anon, authenticated, service_role;

-- Lanza 42501 si quien llama no es admin. Para RPC del panel (que además son SECURITY INVOKER).
create or replace function guide.assert_admin()
returns void
language plpgsql
stable
set search_path = ''
as $$
begin
  if not guide.is_admin() then
    raise exception 'admin only' using errcode = '42501';
  end if;
end;
$$;
revoke execute on function guide.assert_admin() from public;
grant execute on function guide.assert_admin() to authenticated, service_role;

create table if not exists guide.activity_log (
  id              bigint generated always as identity primary key,
  occurred_at     timestamptz not null default now(),
  actor_id        uuid references auth.users (id) on delete set null,
  action          guide.activity_action not null,
  entity_table    text not null,
  entity_id       text not null,
  entity_label    text,
  changed_columns text[],
  old_row         jsonb
);
alter table guide.activity_log enable row level security;
create index if not exists activity_log_occurred_at_idx on guide.activity_log (occurred_at desc);
create index if not exists activity_log_entity_idx on guide.activity_log (entity_table, entity_id);
create index if not exists activity_log_actor_id_idx on guide.activity_log (actor_id);

-- Trigger genérico. Args: [0] columna id, [1] columna etiqueta ('' = ninguna), [2] guardar fila al borrar ('true'/'false').
create or replace function guide.log_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id_col    text := coalesce(nullif(tg_argv[0], ''), 'id');
  v_label_col text := nullif(coalesce(tg_argv[1], ''), '');
  v_snapshot  boolean := coalesce(nullif(tg_argv[2], ''), 'true')::boolean;
  v_new       jsonb;
  v_old       jsonb;
  v_row       jsonb;
  v_changed   text[];
begin
  if tg_op in ('INSERT', 'UPDATE') then v_new := to_jsonb(new); end if;
  if tg_op in ('UPDATE', 'DELETE') then v_old := to_jsonb(old); end if;
  v_row := coalesce(v_new, v_old);

  if tg_op = 'UPDATE' then
    select array_agg(n.key order by n.key) into v_changed
    from jsonb_each(v_new) n
    where n.key not in ('updated_at', 'updated_by')
      and n.value is distinct from (v_old -> n.key);
    if v_changed is null then
      return null;
    end if;
  end if;

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, old_row)
  values (
    (select auth.uid()),
    lower(tg_op)::guide.activity_action,
    tg_table_name,
    coalesce(v_row ->> v_id_col, '?'),
    case when v_label_col is not null then left(v_row ->> v_label_col, 200) end,
    v_changed,
    case when tg_op = 'DELETE' and v_snapshot then v_old end
  );
  return null;
end;
$$;
revoke execute on function guide.log_activity() from public;

drop trigger if exists admins_log_activity on guide.admins;
create trigger admins_log_activity
  after insert or update or delete on guide.admins
  for each row execute function guide.log_activity('user_id', 'email', 'true');

-- Grants
grant select on guide.admins to authenticated;
grant select on guide.activity_log to authenticated;
grant all on guide.admins, guide.activity_log to service_role;
grant usage, select on all sequences in schema guide to service_role;

-- Policies
drop policy if exists admins_select on guide.admins;
create policy admins_select on guide.admins
  for select to authenticated
  using (user_id = (select auth.uid()) or (select guide.is_admin()));

drop policy if exists activity_log_select on guide.activity_log;
create policy activity_log_select on guide.activity_log
  for select to authenticated
  using ((select guide.is_admin()));
