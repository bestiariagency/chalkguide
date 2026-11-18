-- F6.12 Agenda: estado «cancelado» (publicado pero anulado; el sitio lo muestra marcado hasta que pasa).
-- Va solo: un valor nuevo de enum no puede usarse en la misma transacción en que se añade. Idempotente.
alter type guide.event_status add value if not exists 'cancelled' after 'approved';
