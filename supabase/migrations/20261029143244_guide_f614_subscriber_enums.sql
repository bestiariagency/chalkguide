-- F6.14 (D35) · Suscriptores, parte 1: estados nuevos (expired = Caducado sin confirmar; erased = supresión RGPD) y el
-- estado de sincronización con el proveedor (Brevo, F4.6). Va sola: un valor de enum nuevo no se puede usar en la
-- misma transacción que lo crea. Idempotente.
alter type guide.subscriber_status add value if not exists 'expired';
alter type guide.subscriber_status add value if not exists 'erased';

do $$
begin
  if not exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace
                 where n.nspname = 'guide' and t.typname = 'brevo_sync_status') then
    create type guide.brevo_sync_status as enum ('not_synced', 'pending', 'synced', 'error');
  end if;
end $$;
