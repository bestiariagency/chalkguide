-- F6.12 (c): reject_reason legible como el resto de columnas públicas. Solo tiene valor en descartados, que la RLS
-- oculta a anon y no admin; lo necesita el RETURNING de set_event_status (invoker). Idempotente.
grant select (reject_reason) on guide.events to anon, authenticated;
