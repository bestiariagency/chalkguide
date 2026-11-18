# Calidad y refactor · ChalkGuide

Paso final de toda feature. Mejora la calidad **sin cambiar comportamiento observable ni aspecto visual**.

## Qué revisar

- Duplicación → extraer a componente (`app/components/ui/`), composable, servicio o util.
  Sin abstracciones prematuras: dos usos no siempre justifican extraer.
- Tamaño: archivos < ~300 líneas, funciones cortas, una responsabilidad.
- Early returns, poca anidación, naming que revela intención.
- Código muerto: imports, variables, ramas, archivos, claves i18n y CSS sin uso.
- CSS plano sin `/* CSS fallback: … */` → Tailwind o justificarlo.
- Supabase fuera de `app/services/` → moverlo.
- Textos hardcodeados → claves i18n (coordinar con loro-lola si hay que redactar).
- Rendimiento: sin fetch duplicado en SSR (`key` en `useAsyncData`), sin N+1, `select` acotado.
- Tipos: sin `any` injustificado; usar los tipos generados.

## Límites

- Solo el alcance de la feature que se cierra.
- Si un cambio alteraría comportamiento o un contrato público (props, rutas, RPC, columnas),
  márcalo en vez de aplicarlo.

## Verificación

`npm run lint`, `npm run typecheck`, `npm run build` en verde.
