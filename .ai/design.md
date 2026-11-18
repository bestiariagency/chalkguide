# Diseño UI/UX · ChalkGuide

## Método

buho-pixel diseña directamente, sin depender de Pencil ni de ninguna herramienta externa. Hay dos
productos con identidad propia:

1. **Sitio público** (audiencia): editorial, bilingüe, mobile-first.
2. **Panel `/administrador`** (Xavi): herramienta profesional de gestión, independiente del sitio.

Flujo de **propuesta → ping-pong → aprobación** antes de implementar:
- Propuestas como **mockups HTML estáticos** autocontenidos (Tailwind vía CDN, datos de ejemplo
  realistas), en `docs/design/site/` y `docs/design/admin/`, que se abren en el navegador.
  Cada mockup debe verse bien en desktop (1440) y móvil (390).
- Cuando hay que elegir rumbo, presentar 2–3 direcciones distintas, cada una con nombre, intención y
  pros/contras, y una recomendación.
- Spec en markdown junto a los mockups (`README.md` de la carpeta): tokens, tipografía, rejilla,
  componentes, estados y responsive, lista para coneja-lucky.
- Al aprobarse, los tokens pasan a `@theme` en `app/assets/css/main.css` (vía coneja-lucky). Los
  tokens actuales son provisionales.

## Sitio público

- Referencia: **Mama Proof para escaladores**. Editorial, práctico, datos concretos.
- La **reseña del autor** domina la ficha; las opiniones de usuarios van debajo, con menos peso.
- Datos comparables: tablas y comparadores legibles en móvil (comparador de pies de gato lado a lado,
  filtros y rango de precio).
- Transparencia visible: "visita invitada", "enlace de afiliado", fecha de verificación del dato.
- Promedio de usuarios solo con ≥ 3 opiniones; si no, estado vacío digno, no un "0".
- CTA de newsletter presente pero no invasivo; nada de dark patterns.
- Los layouts aguantan textos en español (más largos) e inglés.

## Panel de administración

- Referencias: Linear, Vercel, Supabase Studio, Notion, Ghost admin. Profesional, denso pero claro.
- Navegación lateral persistente, buscador, migas de pan, acciones primarias consistentes.
- Tablas de datos con orden, filtros, búsqueda, paginación y acciones masivas.
- Editores con autoguardado o aviso de cambios sin guardar, vista previa, estados de publicación claros.
- Acciones destructivas con confirmación explícita; feedback con toasts.
- Desktop-first, pero usable en tablet y móvil para tareas rápidas (moderar, aprobar).
- Tokens propios del panel (no heredar la estética editorial del sitio).

## Qué se evalúa

- **Gráfica**: jerarquía tipográfica, espaciado en escala de 4 px, alineación, consistencia, uso de tokens.
- **UX/UI**: claridad de flujos, estados (hover, focus, active, disabled, loading, vacío, error, éxito),
  microinteracciones 120–200 ms con `prefers-reduced-motion`.
- **Responsive**: 1440 / 768 / 390; táctiles ≥ 44 px; sin scroll horizontal.
- **Contraste**: WCAG AA (texto 4.5:1, UI 3:1), foco siempre visible.
- **Accesibilidad**: labels visibles, errores con icono + texto + `aria-*`, teclado completo.

## Veredicto

**APROBADO**, o **CAMBIOS** + lista (elemento, viewport, esperado, actual, severidad).
