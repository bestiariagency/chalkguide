-- Newsletter › Email de bienvenida (README §21, F4.6 apéndice «Email de bienvenida»).
-- Paso 1/2: nuevo tipo de trabajo del outbox. Va solo porque ALTER TYPE … ADD VALUE no puede usarse en la misma
-- transacción que lo crea (índices y CHECK del paso 2 lo nombran). Idempotente. Cero cambios en public.
alter type guide.outbox_kind add value if not exists 'welcome_email';
