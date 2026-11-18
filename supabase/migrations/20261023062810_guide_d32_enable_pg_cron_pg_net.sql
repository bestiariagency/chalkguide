-- D32 · Limpieza diaria de fotos de opiniones (F6.11b): pg_cron + pg_net como recomienda Supabase.
-- pg_cron crea su schema `cron`; pg_net, su schema `net` (registrado en `extensions`). Nada en `public`. Idempotente.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
