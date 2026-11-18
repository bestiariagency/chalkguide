# Convenciones comunes · ChalkGuide

## Repo

```
app/
  assets/css/main.css   tokens @theme (provisionales) + Tailwind
  components/           UI; subcarpetas por dominio (gyms/, shoes/, reviews/, ui/)
  composables/          estado y lógica reutilizable (useXxx)
  layouts/ pages/       rutas; pages finas, sin lógica de negocio
  services/             único punto de acceso a Supabase (funciones puras que reciben el cliente)
  types/                database.types.ts (generado) y tipos de dominio
  utils/                helpers puros (formato de precios, índices derivados…)
i18n/locales/           es.json (por defecto), en.json
server/api/             endpoints Nitro (nunca prerender, nunca indexados)
supabase/migrations/    copia versionada de cada migración aplicada
docs/                   plan de producto y specs (docs/design/)
.ai/                    estándares por disciplina (autoritativos)
```

## Código

- TypeScript estricto; nada de `any` sin comentario que lo justifique.
- Vue `<script setup lang="ts">` + Composition API. Archivos < ~300 líneas.
- Naming: componentes `PascalCase`, composables `useCamelCase`, archivos de servicio `kebab-case`,
  columnas y tablas SQL `snake_case` en inglés.
- Código e identificadores en inglés; textos visibles y documentación en español.
- Comentarios solo para el *porqué*, no para el *qué*.

## Verificación

`npm run lint`, `npm run typecheck` y `npm run build` en verde antes de entregar.
`npm run format` si se tocaron muchos archivos.
Si se tocaron textos o claves i18n: `node scripts/check-i18n.mjs` (mismas claves en es/en y ninguna
clave usada sin definir; las dinámicas `t(\`x.${y}\`)` se revisan a mano).

## Git

Nadie del equipo hace commit, push ni operaciones destructivas de git. Xavi commitea.

## Datos y fechas

- Precios en EUR con fecha de verificación; todo dato de ficha lleva `verified_at` y fuente.
- Fechas en ISO en BD; formateo por locale en la UI.

## Entregas

Resumen corto: qué se hizo, qué falta, riesgos. Sin volcar archivos, esquemas ni logs completos.
