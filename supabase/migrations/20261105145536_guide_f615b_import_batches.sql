-- F6.15b (D50): lotes de importación de fichas. Solo admin; sin grant a anon.
-- No se añade import_batch_id a guide.items: authenticated tiene SELECT de toda la tabla y la columna se vería.

create table if not exists guide.import_batches (
  id          uuid primary key default gen_random_uuid(),
  category    text not null references guide.item_categories (key),
  status      text not null default 'applied',
  row_count   integer not null default 0,
  chunks      integer not null default 0,
  counts      jsonb not null default '{}'::jsonb,
  created_by  uuid default auth.uid() references auth.users (id) on delete set null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint import_batches_status_check check (status in ('applied', 'partially_undone', 'undone')),
  constraint import_batches_row_count_check check (row_count between 0 and 500),
  constraint import_batches_chunks_check check (chunks between 0 and 5),
  constraint import_batches_counts_check check (jsonb_typeof(counts) = 'object' and octet_length(counts::text) <= 2000)
);
comment on table guide.import_batches is
  'F6.15b (D50). Un lote = una importación de fichas (uno o varios trozos de hasta 100 filas, máx. 500). Sin datos de las filas.';

create table if not exists guide.import_batch_items (
  batch_id      uuid not null references guide.import_batches (id) on delete cascade,
  item_id       uuid not null references guide.items (id) on delete cascade,
  action        text not null,
  version_after timestamptz not null,
  undone_at     timestamptz,
  primary key (batch_id, item_id),
  constraint import_batch_items_action_check check (action in ('created', 'updated', 'drafted'))
);
comment on table guide.import_batch_items is
  'F6.15b. Qué hizo cada lote con cada ficha. version_after: draft_entity_version (created/updated) o updated_at del borrador (drafted); deshacer exige que no haya cambiado.';
create index if not exists import_batch_items_item_idx on guide.import_batch_items (item_id);
create index if not exists import_batches_created_at_idx on guide.import_batches (created_at desc);

alter table guide.import_batches enable row level security;
alter table guide.import_batch_items enable row level security;

revoke all on guide.import_batches from public, anon, authenticated;
revoke all on guide.import_batch_items from public, anon, authenticated;
grant select, insert, update on guide.import_batches to authenticated;
grant select, insert, update on guide.import_batch_items to authenticated;
-- Sin DELETE: los lotes no se borran (los ítems desaparecen en cascada con su ficha).

drop policy if exists import_batches_select on guide.import_batches;
drop policy if exists import_batches_insert on guide.import_batches;
drop policy if exists import_batches_update on guide.import_batches;
create policy import_batches_select on guide.import_batches for select to authenticated using ((select guide.is_admin()));
create policy import_batches_insert on guide.import_batches for insert to authenticated with check ((select guide.is_admin()));
create policy import_batches_update on guide.import_batches for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));

drop policy if exists import_batch_items_select on guide.import_batch_items;
drop policy if exists import_batch_items_insert on guide.import_batch_items;
drop policy if exists import_batch_items_update on guide.import_batch_items;
create policy import_batch_items_select on guide.import_batch_items for select to authenticated using ((select guide.is_admin()));
create policy import_batch_items_insert on guide.import_batch_items for insert to authenticated with check ((select guide.is_admin()));
create policy import_batch_items_update on guide.import_batch_items for update to authenticated
  using ((select guide.is_admin())) with check ((select guide.is_admin()));

drop trigger if exists import_batches_set_updated_at on guide.import_batches;
create trigger import_batches_set_updated_at before update on guide.import_batches
  for each row execute function guide.set_updated_at();

-- Registro: una entrada por trozo aplicado ('import') y por deshacer ('import_undo'). Sin datos ni nombre de archivo.
-- DEFINER porque activity_log no tiene grant de INSERT; solo se ejecuta como trigger.
create or replace function guide.import_batches_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_action guide.activity_action;
begin
  if pg_catalog.pg_trigger_depth() = 0 then
    raise exception 'trigger only' using errcode = '42501';
  end if;
  if new.chunks > old.chunks then
    v_action := 'import';
  elsif (new.counts -> 'undo') is distinct from (old.counts -> 'undo') then
    v_action := 'import_undo';
  else
    return null;
  end if;
  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, details)
  values ((select auth.uid()), v_action, 'import_batches', new.id::text, new.category,
          jsonb_build_object('category', new.category, 'status', new.status, 'rows', new.row_count,
                             'chunks', new.chunks, 'counts', new.counts));
  return null;
end;
$$;
revoke all on function guide.import_batches_log() from public, anon, authenticated;

drop trigger if exists import_batches_log on guide.import_batches;
create trigger import_batches_log after update on guide.import_batches
  for each row execute function guide.import_batches_log();

-- Las entradas por ficha de un lote llevan details.import_batch (GUC local que fija admin_import_items) para agruparlas.
-- Falsificar el GUC solo cambia la agrupación en Actividad, no permisos.
create or replace function guide.log_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  c_skip      constant text[] := array['search_es', 'search_en'];
  v_id_col    text := coalesce(nullif(tg_argv[0], ''), 'id');
  v_label_col text := nullif(coalesce(tg_argv[1], ''), '');
  v_snapshot  boolean := coalesce(nullif(tg_argv[2], ''), 'true')::boolean;
  v_batch     text := nullif(current_setting('guide.import_batch', true), '');
  v_new       jsonb;
  v_old       jsonb;
  v_row       jsonb;
  v_changed   text[];
begin
  if tg_op in ('INSERT', 'UPDATE') then v_new := to_jsonb(new) - c_skip; end if;
  if tg_op in ('UPDATE', 'DELETE') then v_old := to_jsonb(old) - c_skip; end if;
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

  insert into guide.activity_log (actor_id, action, entity_table, entity_id, entity_label, changed_columns, old_row, details)
  values (
    (select auth.uid()),
    lower(tg_op)::guide.activity_action,
    tg_table_name,
    coalesce(v_row ->> v_id_col, '?'),
    case when v_label_col is not null then left(v_row ->> v_label_col, 200) end,
    v_changed,
    case when tg_op = 'DELETE' and v_snapshot then v_old end,
    case when v_batch ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
         then jsonb_build_object('import_batch', v_batch) end
  );
  return null;
end;
$$;
