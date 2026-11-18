-- Introspection of the `guide` schema for scripts/gen-guide-types.mjs.
-- Run it (e.g. via the Supabase MCP execute_sql or the SQL editor), save the JSON result to a
-- file and pass that file to the generator. Needed because the MCP type generator only emits `public`.
with cols as (
  select c.table_name, c.column_name, c.ordinal_position, c.is_nullable, c.column_default, c.is_generated, c.is_identity,
         c.data_type, c.udt_schema, c.udt_name
  from information_schema.columns c where c.table_schema = 'guide'
),
rels as (
  select c.relname, c.relkind from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'guide' and c.relkind in ('r', 'v', 'm')
),
enums as (
  select t.typname, json_agg(e.enumlabel order by e.enumsortorder) labels
  from pg_type t join pg_enum e on e.enumtypid = t.oid join pg_namespace n on n.oid = t.typnamespace
  where n.nspname = 'guide' group by t.typname
),
doms as (
  select t.typname, bt.typname as base from pg_type t join pg_namespace n on n.oid = t.typnamespace
  join pg_type bt on bt.oid = t.typbasetype where n.nspname = 'guide' and t.typtype = 'd'
),
funcs as (
  select p.proname, pg_get_function_arguments(p.oid) args, pg_get_function_result(p.oid) result
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'guide' and p.prokind = 'f'
    and has_function_privilege('authenticated', p.oid, 'execute')
    and pg_get_function_result(p.oid) <> 'trigger'
),
fks as (
  select con.conname, cl.relname tbl, array_agg(a.attname order by k.ord) cols, rcl.relname ref,
         array_agg(ra.attname order by k.ord) refcols
  from pg_constraint con
  join pg_class cl on cl.oid = con.conrelid join pg_namespace n on n.oid = cl.relnamespace
  join pg_class rcl on rcl.oid = con.confrelid join pg_namespace rn on rn.oid = rcl.relnamespace
  cross join lateral unnest(con.conkey, con.confkey) with ordinality k(attnum, refattnum, ord)
  join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum
  join pg_attribute ra on ra.attrelid = con.confrelid and ra.attnum = k.refattnum
  where con.contype = 'f' and n.nspname = 'guide' and rn.nspname = 'guide'
  group by con.conname, cl.relname, rcl.relname
)
select json_build_object(
  'rels', (select json_agg(rels) from rels),
  'cols', (select json_agg(cols order by table_name, ordinal_position) from cols),
  'enums', (select json_object_agg(typname, labels) from enums),
  'doms', (select json_object_agg(typname, base) from doms),
  'funcs', (select json_agg(funcs) from funcs),
  'fks', (select json_agg(fks) from fks)
) as meta;
