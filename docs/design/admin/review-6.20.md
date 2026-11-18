# 6.20 · Revisión de diseño integral del panel

- Revisor: buho-pixel
- Fecha: 2026-11-13
- Método: solo por código. La extensión de Chrome no conecta, así que el pase visual a 1440, 768 y 390 queda pendiente (ver «Solo en navegador»).
- Veredicto: **CAMBIOS**. 1 bloqueante, 7 importantes y 13 menores. El panel es sólido: los tokens se usan bien, el foco global está bien resuelto y modal, toast y tabla siguen la spec.

Decisión de SúperXavi sobre I1c: se toma la alternativa. La fila `cleanup` pasa a ser un aviso no clicable, sin banda nueva en Opiniones › Fotos. Así no hace falta una pantalla nueva.

## Bloqueante

**B1 · La lupa de la barra móvil sigue desactivada.** `app/components/admin/AdminMobileBar.vue:21-29` tiene `aria-disabled` y «Próximamente», pero ⌘K ya funciona y §15.7 dice que en < 768 se abre desde la lupa. Quitar `aria-disabled` y `title`; añadir `@click="openPalette"` (de `useAdminPalette`), `aria-label="Buscar o ir a…"` y `aria-haspopup="dialog"`.

## Importantes

**I1 · Fila `cleanup` del Inicio.**

- a) `app/utils/admin-dashboard-pending.ts:162-177`: el contexto tiene unos 180 caracteres y rompe el patrón de la fila (línea 2 = contexto corto). Entre 1024 y 1279, con 3 columnas, ocupa 6–8 líneas. Dejarlo en 70 caracteres como máximo, por ejemplo «Las fotos rechazadas o caducadas pueden no estar borrándose». Textos: loro-lola.
- b) El fallo confirmado (estado distinto de 200) usa el tono `warn`, igual que «sin comprobar». Añadir `PendingTone 'danger'` (`bg-adm-danger-soft text-adm-danger`, en `Pending.vue:21-26`) solo para el fallo, con icono `CircleAlert`. «Nunca comprobada» y «más de 48 h» siguen en `warn` con `TriangleAlert`.
- c) El destino `opiniones?vista=photos` (`:187`) no ayuda a arreglar el problema. Se quita el enlace: la fila queda como aviso no clicable (decisión arriba). Como el remedio («Edge Function secrets» y «Vault») ya no cabe en el contexto corto, debe quedar accesible de otro modo, por ejemplo en un `title` o una ayuda desplegable de la propia fila. Lo decide coneja-lucky con el patrón existente.
- d) Que vaya primera dentro de «Revisar» está bien.

**I2 · Objetivo táctil de la franja de vista previa.** En `articulos/[id]/vista-previa.vue:41` y `paginas/[key]/vista-previa.vue:41`, `max-md:min-h-11` está sobre un `<a>` en línea y no tiene efecto (unos 28 px). Usar `inline-flex items-center min-h-11 md:min-h-0 px-3` en el enlace EN y lo mismo en el span ES.

**I3 · Estado «Preparando la vista previa…»** (`:47` en las dos páginas).

- Mostrarlo solo si tarda más de 300 ms (`useDebouncedValue(flag, 300)`, como en Categorías y Autores), con `Loader2` animado y `motion-reduce:animate-none`, y `aria-busy="true"` en el contenedor.
- Quitar `role="status"` del `<p>` de la etiqueta (`:35` / `:38`): ahora se anuncian dos cosas a la vez.
- El vacío «Todavía no hay contenido en…» (`:48`) pasa a `AdminStateBlock kind="empty"` con la acción «Volver al editor».
- Envolver el contenido en `<main id="contenido">`.
- Las dos páginas duplican la franja: extraer `AdminPreviewStrip`.

**I4 · Drawer del menú en < 768** (`AdminSidebar.vue:47-56` y `useAdminMenu.ts`). No atrapa el foco, no lo mueve al abrir, no lo devuelve al cerrar y no bloquea el scroll. La transición de 200 ms no lleva `motion-reduce:transition-none`. En < 768, montarlo en Reka `DialogRoot`/`DialogContent` (como `AdminModal`), o añadir `useFocusTrap` más `inert` en `main`, foco al botón Cerrar y vuelta al botón Menú.

**I5 · Objetivos táctiles de menos de 44 px en móvil.**

