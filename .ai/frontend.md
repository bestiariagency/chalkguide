# Frontend · ChalkGuide

## Stack

Nuxt 4 (`app/`), Vue 3 `<script setup lang="ts">`, Tailwind CSS v4 vía `@tailwindcss/vite`,
`@nuxtjs/i18n`, `@nuxt/image`, `@nuxtjs/supabase`.

## Reglas

- **Tailwind-first**: utilidades y tokens de `@theme` (`app/assets/css/main.css`). CSS plano solo si
  Tailwind no puede, con `/* CSS fallback: <motivo> */`. Nada de colores o medidas sueltas.
- **Diseño**: implementa los mockups y specs aprobados de `docs/design/` (site/ o admin/). Si falta
  un token o una decisión visual, pídelo a buho-pixel vía SúperXavi en vez de inventarlo.
- **Textos**: siempre `$t()` / `useI18n()` con claves en `i18n/locales/es.json` y `en.json`
  (ambos a la vez). Nunca hardcodear. Contenido largo (artículos, reseñas) viene de datos, no de i18n.
- **Supabase**: solo desde `app/services/*`, con `useSupabaseClient().schema('guide')`.
  Componentes y páginas nunca llaman a Supabase directamente. Tipos desde `app/types/database.types.ts`.
- **Datos en páginas**: `useAsyncData`/`useFetch` con `key` estable para SSR/prerender sin doble fetch.
- **Render híbrido**: páginas editoriales estáticas → `prerender`; fichas y listados con datos vivos
  → SSR (o `swr`/`isr` si osset-op lo define). Cada ruta nueva se registra en `routeRules` (es y `/en`).
- **Rutas localizadas**: `NuxtLinkLocale` / `localePath()`; nunca enlaces con prefijo a mano.
- **Lógica**: negocio en composables/servicios/utils (índices derivados, promedio de usuarios solo
  con ≥ 3 opiniones). Componentes presentacionales.
- **Login**: Google vía Supabase Auth, solo para opinar. Las fichas se ven completas sin login.
- **Jerarquía de ficha**: reseña del autor arriba y destacada (con aviso si la visita fue invitada);
  opiniones de usuarios debajo.
- **Newsletter**: casilla "quiero recibir novedades" desmarcada por defecto; nunca se infiere del login.
- **Afiliados**: enlaces con `rel="sponsored nofollow noopener"` y marca visible.
- **Datos de usuario** (nombres, opiniones, cualquier texto que venga de lectores): siempre como
  texto interpolado, **nunca** con `v-html`. El único HTML que se renderiza es el del contenido
  editorial, ya sanitizado en origen.

## Panel `/administrador`

- Experiencia independiente: layout `admin` propio, componentes en `app/components/admin/`,
  tokens propios del panel según la spec de buho-pixel. No reutilizar componentes editoriales del sitio.
- Rutas `/administrador/**`: `ssr: false`, `robots: false`, fuera del sitemap y sin prefijo de idioma
  (UI solo en español; el contenido se edita en es y en).
- Guard de ruta: sin sesión → login del panel; con sesión pero sin `guide.is_admin()` → fuera.
  La seguridad real es RLS; el guard es solo UX.
- Nada de pantallas sin propuesta aprobada en `docs/design/admin/`.
- Librerías (D7, instaladas en F6.1, se usan desde 6.2): `reka-ui` (headless: Dialog, Toast, Tabs,
  Popover... estilado con utilidades `adm-*`) y `@tanstack/vue-table` (lógica de tablas; el marcado
  `<table>` es nuestro). Envolverlas en `app/components/admin/`; nada de estilos propios de la librería.
- Base (F6.1): tokens `adm-*` en `app/assets/css/admin.css` (scope `.admin`), clases comunes en
  `app/utils/admin-classes.ts`, menú en `app/utils/admin-nav.ts`, guard global
  `app/middleware/admin.global.ts`, páginas con `definePageMeta({ i18n: false })` (sin `/en`).

## Calidad

- a11y: HTML semántico, foco visible, labels, contraste AA, `alt` útil, navegación por teclado.
- Mobile-first: sin scroll horizontal, objetivos táctiles ≥ 44 px.
- Imágenes con `<NuxtImg>`, dimensiones explícitas y `loading="lazy"` fuera del primer viewport.
- Estados: cargando, vacío, error y éxito en todo lo que dependa de datos.