- `exports/Rows.vue:44`: `max-md:size-7` → `max-md:size-11`.
- `AdminTableToolbar.vue:49`: `max-md:size-9` → `max-md:size-11`.
- `items/ChipsField.vue:30`: `max-md:size-8` → `max-md:size-11`.

**I6 · Dos botones primarios en la misma vista.** El toggle «Destacados» usa `admBtnPrimary` cuando está pulsado (`articulos/index.vue:136`, `items/List.vue:158`), y §4.2 pide un solo primario. Crear `admBtnPressed` = `admBtnGhost` + `aria-pressed:border-adm-acc aria-pressed:bg-adm-acc-soft aria-pressed:text-adm-acc`, y aplicarlo también a los ámbitos de ⌘K (`AdminCommandPalette.vue:75`).

**I7 · `AdminDataTable.vue`.** Lo aplica zorro-foxter al partir el archivo (6.21).

- `:107`: «sin resultados» solo se detecta por búsqueda; con filtros sale «Todavía no hay nada» y cada página lo reimplementa en `#empty`. Prop `filtered?: boolean`; `no-results` = `search || filtered`.
- `:165-166`: el texto dice «quita los filtros», pero el botón solo borra la búsqueda. Emitir `clear-filters` y mostrar «Quitar filtros» si `filtered`.
- `:205` frente a `:266-267`: el esqueleto es `animate-pulse` en escritorio y `animate-adm-skeleton` en móvil, que no anima (sin gradiente), y §14.6 prohíbe el brillo. Usar `animate-pulse motion-reduce:animate-none` en los dos y extraer `AdminTableSkeleton`.
- `:176, 191, 219, 230, 134`: clases `max-md:*` dentro de la tabla, que ya es `max-md:hidden`. Código muerto: borrarlas.
- `:323` y `AdminTablePager.vue:16`: dos regiones live que se anuncian dos veces, y dice «1 resultados». Quitar `aria-live` del pager y pluralizar en `:323`.
- `:132, 134`: sombra con valor suelto → token `--adm-shadow-edge` en `admin.css`.

## Menores

- **M1 · Escala tipográfica.** Fuera de 11·12·13·14·16·20·24·30–34 hay `text-[11.5px]` (×13), `[12.5px]` (×11), `[13.5px]`, `[15px]` (×7), `[22px]`, `[28px]` y `[10px]`. Cambiar 11.5→12, 12.5→13 (subscribers/Table, import/*, items/AssignCovers, dashboard/Calendar:54), 13.5→14 (`AdminPaletteOption.vue:25`), los 15 de Inspector, InspectorSeo y reviews/Detail a 14 o 16, y `AdminBottomNav.vue:32` `text-[10px]` → 11. Los 28 de los canvas del editor se quedan (título de documento) y se documentan. 10.5 solo en mono, kbd y etiqueta de idioma, como en el mockup.
- **M2 · Valores sueltos de paleta.** `admin-classes.ts:7, 39, 43` (`hover:bg-zinc-700`, `red-800`, `violet-800`) → tokens `--adm-primary-hover`, `--adm-danger-hover`, `--adm-st-rev-hover`, porque rompen el modo oscuro. `media/Grid.vue:32`: `bg-white/90 text-zinc-600` → `bg-adm-elev/90 text-adm-meta`. Fondo de capa: `AdminSidebar.vue:47` usa `bg-black/40` y Modal/Palette `bg-zinc-950/50` → un único token `--adm-scrim`.
- **M3 · Cabeceras.** 13 páginas copian a mano `header h-12 …`; `AdminPageBar` solo lo usan `estadisticas` y `[...slug]`. Ampliar `AdminPageBar` (`h1`, `count`, visible en móvil) y usarlo en todas. Lo aplica zorro-foxter.
- **M4 · Recuento del `h1` a 0 mientras carga** (`articulos/index.vue:92`, `items/List.vue:121`) → `v-if="!loading"`, como en Categorías.
- **M5 · «Quitar filtros» con tres estilos** (`subscribers/Chips.vue:22` enlace, `events/Empty.vue:19` silencioso, resto `admBtnGhost`) → `admBtnGhost` en todos.
- **M6 · Niveles de encabezado.** `AdminStateBlock.vue:32` usa siempre `h3` y se salta niveles bajo un `h1` sin `h2`. Prop `level`, por defecto `p` en seminegrita.
- **M7 · Retardo del esqueleto.** Solo `categorias.vue:15` y `autores.vue:15` esperan 300 ms. Generalizarlo con un composable `useDelayedFlag` a los 15 `Skeleton.vue`.
- **M8 · `prefers-reduced-motion`.** Falta en `AdminSwitch.vue:18, 20`, los chevrons de `editor/Inspector.vue:53-123` y `pages/Inspector.vue`, `editor/Cover.vue`, `editor/nodes/FigureView.vue` y `media/Uploads.vue` → `motion-reduce:transition-none`.
- **M9 · Estrella de destacado.** `aria-label` sobre un svg sin `role` (`articulos/index.vue:158`, `items/List.vue:175`) → `role="img"`, o `aria-hidden` + `<span class="sr-only">Destacado</span>`.
- **M10 · Tamaño de icono en conflicto.** `items/List.vue:156`: `admIconBtn` + `size-5` choca con el `size-8` de la base → `size-5!`.
- **M11 · Recarga de página.** `AdminConfirmDelete.vue:66`: `<a :href>` → `NuxtLink`.
- **M12 · Breakpoint fuera del sistema.** `editor/Header.vue:70`: `max-[1399px]:hidden` → `max-xl:hidden`, si «Volver a borrador» está en el menú ▾.
- **M13 · Etiqueta en `li`.** `dashboard/Calendar.vue:101`: `aria-label` en un `li` sin rol tiene poco soporte → texto `sr-only` dentro.

## Solo en navegador (1440 / 768 / 390)

1. Cabecera fija de la tabla: los `th` `sticky top-0` (`AdminDataTable.vue:128`) están dentro de `overflow-x-auto` (`:171`) y probablemente no se fijan al hacer scroll de página. Si falla, altura máxima con scroll interno o thead clonado.
2. Inicio entre 1024 y 1279 con la fila `cleanup`: altura de la fila y equilibrio de columnas.
3. En móvil, el toast y la barra de lote están los dos en `bottom-[76px]` (`AdminToaster.vue:54`, `AdminBulkBar.vue:22`): probable solape tras «Deshacer».
4. Contraste del foco `acc` sobre el toast de éxito (fondo tinta): unos 3:1, en el límite.
5. Contorno de foco de los eventos del calendario recortado por `overflow-hidden` (`dashboard/Calendar.vue:58`).
6. Prioridad del hover frente a la fila seleccionada en la tabla (`group-hover` frente a `group-data-[selected]`).
7. Franja de vista previa a 390: salto de línea, objetivo de 44 px y violeta de «con cambios».
8. Badges del raíl entre 768 y 1279 (`AdminSidebar.vue:106`).
9. Orden de tabulación del editor (cabecera → canvas → inspector) y trampas de foco en drawers apilados.

## Reparto

- coneja-lucky: B1, I1 (a, b, c), I2–I6 y M1, M2, M4–M13. Textos nuevos o cambiados → loro-lola.
- zorro-foxter: I7 y M3, al partir `AdminDataTable.vue` (cierre de 6.21).
- buho-pixel: segunda revisión por código y pase visual cuando conecte Chrome.

---

# Segunda revisión (por código)

- Fecha: 2026-11-13
- Método: solo por código (Chrome sigue sin conectar). El pase visual de «Solo en navegador» sigue pendiente.
- Veredicto: **CAMBIOS**. 3 importantes y 6 menores. B1, I1, I2, I4, I5, I6, I7 (salvo el texto), M1–M11 y M13 cumplen la spec. No hay etiquetas sin resolver: todas las `<Admin…>` corresponden a un componente (las demás coincidencias son tipos TS). Tokens nuevos presentes en claro y oscuro. El fallback global de `prefers-reduced-motion` (`main.css:545`) cubre también los `animate-adm-spin`.

## Decisiones

1. **M12 · «Volver a borrador».** Se añade al menú ▾. Ahora mismo, por debajo de 1400 px (incluido el móvil, `BottomBar.vue`), no hay forma de desprogramar un artículo: es un hueco funcional, no solo de breakpoint. En `PublishMenu.vue`, entrada «Volver a borrador» (icono `FilePen`) cuando `scheduled && !live`, antes de «Copiar enlace…» y con separador, emit `draft`. Conectarla en `editor/Header.vue:72`, en `editor/BottomBar.vue:5-6, 13-25` (prop ya existe, falta el emit) y en `articulos/[id]/index.vue:199` (`@draft="editor.backToDraft()"`). El botón de la cabecera (`Header.vue:70`) pasa a `max-xl:hidden`. A partir de 1280 la acción sale dos veces (botón y menú), y es aceptable: el botón es el atajo.
2. **`text-[22px]`.** `editor/nodes/NoteView.vue:11` se queda. Es una etiqueta de ámbito sitio (Caveat, `text-accent`, `aria-hidden`), versión reducida del 28 público, y la escala del panel no la gobierna. Queda documentado en README §4.1. `settings/AuthorPreview.vue:37` → `text-2xl leading-8` (24/32, paso de escala).
3. **Texto de «sin resultados».** El genérico no basta. Una pestaña vacía (Programados, Destacados) no es «otra búsqueda», y en tablas sin filtros «quita los filtros» es falso. No hace falta un slot: con props basta y las acciones siguen unificadas. Ver R4.
4. **Agenda y suscriptores sin `filtered`.** OK. Sus `#empty` distinguen ya el vacío filtrado y tienen acciones propias («Buscar en todos», «Quitar filtros», ambas `admBtnGhost`). Con búsqueda sin resultados entra el bloque genérico de la tabla, y es correcto.

## Importantes

- **R1 · I3 incompleto.** `components/admin/AdminPreviewStrip.vue:22`: el `<p>` de la etiqueta sigue con `role="status"`. Quitarlo. Cada cambio de idioma o de estado se anuncia junto con «Preparando…» y con el bloque vacío (`AdminStateBlock`, que ya es `status`).
- **R2 · Vacío falso en fichas filtradas.** `components/admin/items/List.vue:147, 149`: `filtered` solo mira `view` y `featuredOnly` (`useAdminItems.ts:19`). Con «Para publicar: listas/faltan» (`readyFilter`) o con el filtro de importación activo y 0 filas, sale «Todavía no hay {nouns}» + «Nuevo», y es falso. Esperado: `:filtered="items.filtering.value || readyFilter !== 'all' || importFilter.active.value"`, y `@clear-filters` que además ponga `readyFilter = 'all'` y llame a `importFilter.clear()`.
- **R3 · M12** (decisión 1).

## Menores

- **R4 · Copia de «sin resultados».** `AdminDataTable.vue:161`: props opcionales `noResultsTitle` y `noResultsDescription`. Descripción por defecto según el caso: solo búsqueda → «Prueba con otra búsqueda.»; solo `filtered` → «Prueba con otra vista o quita los filtros.»; ambos → la actual. `articulos/index.vue:105-121` pasa «Ningún artículo con estos filtros» / «Prueba con otra vista, categoría o autor.». `items/List.vue:132-149` pasa el equivalente con `info` (género con `feminine`). Textos: loro-lola.
- **R5 · Objetivos de 44 px que desbordan.** Con `max-md:size-11` el botón mide 44, pero su contenedor sigue midiendo 24–32.
  - `exports/Rows.vue:43`: `li` `max-md:h-8` con botón de 44. Pasar el `li` a `max-md:h-11`.
  - `items/ChipsField.vue:30` y `items/List.vue:155` (ficha de importación `h-6`): mantener el botón visual pequeño y agrandar el área táctil con `relative max-md:after:absolute max-md:after:-inset-3`, en lugar de `max-md:size-11`.
  - `AdminTableToolbar.vue:46`: el input tiene `pr-8` y el botón de borrar mide 44 en móvil, así que el texto queda debajo. Añadir `max-md:pr-12`.
- **R6 · `text-[22px]`** en `AuthorPreview.vue:37` (decisión 2).
- **R7 · Texto sobre botones de color en oscuro.** `utils/admin-classes.ts:39, 43`: `text-white` sobre `danger` oscuro `#f87171` da 2,8:1, y sobre `st-rev` `#c4b5fd` da 1,9:1 (con hover `#ddd6fe`, peor). Tokens `--adm-on-danger` y `--adm-on-rev` (`#fff` en claro y `#0e0e10` en oscuro). El modo oscuro no se activa en v1, así que no bloquea.
- **R8 · Escape del foco del drawer.** `layouts/admin.vue:17`: el enlace «Saltar al contenido» queda fuera del contenedor `inert`, así que con el drawer abierto Tab sale del diálogo hacia él. Añadirle `:inert="menuOpen || undefined"` (o moverlo dentro del contenedor).
- **R9 · Sangrado** (cosmético, para zorro-foxter): `AdminDataTable.vue:167-290`, `articulos/[id]/vista-previa.vue:34-51` y `paginas/[key]/vista-previa.vue:34-51`.

## Reparto

- coneja-lucky: R1, R2, R3, R5, R6, R7 y R8. R4, con los textos de loro-lola.
- zorro-foxter: R9.
- buho-pixel: tercera revisión de R1–R8 por código y pase visual cuando conecte Chrome.

# Tercera revisión (por código)

- Fecha: 2026-11-13
- Método: solo por código (Chrome sigue sin conectar). El pase visual de «Solo en navegador» sigue pendiente.
- Veredicto: **APROBADO** (por código).

R1–R9 cumplen:

- **R1.** `AdminPreviewStrip.vue:22`: el `<p>` ya no lleva `role="status"`.
- **R2.** `items/List.vue:30-35`: `filtered` incluye `readyFilter` y la importación, y `clearFilters` limpia las tres cosas.
- **R3.** «Volver a borrador» aparece en el menú ▾ cuando `scheduled && !live`, con separador y emit `draft`. Está conectado en `Header.vue:72`, `BottomBar.vue:6, 26` y `articulos/[id]/index.vue:153, 212`. El botón de la cabecera lleva `max-xl:hidden`.
- **R4.** `AdminDataTable.vue:100-105, 172`: los textos propios solo se aplican con `filtered`. Con búsqueda sola sale «Sin resultados» + «Prueba con otra búsqueda.».
- **R5.** `Rows.vue:43` (`li` con `max-md:h-11`), área táctil con `::after` en `ChipsField.vue:30` y `List.vue:162`, y `max-md:pr-12` en `AdminTableToolbar.vue:46`.
- **R6.** `AuthorPreview.vue:37` usa `text-2xl leading-8`.
- **R7.** Tokens `--adm-on-danger` y `--adm-on-rev` presentes en claro y en oscuro, usados en `admin-classes.ts:39, 43`.
- **R8.** `layouts/admin.vue:19`: el enlace de salto lleva `:inert`.
- **R9.** Sangrado corregido.

Sin regresiones: foco, `aria-*`, `motion-reduce` y tokens están bien, y no hay etiquetas sin resolver.

Menores no bloqueantes (para zorro-foxter):

- `items/Tabs.vue:44`: la insignia de errores usa `text-white` sobre `bg-adm-danger`. Pasar a `text-adm-on-danger` (solo afecta al modo oscuro, que no está activo en v1).
- `editor/PublishMenu.vue:8-9`: el comentario no menciona «Volver a borrador».

---

# Importador de fichas (6.15b): puntos para el pase visual 7.5b

- Fecha: 2026-11-13
- Origen: revisión de cierre de 6.15b, hecha solo por código. Estos puntos solo se pueden comprobar en el navegador y se suman a los 9 de «Solo en navegador».

10. Revisión entre 768 y 1279: resumen en 3 × 2, barra fija de acciones con «Importar sin las N con error…» y «Subir el archivo corregido» (que no se corten ni tapen la última fila de la tabla), y tabla de `min-w-[960px]` con scroll horizontal dentro de la tarjeta, sin scroll horizontal de página.
11. «Asignar portadas» a 390 (`items/AssignCovers.vue:38-44`): la rejilla móvil no define columnas y `max-md:col-span-2` crea dos implícitas en `auto`. Hay que comprobar que un nombre largo no desborde. Si desborda, usar `grid-cols-[auto_minmax(0,1fr)]` por debajo de 768. Comprobar también que el modal `lg` se ve como hoja inferior (§13.8).
12. «Publicar en lote» a 390: listas con `max-h-48` dentro del scroll del modal (doble scroll) y botones del pie de 44 px.
13. Barra fija del importador frente a los toasts (deshacer importación, errores): que no se solapen en 1024–1440.
14. Foco al cambiar de paso (archivo → leyendo → revisión → importando → resultado): después del arreglo pedido en la revisión de cierre, comprobar con teclado y VoiceOver que el foco cae en el título del paso y que se anuncia «Importación terminada».
