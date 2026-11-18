# ChalkGuide · Diseño del panel `/administrador`

Propuestas de F5 (`docs/PLAN.md`). Autor: buho-pixel. Estado: 5.1–5.3 cerradas (**D23**: dirección A con tres préstamos de B). **5.4 y 5.5 en revisión de Xavi** (9 oct 2026).

Ver en el navegador (sirviendo desde la raíz del repo, `python3 -m http.server 8080`):
`http://localhost:8080/docs/design/admin/index.html`

| Archivo | Qué es |
| --- | --- |
| `index.html` | Índice de las propuestas del panel |
| `arquitectura.html` | 5.1 · Menú, rutas, patrones y los cinco flujos clave |
| `direccion-a-consola.html` | 5.2 · Dirección A: Inicio, Artículos y Editor (`#inicio`, `#articulos`, `#editor`), claro y oscuro |
| `direccion-b-taller.html` | 5.2 · Dirección B: las mismas tres pantallas |
| `anchos.html` | Marcos de 390 y 768 (5.5 y 5.2). Un solo marco: `anchos.html?solo=opiniones.html&w=390` |
| `design-system.html` | **5.4** · Design system del panel |
| `assets/admin.css`, `assets/admin.js` | **5.4** · Tokens y componentes de referencia; shell común de los mockups (menú, barra inferior, Nuevo, modales, toasts, arrastrar) |
| `login.html`, `inicio.html`, `articulos.html`, `articulo-editor.html`, `categorias.html`, `medios.html`, `rocodromo-editor.html`, `pie-de-gato-editor.html`, `resolador-editor.html`, `opiniones.html`, `suscriptores.html`, `exportar.html`, `actividad.html`, `ajustes.html` | **5.5** · Mockups sobre A
| `importar.html` | **F6.15b** · Importar fichas (§13): página por tipo, revisión previa, resultado, publicar en lote y asignar portadas |
| `inicio-v2.html` | **D52** · Inicio v2 (§14): Pendiente primero, calendario de dos semanas, tarjetas a su altura. Estados en el hash |
| `busqueda-cmdk.html` | **D53 · 6.22** · Búsqueda de contenido en ⌘K (§15). Interactiva; estados en el hash |
| `estadisticas.html` | **6.16** · Estadísticas (§16): suscriptores, artículos, opiniones, fichas y el hueco de visitas. Interactiva; estados en el hash |
| `ajustes-autores.html` | **6.17 · D51/D57/D60** · Autor del sitio en Ajustes y pantalla Autores en Editorial (§17). Interactiva; estados en el hash |

Marco común (D7): Reka UI (headless) + Tailwind v4, TanStack Table, gráficos ligeros. Iconos Lucide (trazo 1.75), como el sitio.
Solo español, un único superadmin, `ssr:false` y `noindex`. Desktop primero; tablet y móvil para tareas rápidas.

---

## 1 · Arquitectura de información (5.1)

Detalle y flujos paso a paso en `arquitectura.html`. Resumen:

**Menú (5 grupos + Inicio y Ajustes, 16 destinos).** Inicio · *Editorial*: Artículos, Categorías, Páginas · *Guías*: Rocódromos,
Resoladores, Pies de gato, Criterios de nota · *Comunidad*: Opiniones (contador de pendientes), Agenda (contador de
borradores del agente), Suscriptores · *Biblioteca*: Medios · *Datos*: Estadísticas, Exportar, Actividad · pie: Ajustes,
Ver sitio, sesión. Arriba: buscador/paleta `⌘K` y "Nuevo" (`C`).

**Patrones.** Página completa para lo que se escribe (artículo, ficha, página). Drawer lateral para entidades pequeñas
(medio, evento, categoría, suscriptor). Modal solo para confirmar o elegir (borrar, programar, selector de medios).
Filtros en la URL.

**Rutas** (`/administrador/…`): `entrar`, `/` (Inicio), `articulos[/nuevo|/:id]`, `categorias`, `paginas[/:key]`,
`rocodromos|resoladores|pies-de-gato[/nuevo|/:id]`, `criterios`, `opiniones`, `agenda`, `suscriptores`, `medios`,
`estadisticas`, `exportar`, `actividad`, `ajustes`.

**Ficha de rocódromo** (pestañas): General · Ubicación y horarios · Precios · Instalaciones (booleanos en tres estados
Sí/No/No lo sé, `grading_difficulty` y `setting_dynamism` 1–5) · Reseña y notas (tipo de visita con nota de
transparencia obligatoria si es invitada; notas 1–5 por criterio activo, media en vivo) · Galería · Relacionados · SEO.

**Reglas transversales.**
- Guardado: autoguardado en borradores (3 s); guardado explícito en programado/publicado; aviso de cambios sin guardar
  y copia local. **Sustituido en D23/5.4:** editar lo publicado crea un borrador de cambios con autoguardado (§4.3).
- Idiomas: conmutador ES/EN por editor; EN opcional con indicador de completitud (`has_en`) en editor y listados.
- Publicar o programar pasa por un checklist (título, categoría, portada con alt ES, extracto, SEO). Lo que bloquea
  frente a lo que solo avisa, en el flujo A.
- Destructivas: modal con objeto y consecuencia concretos; si hay alternativa reversible (ocultar, despublicar,
  desactivar), se ofrece antes.
- Toasts: éxito 5 s con "Deshacer"; error persistente con `role="alert"` y "Reintentar".
- Responsive: ≥ 1280 menú 240 + inspector; 768–1279 menú en raíl de 56 (A) o drawer (B) e inspector deslizante;
  < 768 drawer, tablas → tarjetas, táctiles ≥ 44.

---

## 2 · Direcciones (5.2)

### A · Consola (recomendada)

**Intención.** Herramienta de trabajo, no escaparate. Clara, densa, silenciosa: Linear, Vercel y Supabase Studio. La marca
aparece como hilo (naranja tostado en foco, selección, contadores y en la barra activa del menú), nunca como decoración.

- Shell: menú de 240 px en gris muy claro, barra superior de 48 px con migas y una sola acción primaria (tinta).
- Listado: vistas como pestañas con recuento (Todos, Publicados, Programados, Borradores, Sin EN), filtros en botones
  desplegables, filas de 40 px, columnas que se esconden por ancho, barra de lote flotante abajo.
- Editor: lienzo centrado de 760 px (título, slug, Tiptap con barra fija y menú `/`) e inspector de 340 px con secciones
  plegables: Publicación, Portada (alt ES/EN y color dominante), Organización, SEO con vista previa, Checklist.
  "Publicar ▾" abre el modal de programar con atajos de fecha y avisos.
- Tema claro y oscuro con los mismos nombres de token.

Pros: máxima densidad y legibilidad de datos (fichas con ~40 campos, tablas largas); separación clara entre "estoy
editando" y "esto es el sitio"; encaja 1:1 con Reka/TanStack; modo oscuro casi gratis; envejece bien.
Contras: menos "ChalkGuide"; puede sentirse genérico si no se cuida el detalle (tipografía, ritmo, microcopy).

### B · Taller

**Intención.** El panel como el taller del autor: la misma pizarra y el mismo papel que el sitio (§7 y §9 del README del
sitio). Densidad media y sensación de "estoy en mi medio".

- Shell: menú de pizarra (`#0f0f0f` + rejilla de tiza), contenido en papel `#F4F1EA`, etiquetas en JetBrains Mono
  mayúsculas, primario naranja de marca con barrido.
- Inicio: cuatro tarjetas grandes de pendientes, pizarra oscura de números y barras, calendario editorial del mes.
- Listado: segmentado de estado, chips de categoría con su color (filtran), filas de 60 px con miniatura de 48; al
  seleccionar, la barra de lote sustituye a los filtros.
- Editor: el artículo se edita sobre la "hoja" con la portada dentro, kicker, título de 40 px y entradilla (casi
  WYSIWYG). Panel lateral con pestañas Publicar / Portada / SEO; en móvil, hoja inferior con "Ajustes" y "Publicar".

Pros: identidad fuerte y coherente con la marca; muy agradable para escribir; el editor anticipa cómo se verá.
Contras: menos densidad (en tablas largas, ~35 % menos filas por pantalla); al parecerse tanto al sitio se confunde
edición y vista previa; el naranja de marca en todos los primarios compite con los estados; sin modo oscuro natural;
contradice la regla de `.ai/design.md` ("tokens propios del panel, no heredar la estética editorial").

### Recomendación

**A · Consola**, con tres préstamos de B:
1. **Calendario editorial** del mes en Inicio (sustituye a "Próximas publicaciones").
2. **Portada y entradilla dentro del lienzo** del editor (arriba del título), además de en el inspector.
3. **Panel del editor como hoja inferior** en móvil, con barra fija "Ajustes / Publicar".

Razones: el panel es una herramienta de uso diario y de datos (tablas, fichas, moderación), la densidad y la calma
pesan más que la atmósfera; `.ai/design.md` pide tokens propios e independencia del sitio; y separar visualmente el
panel del sitio reduce errores ("¿esto ya está publicado?"). La vista previa fiel del artículo ya existe: botón
"Vista previa" con el CSS real del sitio.

---

## 3 · Decisiones de D23 aplicadas

| Decisión de Xavi | Dónde se ve | Cómo |
| --- | --- | --- |
| A · Consola + calendario editorial en Inicio | `inicio.html` | Mes (lun–dom) con publicados, programados, publicados con cambios y agenda (casilla para ocultarla). Hoy en naranja; `+` en días libres para programar un borrador. En < 768, lista de las próximas dos semanas |
| Portada y entradilla dentro del lienzo | `articulo-editor.html` | Portada 16:9 arriba (Cambiar / Alt / color dominante al pasar), categoría, título, URL y **entradilla = extracto** (contador 300). Sigue también en el inspector (alt y color) |
| Ajustes del editor como hoja inferior en móvil | `articulo-editor.html` a 390 | Barra fija "Ajustes / Publicar cambios"; el inspector sube como hoja (88 dvh). 768–1279: drawer derecho; ≥ 1280: columna fija de 340 |
| Solo tema claro en v1, oscuro preparado | `design-system.html#tokens`, `assets/admin.css` | Mismos nombres de token bajo `.theme-dark`; muestra estática; sin conmutador |
| Editar lo publicado = borrador de cambios | editor de artículo, rocódromo, listados, Inicio, Actividad | §5.3 |
| Barra inferior móvil: Inicio, Opiniones, Medios, Nuevo | todas las pantallas a 390 | "Nuevo" abre la hoja Crear (Artículo, Rocódromo, Resolador, Pie de gato, Evento, Subir fotos). Los editores la sustituyen por su barra de acción |
| Exportaciones en Actividad | `exportar.html`, `suscriptores.html` (modal), `actividad.html` | Aviso discreto bajo el botón de descarga; en Actividad, pestaña "Exportaciones", fila con icono de descarga, insignia "Datos personales" y "Detalle" (quién, cuándo, filtros, columnas, filas, formato) |
| Opiniones en post-moderación (P2) | `opiniones.html` | La bandeja abre en **Recientes · 7 días**; "Nueva" = llegada desde tu última visita. "Pendientes" solo existe si se activa la premoderación en Ajustes |

---

## 4 · Design system (5.4) · spec para coneja-lucky

Referencia viva: `design-system.html`. CSS de referencia: `assets/admin.css` (no es para copiar tal cual: pasarlo a `@theme` + componentes Vue con Reka UI).

### 4.1 Tokens (layout `admin`, prefijo `adm-`)

Variables en `.admin` (claro, v1) y `.admin.dark` (preparado, sin conmutador); `@theme inline` las expone a Tailwind con prefijo `adm-` para no chocar con el sitio.

| Token | Claro (v1) | Oscuro (preparado) | Uso · contraste en claro |
| --- | --- | --- | --- |
| `bg` / `elev` | `#FFFFFF` | `#0E0E10` / `#131316` | Fondo, tarjetas, campos |
| `side` | `#FAFAFA` | `#0A0A0B` | Menú, cabecera de tabla |
| `subtle` | `#F4F4F5` | `#1A1A1D` | Hover, segmentado |
| `line` / `line-strong` | `#E4E4E7` / `#D4D4D8` | `#26262B` / `#34343A` | Solo decorativo |
| `control` | `#8B8B94` | `#6E6E78` | Borde de campo, casilla · 3.4 (UI) |
| `fg` | `#18181B` | `#EDEDEF` | Texto · 17.7 |
| `meta` | `#52525B` | `#A1A1AA` | Secundario · 7.7 |
| `muted` | `#71717A` | `#8B8B94` | Placeholder · 4.8 (**no** sobre `subtle`: 4.4) |
| `acc` / `acc-soft` | `#C2410C` / `#FFF1E8` | `#F59A52` / `#2A1709` | Foco, selección, contadores · 5.2 / 4.7 |
| `primary` / `on-primary` | `#18181B` / `#FFFFFF` | `#EDEDEF` / `#0E0E10` | Botón primario · 17.7 |
| `st-draft` (+`-bg`) | `#3F3F46` / `#F4F4F5` | `#D4D4D8` / `#232327` | Borrador · 9.5 |
| `st-sched` | `#1D4ED8` / `#DBEAFE` | `#93C5FD` / `#172554` | Programado · 5.5 |
| `st-pub` | **`#166534`** / `#DCFCE7` | `#86EFAC` / `#052E16` | Publicado, visible, activo · 6.5 (antes `#15803D`, 4.6) |
| `st-rev` (+`-bg`, `-line`) | **`#6D28D9`** / `#EDE9FE` / `#C4B5FD` | `#C4B5FD` / `#2E1065` | **Cambios sin publicar** (exclusivo) · 6.0; botón blanco sobre `st-rev` 7.1 |
| `st-hidden` (+`-line`) | `#52525B`, contorno discontinuo `#8B8B94` | `#A1A1AA`, `#6E6E78` | Oculto · 7.7 / 3.4 |
| `danger` / `-soft` | `#B91C1C` / `#FEE2E2` | `#F87171` / `#2A0E0E` | Error, eliminar · 5.3 |
| `warn` / `-soft` / `-icon` | **`#92400E`** / `#FEF3C7` / `#B45309` | `#FCD34D` / `#2A1F05` | Aviso · 6.4 (antes `#A16207`: 4.4, no pasaba); icono 4.5 |
| `diff-add` / `diff-del` | `#DCFCE7` / `#FEE2E2` | `#052E16` / `#2A0E0E` | Resumen de cambios (texto `fg` encima 16 / 14.5) |

Tipografía, espaciado, radios, alturas, sombras y movimiento: sin cambios frente a 5.2 (Inter 400/500/600 + JetBrains Mono; escala 11 · 12 · **13** · 14 · 16 · 20 · 24 · 30–34; espaciado de 4; radios 3/4/6/8/12/16; control 32, fila 40, **44 en táctil o < 768**; campos a 16 px en móvil). Sombra solo en lo que flota (`shadow-pop`, `shadow-drag`). Movimiento 150 ms en color/borde, 200 ms en modal/hoja/drawer (fundido del fondo + subida del panel), nada con `prefers-reduced-motion`. Suelo de 11 px para todo texto funcional (D80, sustituye la excepción de 10,5 de 6.20). Excepciones fuera de la escala: 28 en el título de documento de los canvas del editor; 22 en la etiqueta Caveat de la nota del autor en el editor (ámbito sitio, decorativa).

### 4.2 Componentes

| Componente | Base | Reglas |
| --- | --- | --- |
| Botón | `<button>` | Primario (tinta, uno por vista), fantasma, silencioso, peligro (solo en confirmaciones), peligro suave (abre confirmación), **cambios** (`st-rev`, solo "Publicar cambios"). Dividido para Publicar ▾. Estados: hover, foco, `aria-busy` con spinner y verbo en gerundio, `disabled` .45 |
| Insignia | `span.chip` | Siempre texto + punto/icono. Compuesta "Publicado · N cambios" (`chip-pair`). Ver tabla de estados en el design system |
| Campo | Reka `Label` + input | Etiqueta encima; `*` + "(obligatorio)" en sr-only; ayuda debajo; error con icono + texto, `aria-invalid`, `aria-describedby`; al guardar: banner con enlaces a cada error y foco al primero. Afijos (`€`, `m²`, `/blog/`) |
| URL (slug) | input con prefijo | Sigue al título hasta que se edita (icono candado). Disponible ✓ / ocupada (con sugerencia `-2`) / caracteres corregidos solos. **Publicado: fija**; "Cambiar…" avisa de que la URL antigua deja de funcionar (duda 3) |
| Contador SEO | `.counter` + `.meter` | Título 70 (ideal 50–60), descripción 160 (ideal 120–160). Verde → ámbar al pasar del ideal → rojo y bloqueo por encima del máximo (CHECK de BD). Vacío: placeholder con el valor heredado |
| ES / EN | — | **Documentos** (artículo, página, reseña larga): conmutador ES/EN global en la cabecera; todo el documento sigue al idioma activo; punto ámbar si EN incompleto. **Formularios** (fichas, medios, categorías, ajustes): pares lado a lado ≥ 1024, apilados por debajo, con `lang-tag`. Texto largo dentro de un formulario: pestañas locales |
| Tres estados | `seg.tri`, `role=radiogroup` | Sí / No / No lo sé (null). ← → |
| Escala 1–5 descriptiva | `seg.scale` | Grados y Estilo (y rigidez): número + palabra; neutro, sin verde/rojo; "Sin dato" aparte |
| Nota 1–5 | `seg.score` | 1–5 + "Sin nota" (no cuenta en la media); media en vivo |
| Tabla | TanStack + `<table>` | Cabecera fija; orden con `aria-sort`; búsqueda `/`; filtros en botones con menú de casillas + fichas de filtros activos (en la URL); selección por fila/página + banda "Seleccionar los N"; barra de lote flotante con `aria-live`; columnas fijas (casilla + primera a la izquierda, acciones a la derecha) con sombra de borde al desplazar; paginación 25/50/100; menú de columnas. < 768: tarjetas |
| Selector de medios | Reka `Dialog` | Biblioteca/Subir, buscador, filtros Sin alt/Sin usar, rejilla, panel lateral con color dominante y **alt ES obligatorio para usarla** (en línea). Uno o varios. Hoja en móvil |
| Modal / drawer / hoja | Reka `Dialog` | Modal 480/720/960 para confirmar o elegir; drawer 440 para entidades pequeñas; < 768 todo pasa a hoja inferior con asa y botones al pie a ancho completo. Foco atrapado, Esc, foco de vuelta, scroll bloqueado |
| Toast | Reka `Toast` | Éxito (tinta, 5 s, "Deshacer"), error (persistente, borde rojo, "Reintentar", `role=alert`), info. Máx. 3. Abajo a la derecha; en móvil encima de la barra inferior |
| Confirmar borrado | `role=alertdialog` | Cuatro niveles: simple; **bloqueado "medio en uso"** (lista de usos con enlaces + alternativa "Reemplazar archivo"); con reasignación (categoría); irreversible con email escrito (RGPD). Foco inicial en Cancelar |
| Vacío / carga / error | — | Vacío: primera vez (acción) · sin resultados (salidas concretas) · al día (sin acción). Carga: esqueleto con la forma real > 300 ms, `aria-busy`. Error: bloque con Reintentar y código; banner sin conexión (copia local); banner "otra pestaña está editando" |
| Arrastrar | `vue-draggable-plus` | Asa a la izquierda; línea naranja de destino; elemento levantado con sombra y contorno; teclado Espacio / ↑↓ / Espacio / Esc con anuncios; alternativa en menú (Mover arriba/abajo); se guarda al soltar con toast "Deshacer" |

### 4.3 Cambios sin publicar (D23)

- **Modelo.** Editar algo publicado o programado crea, al primer cambio, un borrador de cambios (revisión). El sitio sigue sirviendo lo publicado. Con esto **el autoguardado vale para todo** (se guarda el borrador); sustituye la regla de 5.1 "guardado explícito en publicado".
- **Editor.** Insignia compuesta "Publicado · N cambios" + "Guardado · hace X" · banda violeta bajo la cabecera ("El sitio sigue mostrando la versión del …", Ver N cambios, Descartar) · botón **Publicar cambios** (violeta) con ▾: Ver cambios, Descartar cambios…, Copiar enlace de vista previa, Despublicar… · **barra violeta de 3 px** a la izquierda de cada campo o bloque cambiado (verde si el bloque es nuevo) y "Cambiado" en la etiqueta · inspector: "Sin publicar: N cambios · ver" e Historial.
- **Ver cambios / Publicar.** Modal con una fila por campo: texto corto con diff de palabras, cuerpo como recuento por bloques + "Ver texto" (párrafos añadidos/cambiados), imagen antes → después, números `69,00 € → 72,00 €`; "Revertir" por campo; checklist; "Descartar todos…", "Seguir editando", "Publicar cambios". Si un error bloquea, el botón está desactivado y el motivo enlaza al campo.
- **Descartar.** `alertdialog`: vuelve a la versión publicada; el sitio no cambia; toast con Deshacer.
- **Listados e Inicio.** Vista "Con cambios" (punto violeta) en Artículos; insignia compuesta en filas y tarjetas; menú de fila con Ver cambios / Publicar cambios / Descartar; Inicio: KPI "N con cambios", tarea en Pendiente y color propio en el calendario.
- **Fichas.** Igual, con el punto violeta en la pestaña que tiene cambios (y contador rojo en la que tiene errores).
- **Actividad.** "Guardaste un borrador de cambios…" y "Publicaste N cambios en…" con los campos.

### 4.4 Responsive

≥ 1280 menú 240 + inspector 340 · 768–1279 raíl 56, inspector en drawer, editores con barra superior · < 768 drawer de menú, barra inferior (Inicio, Opiniones, Medios, Nuevo), tablas → tarjetas, modales y drawers → hojas, editores con barra inferior propia (Ajustes / Publicar cambios). Sin scroll horizontal de página: solo tablas y pestañas se desplazan dentro de su contenedor (la pestaña activa se centra).

---

## 5 · Mockups (5.5)

| Pantalla | Qué enseña |
| --- | --- |
| Login | Email + contraseña (D2), mostrar contraseña, "¿La has olvidado?"; estados cargando, datos incorrectos (mensaje único), cuenta sin acceso (no está en `guide.admins`), demasiados intentos; sesión caducada como modal sin perder el trabajo |
| Inicio | KPIs, calendario editorial, Pendiente (opiniones nuevas, cambios sin publicar, agenda, verificación, alt, hueco sin programar), altas por semana con "Ver como tabla", actividad con exportación |
| Artículos | Vistas con recuento (incluida "Con cambios"), filtros, tabla y tarjetas, menú de fila abierto, lote, selector de estado del mockup (cargando, vacío, error) |
| Editor de artículo | Publicado con 3 cambios: banda, marcas por campo/bloque, modal "Publicar 3 cambios" con diff (`#cambios` lo abre), descartar, eliminar publicado, ES/EN, hoja de ajustes en móvil |
| Categorías | Orden de las 6 categorías y de los artículos de una categoría, arrastrando o con teclado; drawer de edición con pares ES/EN y color; borrar con reasignación |
| Medios | Rejilla con color dominante, filtros Sin alt / Sin usar, zona de soltar (escritorio) y progreso con error por archivo; detalle (`#detalle`): alt/pie ES/EN, crédito, color editable y "Recalcular", **dónde se usa**, Reemplazar (antes → después, aviso de alt), Eliminar bloqueado con motivo |
| Rocódromo | Todas las columnas de `gyms` + `items` en 9 pestañas: General (fuente y verificación), Ubicación y horarios (mapa, metro, horario por tramos con error), Precios (con cambios), Instalaciones (cifras + 11 tres estados), **Grados y estilo**, **Reseña y notas** (visita invitada con nota de transparencia ES/EN y vista de la insignia, veredicto, cuerpo, 7 criterios con media e índices), Galería ordenable, Relacionados, SEO. Lateral: estado, checklist que bloquea, ocultar ficha, eliminar desactivado si hay opiniones |
| Pie de gato (ligera) | Ficha técnica completa, precio y afiliado (vista de la marca), "Lo que aprendí" con **tallas EU** (paso 0,5, vista "42,5 · calzo 43,5 de calle"), nota de ajuste ES/EN 140 |
| Resolador (ligera) | **Servicios** del CHECK como casillas con explicación, precios, plazo min–máx con error, marcas de goma, envíos (tres estados) |
| Criterios de nota (F6.10) | Ver §7: lista ordenable por categoría, inactivos aparte, drawer con ayuda al puntuar, desactivar con impacto, bloqueo por fórmula, borrar solo sin notas |
| Agenda (F6.12) | Ver §9: bandeja «Por aprobar» con origen agente/manual, duplicados y caducados; Próximos en tabla o mes; drawer de evento; descartar con motivo |
| Opiniones | Recientes por defecto, nuevas marcadas, lista + detalle en dos columnas, teclado J/K/V/H, impacto en la media, hoja en móvil con botones de 44, borrar solo RGPD |
| Suscriptores (F6.14) | Ver §11: vistas Activos / Sin confirmar / Bajas / Todos, prueba de consentimiento en la ficha, baja irreversible con motivo, supresión RGPD (anonimizar) con email escrito, estado «Antes de F4.6»; Exportar enlaza a §6.15 |
| Exportar (F6.15) | Ver §12 (D37): modal (hoja en móvil) desde «Exportar» en cada listado; filtros heredados, columnas, CSV `;` o JSON, resumen en vivo en el pie; suscriptores con columnas mínimas, finalidad y casilla; «Última exportación» del módulo; sin entrada en el menú |
| Actividad | Agrupado por día, filtros (incluida **Exportaciones**), detalle de una exportación, recuperar borrados |
| Ajustes | Secciones General, SEO por defecto, Redes, Newsletter (versión del texto de consentimiento y aviso de nueva versión), Opiniones (premoderación apagada), Tu cuenta (sin fecha de cambio de contraseña, D60); Autor del sitio en §17; barra flotante de cambios sin guardar (los ajustes no usan borrador de cambios) |

Cómo verlos: `python3 -m http.server 8080` desde la raíz del repo → `http://localhost:8080/docs/design/admin/index.html`. Revisados en Chrome a 1440 y en marcos reales de 390 y 768.

Notas para implementar: el shell de los mockups se pinta con `assets/admin.js` (en Nuxt será el layout `admin`); las animaciones de los mockups son solo de desplazamiento; en producción, fundido de 150 ms con `Presence` de Reka.

---

## 6 · Dudas para Xavi

1. **Opiniones "nuevas"**: con post-moderación no hay estado pendiente; marco como nuevas las llegadas desde tu última visita. ¿Vale guardar esa fecha por cuenta (una columna en `admins`, jabali-javi) para que coincida en móvil y escritorio?
2. **Programar cambios**: ahora "Publicar cambios" es inmediato. ¿Quieres también "Programar cambios" (p. ej. subir precios el día 1)? Requiere que la tarea programada aplique revisiones.
3. **URL de algo publicado**: la dejo fija y cambiarla avisa de que se rompe la antigua. ¿Añadimos redirecciones automáticas (tabla pequeña + middleware) o basta el aviso?
4. **Ajustes sin borrador**: los ajustes globales se guardan al momento (con barra de "cambios sin guardar"). ¿De acuerdo, o los quieres también con borrador de cambios?
5. **Borrar fichas con opiniones**: propongo no permitirlo (solo ocultar). ¿OK?

---

## 7 · Criterios de nota (F6.10) · propuesta

Mockup: `criterios.html` (`#editar`, `#desactivar`, `#nuevo-criterio`, `#eliminar`, `#cargando`, `#vacio`, `#error`).
Ruta `/administrador/criterios?categoria=gym|resoler|shoe` (la categoría va en la URL; por defecto `gym`).
Sin dirección alternativa: reutiliza tal cual el patrón aprobado de Categorías (lista ordenable + drawer).

### 7.1 Qué ve Xavi

- **Cabecera**: "Criterios de nota" + botón primario **Nuevo criterio** (en móvil "Nuevo").
- **Selector de categoría**: `AdminSegmented` con el recuento de activos (Rocódromos 7 · Resoladores 4 · Pies de gato 5). En < 640 ocupa el ancho en 3 columnas iguales (40 px de alto).
- **Lista de activos** (`AdminSortableList`, igual que Categorías): asa · posición · nombre ES + clave en mono · insignia de uso en fórmula · "5 fichas · 24 lectores" · `EN` (`lang-ok` / `lang-miss`) · lápiz. Toda la fila (nombre) abre el drawer. Ordenar con ratón, teclado (Espacio, ↑↓, Espacio/Esc) o menú «Mover»; guarda al soltar con `guide.reorder_criteria(p_category, p_ids)` (solo ids activos, en orden) y toast "Orden guardado" + Deshacer. Error al guardar: toast persistente y la fila vuelve a su sitio.
- **Inactivos** (bloque aparte debajo, sin asa): nombre en `meta`, insignia `Inactivo` (`st-hidden`), "3 fichas · 11 lectores · conservadas", botón **Reactivar** (inmediato, vuelve al final de los activos, toast + Deshacer) y lápiz.
- **Lateral "Dónde cuentan"** (≥ 1280 a la derecha, 400 px; debajo en el resto): nota del autor, notas de lectores (≥ 3 opiniones; la nota general de lectores va aparte) y, en Rocódromos, índice principiantes (Para principiantes 50 %), índice familiar (Para familias 20 %), tabla de la home (Variedad) y la regla de bloqueo.
- **"Así se ve en una ficha"**: el bloque de notas de una ficha real de la categoría con la nota del autor, en el orden actual y solo con activos; se actualiza al reordenar o desactivar.

### 7.2 Drawer (editar / nuevo)

| Campo | Regla |
| --- | --- |
| Nombre ES * / EN | `AdminLangPair`, 80 car. con contador. EN vacío: en /en sale el ES (ayuda bajo el campo) |
| Clave interna | **Nuevo**: sigue al nombre (sin tildes, `a-z _`, máx. 40), editable, error en línea si ya existe en la categoría ("Prueba `value_2`"). **Editar**: solo lectura con candado; no se puede cambiar (la usan fórmulas, medias por criterio y exportaciones) |
| Ayuda al puntuar ES / EN | Textarea 300 car. (`description_es/en`), opcional. "Sale debajo del nombre al puntuar. No se publica en la ficha." |
| Así sale al puntuar | Vista previa en vivo: nombre + ayuda + `seg.score` 1–5 / Sin nota (decorativa, `aria-hidden`) |
| Estado (solo editar) | Insignia Activo/Inactivo + frase de efecto; dos cifras "Tus notas: N fichas" y "Notas de lectores: N"; botón **Desactivar…** o **Reactivar** |
| Pie | **Eliminar…** (peligro suave), Cancelar, Guardar. Eliminar está `disabled` con motivo (`aria-describedby`) si tiene notas |

Nuevo: banner info "Se añade al final de Rocódromos. Las fichas ya puntuadas no tienen nota en este criterio: su media no cambia hasta que lo puntúes." Guardar → toast "Criterio creado al final de la lista".

### 7.3 Desactivar, bloquear, eliminar

- **Desactivar** (con notas): `alertdialog` 520 (hoja en móvil), foco en Cancelar. Título "¿Desactivar «Afluencia»?"; entradilla "Deja de contar en el sitio en cuanto confirmes. **Las notas no se borran**: si lo reactivas, vuelven a contar igual." Después, solo los bloques que apliquen:
  1. *Cambia tu nota en N fichas*: tabla antes → después de hasta 3 fichas publicadas + "y N más" (se calcula en cliente con las notas del autor).
  2. *Sale de las notas de lectores*: deja de salir en la media por criterio (N notas); la nota general de lectores no cambia.
  3. Si alimenta una tabla del sitio (Variedad): banner aviso "La columna «Variedad» de la tabla de rocódromos de la home se queda vacía".
  4. *Deja de pedirse al puntuar*: en tus fichas y en el formulario de opiniones.
  
  Botón **Desactivar** (peligro). Toast "«Afluencia» desactivado · deja de contar en 5 fichas" + Deshacer. Sin notas: se desactiva sin diálogo (toast + Deshacer).
- **Bloqueado por fórmula** (`beginner_friendly`, `family_friendly`): insignia `Σ Índice …` en la fila (`st-neutral`; en < 640 solo icono con texto sr-only); en el drawer, banner info "Entra en el índice familiar (20 % de la fórmula). No se puede desactivar mientras la fórmula lo use" y **Desactivar…** y **Eliminar…** desactivados. Se puede editar nombre y ayuda.
- **Eliminar**: solo si no tiene ninguna nota (ni tuya ni de lectores; la BD ya lo impide con `on delete restrict`). `alertdialog` simple: "No tiene notas guardadas, así que no cambia ninguna media. Se quita de Pies de gato y la clave `sensitivity` queda libre." Con notas: botón desactivado + "No se puede eliminar: tiene 13 notas guardadas. Desactivar lo saca de medias e índices y conserva las notas."

### 7.4 Estados

Carga: esqueleto de 7 filas + lateral (> 300 ms, `aria-busy`). Vacío por categoría: "Pies de gato no tiene criterios todavía" + "Sin criterios, las fichas de esta categoría no muestran nota del autor ni medias de lectores por criterio" + Nuevo criterio. Error: `AdminStateBlock` con Reintentar. Guardar con error: banner `banner-err` arriba del drawer con enlace al campo. Responsive: < 768 la fila muestra "5 fichas · 24 lectores" en la segunda línea en lugar de la clave; asa y lápiz de 44 px; drawer y diálogos → hoja inferior. **Rejilla con `grid-cols-[minmax(0,1fr)]`** en < 1280 (si no, los textos `truncate` ensanchan la columna y hay scroll horizontal en 390).

### 7.5 Lo que necesita backend (jabali-javi → leona-lia)

1. **Recuento de uso por criterio** (fichas con nota del autor y notas de lectores), p. ej. vista o RPC admin `guide.criteria_usage`. Hoy no existe y la pantalla lo necesita para el diálogo y para Eliminar.
2. **Medias e índices filtran por `is_active` solo vía RLS**: `item_author_scores`, `item_user_ratings` y `gym_indices` hacen `join guide.criteria` sin `c.is_active`; para `anon` sale bien por la policy, pero para una sesión admin (o cualquier rol con lectura total) los inactivos siguen contando. Propuesta: filtrar `c.is_active` explícitamente en las vistas.
3. **Bloqueo por fórmula en BD**: impedir `is_active = false` y `delete` de `beginner_friendly` / `family_friendly` (trigger o check en RPC), no solo en la UI.
4. **Clave inmutable**: impedir `update` de `key` (trigger), coherente con la UI.
5. A verificar por coneja-lucky/zorro-foxter: el editor de fichas carga solo criterios activos pero guarda `scores` completos; al publicar se reescriben todas las notas de la reseña (`delete` + `insert`). Confirmar que las notas de criterios inactivos viajan en el payload y no se pierden (si no, "reactivar recupera las notas" sería falso).

### 7.6 Dudas para Xavi

1. **Bloqueo por fórmula**: ¿de acuerdo con que Para principiantes y Para familias no se puedan desactivar ni borrar mientras entren en los índices? (Alternativa: permitirlo y que el índice se calcule sin esa parte, con un aviso fuerte.)
2. **Ayuda al puntuar para lectores**: hoy el formulario de opiniones no muestra la descripción. ¿La mostramos también allí (texto en ES/EN → loro-lola)?
3. **Variedad en la home**: al desactivarla, ¿la columna se oculta o se queda vacía? Propongo ocultarla (coneja-lucky).

## 8 · Fotos de lectores en la bandeja de Opiniones (F6.11b) · propuesta

Mockup: `opiniones-fotos.html` (amplía `opiniones.html`, que no se toca; `?vacio` para el estado vacío). A 390: `anchos.html?solo=opiniones-fotos.html&w=390`. Usa los tokens y chips de siempre (`st-warn`, `st-pub`, `st-hidden`, `count`, `menu`, `dialog`) y el patrón de miniaturas de Medios.

### 8.1 · Lista
- Nueva vista **Fotos por revisar** (segunda pestaña, icono `image`, `count` naranja con el **número de fotos** pendientes). Muestra solo las opiniones con al menos una foto pendiente, **las más antiguas primero** (es una cola), con un banner fino `side`: "El texto ya está publicado. Las fotos salen en la ficha solo cuando las apruebas."
- Fila (en todas las vistas): chip `st-warn` "2 fotos por revisar" junto al idioma. Si no queda ninguna pendiente, un icono `image` `muted` con el número de publicadas. Debajo del texto, miniaturas de 32 px (`rounded`, `aria-hidden`): las pendientes con contorno discontinuo `warn-icon` y las rechazadas al 35 %.
- Menos de 1024: botón de fila "Revisar N fotos" (alto 44) que abre la hoja.
- Vacío: icono, "No hay fotos por revisar" y una línea de explicación.

### 8.2 · Detalle
- Sección **Fotos · 3 · 2 por revisar** entre el texto y las notas por criterio. Rejilla `grid-cols-3 gap-3` (`gap-2` en la hoja) de miniaturas 4:3 `rounded-lg` con borde interior de 1 px. Chip arriba a la izquierda: **Por revisar** (`st-warn`, reloj), **Publicada** (`st-pub`) o **Rechazada** (`st-hidden`, imagen al 40 % y en escala de grises). Al pasar por encima aparece un icono de ampliar, y el clic abre el visor.
- Debajo de cada foto, el peso y las medidas (`11px muted num`) y las acciones `btn-sm`: pendiente → **Aprobar** y **Rechazar ▾**. Publicada → **Retirar** (quiet). Rechazada → el motivo en `meta` y **Aprobar** (quiet, deshace el rechazo).
- **Rechazar** abre un `menu` (`role=menu`, foco en el primer elemento, Esc cierra) con estos motivos: Sin relación con la ficha · Se ve gente reconocible · Borrosa o de mala calidad · Publicidad o datos de contacto · Contenido inapropiado · Rechazar sin motivo. Al elegir uno, se rechaza en el acto y sale el toast "Foto rechazada · no sale en la ficha" con **Deshacer**. Sin diálogo de confirmación, porque se puede deshacer.
- Con 2 o más pendientes, **Aprobar las N** (ghost, en la cabecera de la sección). En el pie, la primaria pasa a ser **Aprobar fotos y siguiente (A)**, y "Ocultar opinión (H)" se queda como ghost.
- Caja de impacto: "Las fotos no cambian la media. Si ocultas la opinión, sus fotos tampoco salen. Las fotos de lectores no entran en Medios." El diálogo RGPD de borrado menciona "y sus N fotos".
- **Visor:** `dialog.xl` con cabecera "Foto 1 de 3 · Marta G." más chip, anterior y siguiente (← →) y cerrar. Debajo, la imagen `object-contain` sobre `#0E0E10`, una línea de metadatos con `shield-check` ("Sin ubicación ni datos de cámara (comprobado al subir)", **solo si el servidor lo verifica**) y las mismas acciones en el pie.
- Teclado: J/K moverse, **A** aprobar las pendientes y pasar a la siguiente, H ocultar la opinión. V sigue significando "está bien" (solo el texto).
- Menos de 1024 (hoja): la sección es igual, pero las acciones son botones de icono de 44 px (✓ / ✕ con `sr-only` "Aprobar la foto 1") y **Aprobar las N** ocupa todo el ancho y mide 44 px. Pie con "Aprobar fotos y siguiente" y "Ocultar opinión".

### 8.3 · Para backend (jabali-javi → leona-lia)
1. Estado por foto: `pending | approved | rejected`, motivo opcional, `reviewed_at`/`reviewed_by` y registro en Actividad. La foto rechazada deja de contar para el límite de 3.
2. Verificar en el servidor que no queda EXIF/GPS (o volver a quitarlo) antes de marcar "comprobado"; no fiarse solo del navegador.
3. URL públicas solo para `approved` y con la opinión visible. Las pendientes, legibles solo por su autor y por el admin (URL firmadas).
4. Limpieza de subidas huérfanas (alguien cancela el formulario) y de las rechazadas pasados N días.
5. Contadores: fotos pendientes en total (pestaña y lateral) y medidas y peso por foto.

## 9 · Agenda (F6.12) · propuesta

Mockup: `agenda.html` (`#revisar`, `#duplicado`, `#caducado`, `#proximos`, `#mes`, `#pasados`, `#descartados`, `#editar-aprobar`, `#editar`, `#nuevo`, `#errores`, `#eliminar`, `#cargando`, `#vacio`, `#error`). A 390: `anchos.html?solo=agenda.html%23revisar&w=390`.
Ruta `/administrador/agenda?vista=revisar|proximos|pasados|descartados|todos&tipo=…&q=…&vista-cal=mes`. No hay dirección alternativa: junta tres patrones que ya están aprobados. La bandeja es la de **Opiniones**, la tabla es `AdminDataTable` (Artículos), el mes es el calendario del **Inicio** y el editor es un drawer, como en Criterios y Categorías. En el shell, el menú y «Nuevo → Evento» ya enlazan aquí (`assets/admin.js`).

### 9.1 · Modelo que se respeta (`guide.events`)
- Estados: `draft` → **Por aprobar** (`st-warn`, icono `circle-dashed`), `approved` → **En la agenda** (`st-pub`; si la fecha ya ha pasado, **Pasado**, `st-neutral`) y `rejected` → **Descartado** (`st-hidden`).
- Origen (`source`): chip `st-neutral` con `sparkles` y el texto «Propuesto por el agente» (en filas, «Agente»), o con `user-pen` y el texto «Manual». **Origen y estado son dos chips distintos**: puede haber un borrador manual y un aprobado que vino del agente. `sparkles` se reserva en todo el panel para «viene del agente».
- **Regla 6:** nada del agente sale sin `approve_event`. Un evento manual nuevo se puede **Publicar** directamente (Xavi es el autor) o guardarse como borrador.
- No hay imagen: ni el esquema ni el sitio la tienen, así que D27 no aplica (ver duda 1). La descripción ES/EN existe en el esquema pero `EventDetails.vue` no la pinta: va plegada con el aviso «hoy no se muestra en el sitio» (duda 2).

### 9.2 · Vistas y barra
- Pestañas: **Por aprobar** (`count` naranja, igual que el menú), Próximos, Pasados, Descartados y Todos. Si hay borradores, la vista por defecto es Por aprobar; si no, Próximos.
- Barra: búsqueda (`/`, en título y lugar) · **Tipo** (menú de casillas con recuento; misma lógica que `useEventTypeFilter`: sin selección, todos) · Lugar · Fechas (por defecto: Próximos 60 días, que es lo que muestra el sitio; en Pasados, últimos 90; también rango libre) · Origen. Los filtros activos salen como fichas con ×, y todo va en la URL.
- Chip de cabecera «El sitio muestra los próximos 60 días». En Próximos, una franja `side` explica dónde sale cada evento. En Descartados, explica por qué se guardan.

### 9.3 · Por aprobar (bandeja)
- Lista de 420 px y detalle (≥ 1024); por debajo, la lista sola y el detalle en hoja. Va **ordenada por fecha del evento** (lo más urgente arriba), con los que ya han pasado al final.
- Fila: casilla · bloque de fecha (`dblock`: día de la semana en mono, número a 20 px y mes; «hoy» en `acc`) · título (2 líneas) · lugar y hora · chips: origen, **confianza** (5 segmentos con texto sr-only alta/media/baja), avisos (`Ya ha pasado` en `st-danger`, `Posible duplicado` y `Confianza baja` (< 0,65) en `st-warn`) y `EN`.
- Detalle:
  - Chips de estado y origen.
  - Banner de caducado o de duplicado. El de duplicado lleva «Abrir el existente» y «Descartar como duplicado».
  - **Así sale en la agenda**: la misma estructura que `EventDetails.vue`, con un selector ES/EN. Sin `title_en`, la vista EN muestra «No sale en /en/agenda».
  - Lista de datos (Tipo, Cuándo, Dónde, Precio, Organizador, Título EN). Lo que el agente dedujo lleva la marca `sparkles deducido`.
  - Caja **Qué encontró el agente**: fuente (`source_url`), cuándo se revisó, confianza, nota y la cita literal de la web (`lang="ca"` si está en catalán).
  - Nota de impacto: «sale en menos de 10 minutos» (ISR de 10 min).
- Acciones:
  - Normal: **Aprobar** (primaria, `A`) · **Editar y aprobar** (`E`, abre el drawer) · **Descartar ▾** (`D`).
  - Caducado: la primaria pasa a **Descartar**, y la otra opción es «Cambiar la fecha».
  - En la lista (< 1024): Aprobar, Editar y × de 44 px.
- **Descartar** abre un `menu` con motivos: Duplicado · No es de escalada · Solo para socios o privado · Fuera del área de Barcelona · Fecha o datos incorrectos · Sin motivo. Al elegir se descarta en el acto, sin diálogo, con el toast «Descartado · el agente no lo volverá a proponer» y Deshacer.
- Lote: casillas y barra flotante «N seleccionados · Aprobar · Descartar».
- Teclado: J/K para moverse, A, E, D y `/`. Después de aprobar o descartar, el foco pasa al siguiente.
- Vacío (al día): «Nada por aprobar» y una explicación de lo que llegará cuando esté el agente (F8), sin acción principal.

### 9.4 · Próximos, Pasados, Descartados y Todos
- `AdminDataTable` con **filas de grupo por mes** («Noviembre 2026 · 4», `side`).
- Columnas: casilla · Fecha (`23 oct vie` y la hora debajo; ascendente en Próximos, descendente en Pasados y Descartados) · Evento (título, con el lugar debajo e icono `mountain` si es ficha) · [Estado, solo en Todos] · Tipo (≥ 1024) · Precio (≥ 1280) o **Motivo** (en Descartados) · Origen (≥ 1280) · EN · ⋯.
- `colspan` de la fila de grupo = número real de columnas. Si sobra una, `table-fixed` se queda corta.
- Menú de fila: Editar · **Duplicar (otra fecha)** (para ligas y cursos con varias jornadas: abre el drawer con los datos copiados y la fecha vacía y enfocada) · Ver en el sitio (`/agenda/aaaa-mm`) · Abrir web del organizador · **Retirar de la agenda** (solo aprobados futuros; `alertdialog` sin peligro: vuelve a Por aprobar) · Eliminar….
- En Descartados no hay menú: solo **Recuperar** (vuelve a borrador).
- < 768: tarjetas con `dblock`, chips y ⋯ de 44 px.
- **Mes** (solo en Próximos y solo ≥ 768): es el calendario del Inicio. Los aprobados van con contorno; los borradores, en `warn-soft` con borde `warn-icon` y «· por aprobar». Al hacer clic en un aprobado se abre el editor; en un borrador, la bandeja con ese evento. El `+` de un día crea un evento con esa fecha. Hay casilla «Mostrar por aprobar» y botón Hoy.

### 9.5 · Drawer de evento (520 px; hoja en < 768)
| Campo | Regla |
| --- | --- |
| Banner del agente | Solo en borradores del agente: fecha, fuente y qué significa «deducido» |
| Título ES * / EN | 200 car. con contador. Ayuda en EN: «Sin título en inglés, el evento no sale en /en/agenda» (`has_en`) |
| Tipo * | `seg` de 3×2 con los 6 tipos (D15: Quedada = `outing`). Marca «deducido» si la puso el agente; se quita al tocarlo |
| Cuándo | «Hora de Barcelona». Switch **Todo el día** (oculta las horas sin mover la rejilla). Empieza * fecha + hora; Termina (opcional) fecha + hora. Error si termina antes (CHECK `events_dates`). Aviso ámbar si la fecha ya ha pasado |
| Dónde | `seg` **Rocódromo de la guía** (selector de fichas de rocódromo → `item_id`, el nombre enlaza a la ficha) / **Otro lugar** (`location_text`, 200). Son excluyentes, porque el sitio da prioridad al nombre de la ficha |
| Precio | Texto libre de 120 («15 € · gratis para socios»). Vacío: no se muestra |
| Enlace del organizador | Afijo `https://`. Error en línea si no es una URL. Es el «Más información» |
| Descripción ES/EN | Pestañas locales, 2000. Plegada |
| Vista previa | ES y EN en vivo, con la misma estructura que el sitio |
| Lo que leyó el agente | Cita y nota sobre `source_url`, que no se edita |

Pie según el estado:
- **Nuevo**: Cancelar · Guardar borrador · **Publicar**.
- **Borrador**: Descartar ▾ · Guardar (sigue por aprobar) · **Guardar y aprobar**.
- **Aprobado**: Eliminar… · Cancelar · **Guardar** (toast «se actualiza en la agenda en unos minutos»).
- **Descartado**: Cerrar · **Recuperar**.

Al publicar con errores sale un `banner-err` con enlaces a cada campo y el foco va al banner (`#errores`). Al cerrar con cambios, aviso de cambios sin guardar (como en el resto de drawers). Los eventos no usan borrador de cambios (D23): son entidades pequeñas y se guardan al momento.

### 9.6 · Eliminar
`alertdialog` con el foco en Cancelar. Si el evento vino del agente, añade un banner ámbar: «Si lo eliminas, puede volver a proponerlo la próxima semana. Para que no vuelva, descártalo». También añade el botón **Descartar en su lugar**. Eliminar solo tiene sentido para lo manual o lo creado por error.

### 9.7 · Estados y responsive
- **Carga:** un esqueleto con la forma de la bandeja (5 filas + detalle) o de la tabla, `aria-busy`.
- **Vacío:**
  - Por aprobar: al día, sin acción.
  - Próximos: primera vez, con Nuevo evento.
  - Descartados: vacío con explicación.
  - Filtros: sin resultados, con «Buscar en todos» y «Quitar filtros».
- **Error:** `AdminStateBlock` con Reintentar y código.
- **Toasts:** aprobar, descartar, retirar y recuperar llevan **Deshacer**.
- **Responsive:** rejillas con `minmax(0,1fr)` y `min-w-0` en lista y detalle. Las pestañas se desplazan dentro de su barra. En 390 no hay scroll horizontal; los táctiles miden 44.

### 9.8 · Para backend (jabali-javi → leona-lia)
1. **Deshacer y recuperar** necesitan volver a `draft`. Hoy solo existen `approve_event` y `reject_event`. Propuesta: `guide.reopen_event(p_id)`, que deja `status = 'draft'` y `approved_at = null`, y sirve para Retirar, Recuperar y Deshacer.
2. **Motivo del descarte**: columna `reject_reason text` (enum o CHECK con los 5 motivos), o `reject_event(p_id, p_reason)`. Ayuda a que el agente de F8 aprenda.
3. **No volver a proponer**: el agente debe saltarse un `dedupe_key` que ya exista en cualquier estado (también `rejected`). Por eso se descarta en vez de borrar.
4. **`agent_meta`**: fijar su forma para F8: `{confidence: 0–1, note, excerpt, found_at, inferred: ['type'|'end'|'price'|…], duplicate_of: uuid|null}`. La UI depende de `confidence`, `inferred`, `excerpt` y `duplicate_of`.
5. **`item_id` solo de rocódromos**: el sitio enlaza a `climbing-gyms-slug`, así que una ficha de resolador o de pie de gato rompería el enlace. Hace falta un CHECK o un trigger.
6. **Contador del menú** = `events_drafts` de `admin_dashboard`. ¿Incluye los borradores caducados? Propongo contar solo los futuros y mostrar los caducados en la bandeja, sin sumarlos al contador.
7. Lote: aprobar o descartar varios a la vez con una sola RPC (`approve_events(uuid[])`) o con un bucle en el cliente.

### 9.9 · Dudas para Xavi
1. **Imagen del evento**: hoy no hay ni columna ni hueco en el sitio. ¿La quieres (cartel del evento, de Medios, con alt obligatorio por D27)? Propongo que no en v1.
2. **Descripción**: está en el esquema pero no sale en el sitio. ¿La mostramos (desplegable en la fila de la agenda) o la quitamos del editor?
3. **Borradores caducados**: ¿se descartan solos al pasar la fecha (tarea programada) o los descartas tú? Propongo descartarlos solos con el motivo «Caducado» y que no cuenten en el contador.
4. **Vista por defecto**: ¿Por aprobar cuando hay algo y Próximos cuando no (propuesta), o siempre Próximos?
5. **Lugar**: ¿bastan los rocódromos de la guía + texto libre? (Una quedada en Montserrat organizada por un rocódromo queda como «Otro lugar».)
6. **Motivos del descarte**: ¿te sirven los cinco o añadirías alguno?


## 10 · Páginas (F6.13) · propuesta

Mockup: `paginas.html`. Los estados se eligen en el selector «Mockup» o con el hash: `#listado`, `#cargando`, `#error`, `#editor-es`, `#editor-en`, `#cambios`, `#publicar`, `#errores`, `#vacio`, `#editor-cargando` y `#editor-error`. A 390: `anchos.html?solo=paginas.html%23cambios&w=390` (sirve con cualquier estado).
Rutas: `/administrador/paginas` y `/administrador/paginas/:key` (`about`, `transparency`, `legal_notice`, `privacy`, `cookies`). No hay dirección alternativa: es **el editor de artículos (§4.3, D23) con menos piezas**, como pide §1 («página completa para lo que se escribe»). En el shell, el menú (Editorial › Páginas) ya enlaza aquí.

### 10.1 · Modelo que se respeta (`guide.pages` + auditoría de jabali-javi)
- **Cinco páginas fijas.** La clave es cerrada: no hay «Nueva página», ni Duplicar, ni Eliminar. Hoy hay 4 filas (`about` publicada con EN; `legal_notice`, `privacy` y `cookies` sin publicar, sin EN y con marcadores). Falta `transparency`, que el sitio ya lee y enlaza desde fichas, reseñas, afiliados y artículos (duda 4).
- **Estado = `published` (booleano).** No se programa. Chips: `Borrador` (o `Sin contenido` si el cuerpo está vacío) y debajo «El sitio dice "en preparación"» · `Publicada` · `Publicada · N cambios` (`chip-pair`, D23).
- **D23 tal cual:** al editar algo publicado se crea un borrador de cambios con autoguardado (`content_drafts`, PT409), con banda violeta, barras por bloque, «Publicar cambios ▾» (Ver cambios, Descartar, Copiar enlace de vista previa, Despublicar) y un modal con diff. Backend añadirá PT423 (no editar lo publicado en directo) y `unpublish_page`.
- **D27:** no se publica con imágenes del cuerpo sin `alt_es`, ni del cuerpo EN sin `alt_en` (ese caso es el estado `#editor-en`).
- **D3:** el inglés va completo o vacío. Sin EN, `/en/...` da 404 y el pie EN enlaza a la versión ES (ya implementado).

### 10.2 · Listado
- Cabecera «Páginas» + chip `st-neutral` «5 páginas fijas del sitio». No hay acción primaria.
- Banner `warn` mientras quede alguna legal sin publicar: «3 páginas legales sin publicar… antes del lanzamiento (F7.4)». Cuando estén todas publicadas, desaparece.
- No es `AdminDataTable`: con 5 filas sobran búsqueda, filtros, paginación y lote. Es una lista con dos grupos (**Sobre ChalkGuide**: Sobre mí y Transparencia; **Legales**: Aviso legal, Privacidad y Cookies). Columnas: Página (título, con la ruta ES · EN en mono debajo y la nota `warn` «Texto provisional» / «Texto en F7.4b») · Estado · Idiomas (`lang-ok` / `lang-miss`) · Buscadores (≥ 1280: «Indexable», «No, sin publicar» o «Nunca (legal)» con `eye-off`) · Actualizada (≥ 1024) · ⋯.
- Menú de fila: Editar · Vista previa · Ver en el sitio · (con cambios) Ver cambios / Descartar… · Despublicar… (en las legales sale desactivado, con el motivo en una segunda línea).
- < 768: tarjetas de 64 px como mínimo (título, ruta, chips y chevron) agrupadas igual. Carga: esqueleto de 5 filas. Error: `AdminStateBlock` con Reintentar. No hay estado «vacío» de listado porque las filas son fijas: el vacío está en el editor (`#vacio`).

### 10.3 · Editor: qué se reutiliza y qué cambia respecto al de artículos
Se reutilizan: `Header` (migas Páginas / título, chip, guardado, ES/EN global con punto ámbar, Vista previa, botón de publicar), `ChangesBand`, `Toolbar`, `Body` (Tiptap, menú `/`, D26 y D27), `ChangesDialog`/`ChangeRow`, `SaveStatus`, `BottomBar` (Ajustes / Publicar), autoguardado, copia local, inspector 340 / drawer / hoja, `AdminTextField` con contador SEO, `AdminSwitch` y el checklist.

| Artículo | Página | Por qué |
| --- | --- | --- |
| Portada en el lienzo, entradilla | **No hay** | No hay columnas. El lienzo empieza con un kicker («Página · Sobre ChalkGuide» o «Página legal» con `scale`) y el título |
| Categoría, Destacado, Fichas relacionadas | **No hay** | — |
| Programar, fecha de publicación | **No hay**: Publicar es inmediato | Rutas fijas y textos que cambian poco (duda 9) |
| URL editable (slug con candado y «Cambiar…») | **Solo lectura**: `chalkguide.com/sobre-mi` + «ruta fija del sitio», sin acción | Las rutas viven en `i18n/localized-routes.ts`; los slugs de la BD no se usan (duda 1) |
| SEO: título, descripción, OG, canónica, No indexar | Título y descripción **por idioma** (≤ 70 / ≤ 160, contador, bloqueo al pasar). Si la descripción está vacía, el placeholder enseña la descripción por defecto **de esa página** (`seo.*Description`), no la entradilla. Sin canónica. No indexar: interruptor en Sobre mí y Transparencia; en las legales, fila fija «Nunca (legal)». OG: solo en Sobre mí y Transparencia (duda 6) | `usePageSeo` ya aplica estas reglas |
| — | **Última actualización** (solo las legales): sección en el inspector con la fecha que ve el lector y su vista en el lienzo («Así sale en la página: Última actualización: 24 de octubre de 2026») | Duda 3 |
| Historial | En las legales, **Versiones publicadas** (copia fechada de cada publicación) | Duda 7 |
| — | **Dónde se enlaza** (plegado): pie, firma de artículos, casilla de la newsletter, fichas… | Explica por qué no conviene despublicar |
| Duplicar / Eliminar | Texto fijo «Las páginas fijas no se duplican ni se eliminan» | Claves cerradas |
| Barra de formato completa | **Sobre mí y Transparencia: completa** (imagen, vídeo D26, tarjeta de ficha). **Legales: sin imagen, vídeo ni ficha**; añade lista numerada | Duda 8 |

**Banda de estado bajo la cabecera** (además de la violeta de D23):
- Sin publicar: franja `side` con `eye-off` que dice «/privacidad muestra "Esta página aún no está publicada" y no se indexa». En Transparencia añade «Ya la enlazan las fichas, las reseñas y los artículos».
- EN incompleto: franja `warn-soft` que dice «la foto nueva no tiene texto alternativo en inglés. No se pueden publicar los cambios (ni los del español) hasta añadirlo o quitar la foto. /en/about sigue con la versión publicada» + «Ir a la imagen». La imagen va con contorno `danger`, error en línea y el botón «Añadir alt EN». «Publicar cambios» queda desactivado (`aria-describedby` al checklist).

**Inspector**, en este orden:
1. **Publicación:** estado, «Sin publicar: N cambios · ver», «En inglés» y el **plazo real** con icono de reloj. En Sobre mí: «se genera al desplegar: el cambio se ve tras el siguiente despliegue» (es prerender). En las demás: «puede tardar hasta 24 h» (ISR de 1 día). Cuando osset-op regenere al publicar, el texto pasa a «en unos minutos» (§10.5).
2. **Última actualización** (legales).
3. **SEO** con `lang-tag`.
4. **Listo para publicar.** Bloquean: Título · Cuerpo (ES) · Imágenes con alt (ES; EN si hay inglés) · Inglés completo o vacío · Campos sin errores. Avisan: **marcas provisionales** (`[XAVI: …]` y «Texto provisional», resaltadas en `warn-soft` dentro del lienzo, porque el seed las trae y saldrían publicadas) · Descripción SEO propia.
5. **Dónde se enlaza.**
6. **Historial / Versiones publicadas.**

**Publicar (primera vez):** modal 720 con lo que pasa en el sitio (la ruta deja de decir «en preparación»; en las legales sigue noindex, follow; solo ES y en /en el pie enlaza aquí; una legal publicada no se despublica). Lleva el fieldset **Última actualización** («Hoy, 24 de octubre de 2026» o «Mantener la fecha anterior», que solo se activa si ya hay una fecha y está pensada para erratas), el banner `warn` si quedan marcas provisionales con «Revisarlas», y en Privacidad la nota «Si cambias cómo tratas los datos de los suscriptores, sube también la versión del texto de consentimiento en Ajustes › Newsletter». Toast: «"Política de privacidad" publicada · se guarda la versión del 24 oct» + «Ver en el sitio».
**Publicar cambios:** es el modal de D23 (diff por campo, Revertir, Descartar todos) más el aviso de plazo. En las legales, el mismo fieldset de fecha, marcado por defecto en «Hoy» si cambian el título o el cuerpo.
**Despublicar:** solo Sobre mí y Transparencia, con `alertdialog`: «/sobre-mi mostrará "Esta página aún no está publicada" y dejará de indexarse; /en/about dará 404», qué enlaces quedan apuntando y «el texto no se borra». En las legales la opción sale desactivada con el motivo.

**Errores (`#errores`):** al publicar, `banner-err` con `role=alert` y foco, con un enlace a cada campo: título SEO 78/70 (CHECK de BD), inglés a medias (título EN sin cuerpo) y fecha futura. Cada campo lleva su error en línea (`aria-invalid` + `aria-describedby`), y sale un toast de error persistente. Los errores de guardado y la copia local son los del editor de artículos.
**Vacío (`#vacio`, Transparencia):** bloque discontinuo «Esta página está vacía · Escribe aquí o pega el borrador de loro-lola (F7.4b) · / para bloques · No se puede publicar sin cuerpo». Publicar queda desactivado.
**Carga / error:** esqueleto con la forma del lienzo y del inspector (`aria-busy`). Si falla, bloque con «Lo publicado no ha cambiado», Reintentar y Volver a páginas.
**Responsive:** igual que el editor de artículos: inspector fijo ≥ 1280, drawer de 360 entre 768 y 1279, hoja de 88 dvh por debajo; barra inferior Ajustes / Publicar; las bandas hacen salto de línea; sin scroll horizontal a 390 (comprobado).

### 10.4 · Copy
El microcopy del mockup es un borrador para el panel (solo ES). Lo revisa loro-lola. En el **sitio** solo hay un texto nuevo (es/en), que depende de la duda 3: «Última actualización: {fecha}» en las legales.

### 10.5 · Para backend (jabali-javi → leona-lia) y DevOps
1. **Slugs fuera del editor:** `has_en` no debe depender de `slug_en`. Pasa a ser `title_en` + `body_html_en`, o el cliente rellena `slug_en` fijo desde la tabla de rutas y un trigger impide cambiar los slugs.
2. **`unpublish_page(p_id)`** (como `unpublish_article`, con registro). Rechaza `legal_notice`, `privacy` y `cookies` si están publicadas (duda 2). **PT423** para pages, igual que en artículos.
3. **Fecha de última actualización:** columna `revised_on date` (no `updated_at`, que cambia con cualquier guardado). Se fija al publicar si cambian el título o el cuerpo, salvo que el panel pida conservarla. Si es futura, error (CHECK `<= current_date`). Va en la lista blanca de `content_drafts`.
4. **Crear la fila `transparency`** sin publicar, con `title_es = 'Transparencia'` y el cuerpo vacío (los valores por defecto actuales ya lo permiten).
5. **Versiones de las legales:** `guide.page_versions` (page_id, body_html_es/en, title, revised_on, published_at, published_by), escrita por `publish_draft` y por la primera publicación. Solo lectura para el admin. Sirve para saber qué texto estaba en vigor cuando alguien se suscribió (enlaza con `consent_version`).
6. **OG:** si se aprueba la duda 6, coneja-lucky hace que `PageEditorial`/`usePageSeo` lean `og_media_id` (hoy no lo leen). En las legales, la columna se ignora.
7. **osset-op:** regenerar `/sobre-mi` y las páginas con ISR de 1 día al publicar (revalidación bajo demanda o deploy hook). Hasta que exista, el panel muestra el plazo real (§10.3).
8. Contadores para el listado: N de cambios por página (como en artículos) y `revised_on`.

### 10.6 · Dudas para Xavi (una sola lista, junto con la auditoría de backend; recomendación en cada una)
1. **URL fija y fuera del editor.** Las rutas están en el código y los slugs de la BD no se usan. **Recomiendo:** mostrar la URL solo como dato, quitar los slugs del formulario y blindarlos en BD (§10.5-1).
2. **¿Despublicar las legales?** **Recomiendo no** para Aviso legal, Privacidad y Cookies una vez publicadas: las exige la LSSI/RGPD y las enlazan el pie y la casilla de la newsletter. Se corrigen con cambios. Sobre mí y Transparencia sí se pueden despublicar. Borrar, nunca.
3. **Fecha de «Última actualización».** **Recomiendo semiautomática:** al publicar un cambio de título o cuerpo de una legal se propone «Hoy», con la opción «Mantener la anterior» para erratas. No se puede escribir a mano una fecha libre (evita fechas atrasadas o futuras). Solo en las legales, y visible en el sitio bajo el título.
4. **Crear `transparency` ya** (sin publicar). **Recomiendo sí:** el sitio ya la enlaza desde muchos sitios y así aparece en el listado con «Sin contenido». El texto llega en F7.4b.
5. **SEO e indexación por página.** **Recomiendo:** título y descripción SEO editables por idioma en las cinco. «No indexar» editable solo en Sobre mí y Transparencia; las legales, siempre noindex, follow, fijo en código y mostrado en el panel como dato.
6. **Imagen OG.** **Recomiendo:** propia (opcional) en Sobre mí y Transparencia, que se comparten; en las legales, siempre la de Ajustes. Requiere un ajuste pequeño en el sitio.
7. **Historial de las legales más allá de Actividad.** **Recomiendo sí:** una copia fechada por publicación (§10.5-5), visible en el inspector como «Versiones publicadas». Es la prueba de qué decía la política cuando alguien dio su consentimiento.
8. **Bloques en las legales.** **Recomiendo:** sin imagen, vídeo ni tarjeta de ficha (solo texto, títulos, listas y enlaces). La tabla de cookies se escribe como lista. Si en F7.4 hace falta una tabla de verdad, se añade un nodo de tabla al editor entonces.
9. **Programar publicación.** **Recomiendo no** en v1: Publicar es inmediato.
10. **Marcas provisionales** (`[XAVI: …]`, «Texto provisional»). **Recomiendo** que solo avisen (ámbar en el checklist y en el modal) y no bloqueen. La alternativa es bloquear solo en las legales.


## 11 · Suscriptores (F6.14) · propuesta

Mockup: `suscriptores.html`. Estados con el selector «Mockup» o con el hash: `#activos`, `#sin-confirmar`, `#bajas`, `#todos`, `#ficha` (activo), `#ficha-pendiente`, `#ficha-caducado`, `#ficha-baja` (se fue, volvió y se volvió a ir), `#baja`, `#lote`, `#suprimir`, `#antes-f46`, `#cargando`, `#vacio`, `#sin-resultados` y `#error`. A 390: `anchos.html?solo=suscriptores.html%23ficha&w=390`.
Ruta `/administrador/suscriptores?vista=activos|sin-confirmar|bajas|todos&origen=…&idioma=…&fecha=alta|confirmacion|baja&desde=…&hasta=…&version=…&q=…`. No hay dirección alternativa: es `AdminDataTable` (Artículos y Agenda) con un drawer de solo lectura, como el detalle de Opiniones. Sustituye al mockup de 5.5: se quitan la columna y la cabecera «Brevo sincronizado» y el modal de exportar.

### 11.1 · Modelo que se respeta (`guide.subscribers` + `subscriber_consent_events` + auditoría de jabali-javi)
- **Estados y chips** (siempre texto + icono). Hace falta un tipo nuevo en `AdminStatusChip` para cada uno:

| BD | Chip | Token · icono | Vista |
| --- | --- | --- | --- |
| `active` | Activo | `st-pub` · punto | Activos |
| `pending` | Sin confirmar | `st-warn` · `clock` | Sin confirmar |
| `expired` (propuesto) | Caducado | `st-hidden` (discontinuo) · `hourglass` | Sin confirmar |
| `unsubscribed` | Baja | `st-neutral` · `user-x` | Bajas |
| `bounced` | Rebotado | `st-danger` · `mail-x` | Bajas (solo existe con proveedor) |
| `erased` (propuesto) | — | No se lista | Solo cuenta en el resumen y en Actividad |

  La baja **no** va en rojo: es una decisión legítima del lector, no un error.
- **Regla 8:** la cuenta (Google) sale como dato aparte, con el texto «Iniciar sesión no es consentimiento: lo que vale es la casilla de arriba». Nunca se deduce el consentimiento de la cuenta.
- **No hay alta ni reactivación desde el panel.** No hay botón «Nuevo», ni «Volver a suscribir», ni edición de ningún campo. Solo la persona vuelve a entrar, con un alta nueva desde el sitio y su doble opt-in (el historial lo muestra como «Volvió a suscribirse»).
- **Orígenes** (`consent_source`): Pie de página · Inicio · Ficha · Artículo · Artículo · a mitad · Artículo · al final · Ventana emergente (no debería haber, D22) · Importado (`admin_import`, ver duda 6). **Vía de baja** (`unsubscribe_source`): Enlace del email · Proveedor de email · Desde el panel · Desde su cuenta.
- **Fechas** en hora de Barcelona, con día, mes, año y hora en la ficha, y solo día y mes en las filas.

### 11.2 · Listado
- **Cabecera:** «Suscriptores» y un chip `st-neutral` con `plug` y el texto «Envíos sin conectar» (title: «El proveedor de email (Brevo) se conecta en F4.6»). A la derecha va **Exportar esta vista** (fantasma), un enlace a `/administrador/exportar?tipo=suscriptores&…` con los filtros de la vista (se diseña en 6.15). No hay acción primaria.
- **Resumen** (`dl`, 4 celdas, 2×2 por debajo de 1024): Activos (+N en 30 días) · Sin confirmar (N caducados) · Bajas (N en 30 días) · Altas en 30 días (% que confirma · N suprimidos). Con proveedor se añade una quinta celda, «Errores de envío», que solo aparece si hay alguno. Las gráficas son de 6.16.
- **Pestañas** con recuento: Activos (por defecto) · Sin confirmar · Bajas · Todos. Rebotados no tiene pestaña: van en Bajas con su chip.
- **Franja de la vista** (`side`, 12 px, `info`): explica qué significa cada vista. En Sin confirmar dice «no reciben nada» y cuándo caducan. En Bajas: «Desde el panel no se puede volver a suscribir a nadie».
- **Barra:** búsqueda por email (`/`, contiene, sin distinguir mayúsculas) · **Origen** (casillas con recuento) · **Idioma** · **Fechas** (menú con un `seg` Alta / Confirmación / Baja más un rango; por defecto, Alta) · **Texto aceptado** (versiones: sirve cuando cambia la política). En Todos se añade **Estado**, y con proveedor, **Sincronización**. Los filtros activos salen como fichas con × y «Quitar filtros», y todo va en la URL. Paginado en servidor (25/50/100) con total.
- **Columnas** (orden por Alta, de más reciente a más antigua; el email y la casilla van fijos a la izquierda y ⋯ a la derecha):
  - Activos: Email · Idioma · Origen · Alta · Confirmado · Texto (`v3`, mono) · Cuenta.
  - Sin confirmar: Email · Estado · Idioma · Origen · Alta · **Esperando** («hace 2 días», con «caduca el 3 nov» o «se anonimiza el 11 nov» debajo).
  - Bajas: Email · Idioma · Origen · Alta · **Baja** · **Vía** (con el motivo debajo si fue desde el panel).
  - Todos: Email · Estado · Idioma · Origen · Alta · Último cambio.
  - Con proveedor, se añade la columna «Envíos» (Sincronizado / Pendiente / Error + «Reintentar»), oculta hasta F4.6.
- **Menú de fila:** Ver prueba de consentimiento · Copiar email · Dar de baja… (no sale si ya está de baja) · Suprimir datos (RGPD)… (`danger`).
- **Lote:** casillas (desactivadas en las bajas) y barra flotante «N seleccionados · Dar de baja… · Exportar». **La supresión nunca va en lote.**
- **< 768:** tarjetas de 64 px como mínimo (email en mono truncado, chip, idioma, origen y fecha o «esperando») con ⋯ de 44 px. Las pestañas se desplazan dentro de su barra. Sin scroll horizontal.

### 11.3 · Ficha (drawer 480; hoja en < 768): solo lectura
Cabecera: email en mono (truncado) + chip. Secciones, en este orden:
1. **Banner** según el estado: Baja («No recibe nada. Solo esta persona puede volver…»), Caducado («No confirmó en 7 días: nunca recibió la newsletter. El email se anonimiza solo el …»).
2. **Prueba de consentimiento** (caja `side`, `dl` de 128 px + 1fr; en < 390, apilada):
   - **Cuándo**: fecha y hora + «hora de Barcelona».
   - **Desde dónde**: origen + página en mono (enlace al sitio).
   - **Texto aceptado**: «Versión 3 · ES» y un desplegable «Ver el texto exacto» con la cita (`lang` del idioma que vio) y «Vigente del … al …». Si era EN y esa versión no tenía texto EN: «vio el español».
   - **Doble opt-in**: «Confirmado» (`badge-check`, `st-pub`) + fecha · «Sin confirmar · enviado hace N días · caduca el …» · «Caducado».
   - **Baja**: fecha + vía + motivo, o «—».
   - **Idioma** y **Cuenta**.
   - Botón silencioso **Copiar como texto**: copia la prueba en texto plano (para responder a la persona o a la AEPD). Pie: «No se guardan IP ni navegador».
3. **Historial** («no se puede editar»): línea de tiempo con los eventos de `subscriber_consent_events`, del más nuevo al más antiguo: Se suscribió / Volvió a suscribirse (origen, versión, idioma) · Email de confirmación enviado (con proveedor) · Confirmó (doble opt-in) · Caducó sin confirmar · Se dio de baja (vía, motivo) · Rebotó. Debajo de cada uno, la fecha y **quién**: La persona · Tú (Xavi) · Sistema. Punto `st-pub` en confirmar, `meta` en baja y caducar, `warn-icon` en «enviado».
4. **Proveedor de email**: «Sin conectar todavía (F4.6)». Con proveedor: Sincronizado hace X / Pendiente / Error con el mensaje corto y «Reintentar».

Pie: **Dar de baja…** (fantasma, solo si no está de baja) · **Suprimir datos…** (peligro suave, a la derecha) + una línea de ayuda con la diferencia. No hay «Guardar»: no se edita nada.

### 11.4 · Dar de baja (`#baja`, `#lote`)
- `alertdialog` con el foco en **Cancelar**. Título: «¿Dar de baja a {email}?» (o «a N suscriptores», con la lista de los 5 primeros y «y N más»).
- Texto: «Dejará de recibir la newsletter. **Desde el panel no se puede deshacer:** solo esa persona puede volver a suscribirse, con un alta nueva y su confirmación por email».
- **Motivo obligatorio** (radios): Me lo pidió (email, mensaje o en persona) · Email erróneo o de prueba · Alta que no hizo esa persona · Otro. Mientras no se elige, el botón está desactivado.
- Nota: «Queda en su historial: fecha, "desde el panel" y el motivo. La prueba de consentimiento se conserva».
- Botón `btn-danger` «Dar de baja» / «Dar de baja a N», con `aria-busy` y «Dando de baja…».
- No se escribe el email (eso se reserva para la supresión): es irreversible pero no borra datos.
- Toast de éxito **sin Deshacer** («{email} dado de baja · ya no recibirá emails»). Deshacer sería volver a suscribir, y eso no se permite. Si falla, toast de error persistente con Reintentar.
- Si se da de baja a alguien que está **Sin confirmar**, también vale: el enlace de confirmación deja de funcionar.

### 11.5 · Suprimir datos (RGPD) (`#suprimir`): distinto de la baja
| | Dar de baja | Suprimir datos |
| --- | --- | --- |
| Para qué | Dejar de enviar | Derecho de supresión (art. 17) |
| Email | Se queda | Se borra (anonimizar) |
| Prueba e historial | Se conservan con el email (demuestran que se respetó la baja) | Se quedan **sin email**: fechas, origen y versión, para que las cifras de 6.16 cuadren |
| Sale en el listado | Sí, en Bajas | No; solo cuenta en el resumen |
| Confirmación | `alertdialog` + motivo | `alertdialog` + motivo + **email escrito exacto** (nivel 4 de §4.2) |
| En lote | Sí | Nunca |
| Deshacer | No | No |

- Diálogo: título «¿Suprimir los datos de {email}?» y texto «No se puede deshacer. Si solo quiere dejar de recibir emails, usa "Dar de baja"…».
- Dos columnas, **Se borra** (email, vínculo con la cuenta, página exacta y enlace de baja) y **Se queda, sin email** (historial anónimo; la cuenta de ChalkGuide y Chalk app no se toca).
- Banner `warn`: «Si exportaste suscriptores antes, borra también esos archivos» y «Cuando se conecte el proveedor, también se borrará allí».
- Motivo obligatorio: Lo pidió la persona · Email de prueba o erróneo · Otro. Campo «Escribe el email para confirmar» (mono, sin autocompletar ni corrector; compara sin mayúsculas ni espacios a los lados).
- `btn-danger` «Suprimir para siempre», desactivado hasta que el motivo y el email estén bien.
- Al terminar: se cierra la ficha, la fila desaparece y sale el toast «Datos suprimidos · ya no hay forma de saber quién era», sin Deshacer. Actividad registra «Suprimiste los datos de un suscriptor · motivo», sin email.
- Se puede suprimir en cualquier estado, también en Activo: suprimir implica dejar de enviar.

### 11.6 · Sin proveedor (`#antes-f46`) y futuro
- Hoy (F4.6 pendiente) no sale ningún email de confirmación, así que todo el mundo está en Sin confirmar. Por eso hay un `banner-info` bajo la cabecera: «Aún no se envían emails de confirmación… Hasta entonces, todas las altas se quedan en "Sin confirmar" y ninguna caduca». La vista por defecto pasa a Sin confirmar, el doble opt-in dice «el email de confirmación llega con F4.6» y no se muestra «caduca». Ver la prueba, dar de baja y suprimir ya funcionan.
- Cuando se conecte, el banner desaparece y el chip de cabecera cambia a «Envíos conectados» (o `st-danger` «N errores de envío» si los hay). Aparecen la columna «Envíos», el filtro «Sincronización», la quinta celda del resumen y la sección del proveedor en la ficha. **El diseño de hoy no depende de nada de esto.**
- «Reenviar confirmación» no sale hasta F4.6 (duda 7).

### 11.7 · Estados y responsive
- **Carga:** esqueleto de 8 filas con la forma de la tabla (`aria-busy`); el resumen, con guiones.
- **Vacío:**
  - Primera vez: «Aún no hay suscriptores», con «Ver el formulario en el sitio».
  - Sin resultados: «Nadie coincide con "…"», con «Buscar en Todos», «Quitar filtros» y la pista «o ya no existe (supresión RGPD)».
  - Vista vacía: Sin confirmar, «Nadie pendiente de confirmar»; Bajas, «Nadie se ha dado de baja».
- **Error:** `AdminStateBlock` con Reintentar y código.
- **Teclado:** `/` busca, ← → cambian de pestaña, Enter en el email abre la ficha, el foco vuelve a la fila al cerrar y el menú de fila se cierra con Esc.
- **Responsive:** 1440 con menú de 240 y tabla `min-w-[940px]` desplazable dentro de su contenedor; 768–1279 con raíl y la misma tabla; < 768 con tarjetas, ficha en hoja de 92 dvh con el pie fijo y botones a ancho completo, y el resumen en 2×2. Táctiles de 44.
- **No probado en navegador** en esta ronda (no se levantó servidor); el JS del mockup pasa `node --check`. Hay que revisarlo a 390, 768 y 1440 antes de aprobar.

### 11.8 · Para backend (jabali-javi → leona-lia)
1. **Cerrar la escritura directa.** Hoy la policy `subscribers_update` deja al admin cambiar cualquier columna (podría poner `active` o tocar `consent_*`, es decir, falsificar la prueba). Hay que quitar UPDATE, INSERT y DELETE directos a `authenticated` y dejar solo RPCs.
2. **`admin_unsubscribe(p_ids uuid[], p_reason text)`**: pasa a `unsubscribed` con `unsubscribe_source = 'admin'` y `unsubscribed_at = now()`. Rechaza a quien ya está de baja o suprimido. El motivo (CHECK: `request|wrong|abuse|other`) se guarda en el evento: añadir `reason` a `subscriber_consent_events`. No existe la operación inversa.
3. **`admin_erase_subscriber(p_id, p_reason)`** = `erased`: `email = null` (o hash, ver duda 2), `user_id`, `consent_page`, `brevo_contact_id` y `unsubscribe_token` a null o rotados. Conserva los eventos sin datos personales (quitar `page` también de los eventos) y añade un evento `erase` + una línea en Actividad sin email. El guard append-only tiene que permitirlo y la columna `email` debe aceptar null en `erased`. leona-lia, que valide que no queda el email en `activity_log` ni en snapshots.
4. **`expired`:** estado o derivado. Lo marca una tarea programada a los N días sin confirmar (evento `expire`), y a los M días lo anonimiza igual que en el punto 3. **Solo se activa cuando F4.6 envíe confirmaciones** (si no, caducaría todo).
5. **`guide.consent_texts`** (`version` pk, `text_es`, `text_en`, `valid_from`, `valid_to`): un trigger la escribe cuando Ajustes sube `consent_version`. Hay que rellenar hacia atrás las versiones ya usadas (la v1 sale del `default` de la migración editorial). La ficha la necesita para «Ver el texto exacto».
6. **Listado:** una RPC o vista `admin_subscribers` paginada en servidor, con total, recuento por pestaña y filtros (estado, `source[]`, `locale`, `consent_version`, tipo de fecha + rango, `q` ILIKE en email). Devuelve `has_account boolean`, nunca datos de `auth.users`. Orden por `consent_at` desc.
7. **Resumen:** recuento por estado, caducados, bajas en 30 días, altas en 30 días, % que confirma y suprimidos. Con proveedor, también los errores de sincronización.
8. **Ficha:** eventos del suscriptor con `occurred_at`, `event`, `source`, `consent_version`, `locale`, `page`, `actor` y `reason`. La UI traduce `actor` (`anon`/`user` → La persona, `admin` → Tú, `service` → Sistema).
9. **Futuro (F4.6):** `brevo_sync_status` (`not_synced|pending|synced|error`) + `brevo_sync_error` corto. La supresión y la baja deben propagarse al proveedor.
10. **`export_subscribers`** debe excluir a los `erased` (lo usa 6.15).

### 11.9 · Dudas para Xavi (recomendación en cada una)
1. **Supresión = anonimizar** (propuesta de jabali-javi: `email` a null y se conservan los eventos sin datos personales) **o borrar la fila entera**. **Recomiendo anonimizar:** cumple el art. 17, no deja nada que identifique a la persona y mantiene bien las cifras de 6.16.
2. **¿Guardar una huella (hash) del email suprimido** para que no vuelva por una importación? **Recomiendo no:** no hay importación (duda 6) y la persona tiene derecho a volver a suscribirse desde el sitio.
3. **Caducidad.** jabali-javi propone ~30 días. **Recomiendo** caducar a los **7 días** sin confirmar (pasado eso, el enlace no lo va a usar nadie) y anonimizar a los **30**, y solo desde F4.6. Si prefieres un solo plazo, 30 días para las dos cosas.
4. **Baja sin Deshacer y con motivo obligatorio.** **Recomiendo sí**, por la regla de no reactivar. El motivo es una lista corta, para que el historial explique por qué lo diste de baja tú.
5. **Baja en lote.** **Recomiendo sí** para la baja (por ejemplo, limpiar emails de prueba), con la lista en el diálogo. La supresión, nunca en lote.
6. **`admin_import`.** **Recomiendo quitarlo** del CHECK: sin doble opt-in no hay prueba de consentimiento. Tampoco hay botón de alta manual en el panel.
7. **«Reenviar confirmación»** a quien está Sin confirmar. **Recomiendo no mostrarlo** hasta F4.6 y, después, solo una vez por alta, para no hacer spam. Así no hay botones que no hacen nada.
8. **Suprimidos en el listado.** **Recomiendo** que no salgan en ninguna vista: solo cuentan en el resumen y en Actividad. La alternativa es una vista «Suprimidos» con filas anónimas, que no aporta nada.

---

## 12 · Exportar (F6.15) · propuesta (D37: modal en cada módulo)

Mockup: `exportar.html`. Pinta el listado del módulo de fondo con el modal abierto. Un estado por módulo en el hash: `#articulos`, `#fichas` (rocódromos), `#opiniones`, `#suscriptores`, `#bajas`, `#agenda`. Estados: `#preparando`, `#vacio`, `#error`, `#error-archivo`, `#cancelar`, `#truncado`. El selector «Mockup» añade «Contando» y «Sin exportaciones». A 390 (hoja inferior): `anchos.html?solo=exportar.html%23bajas&w=390`.
D37 sustituye a la página única de la primera propuesta: **no hay ruta `/administrador/exportar`**. D36 manda en el backend: `guide.admin_export_count` da el recuento en vivo y `guide.admin_export` exporta y registra en la misma transacción. El front ya no llama a `log_export`.

### 12.1 · Dónde entra
- **Botón «Exportar»** (fantasma, `download`) en la cabecera de cada listado, a la derecha: Artículos, Rocódromos, Resoladores, Pies de gato (cada listado de fichas exporta **solo su tipo**), Opiniones, Agenda y Suscriptores (en Suscriptores sustituye al enlace «Exportar esta vista»). En `< 640`, solo el icono de 44 px con `aria-label="Exportar"`.
- **Menú lateral:** se quita «Exportar» del grupo *Datos*, que se queda con Estadísticas y Actividad. Hay que tocar `admin-nav.ts` y eliminar la ruta o el placeholder `exportar`. En la paleta `⌘K` se añade «Exportar {módulo}…», que navega al listado y abre el modal (`?exportar=1`, el parámetro se limpia al abrir).
- **Suscriptores:** se quita «Exportar» de la barra de lote (`bulkExportHref`). No hay exportación de una selección en ningún módulo en v1, aunque el backend acepte `ids`.
- **Últimas exportaciones:** sin página, el modal enseña una línea al pie: «Última exportación de {módulo}: ayer, 19:12 · 1.279 filas · CSV · Copia de seguridad» (de `admin_recent_exports`, filtrado por módulo). Si no hay ninguna: «Aún no has exportado {módulo}». El historial completo va en Actividad (6.18), pestaña «Exportaciones».

### 12.2 · Modal
`Dialog` de Reka, `dialog lg` (720), `role="dialog"`. No es `alertdialog` porque no es destructivo. El foco entra en el select de Estado; Esc y la × cierran; el foco vuelve al botón «Exportar». En `< 768` es la **hoja inferior** del panel (asa, 92 dvh, pie fijo con botones a ancho completo).
- **Cabecera:** «Exportar {módulo}» + «Con los filtros de la vista {vista}. Puedes ajustarlos aquí.» (si ya se ha cambiado el Estado o la vista no es exportable: «Elige qué filas incluir. Puedes ajustar los filtros aquí.») + ×.
- **Cuerpo:** secciones en fila (`96px 1fr`, separadas por `line`; en `< 768` se apilan):
  1. **Filas.** Select de Estado, sin recuento por opción (heredado de la pestaña activa; el recuento en vivo va en el pie) y los demás filtros heredados del listado como fichas con ×, que solo afectan al modal y no al listado. Debajo, «Ajustar filtros ▾» (`details`) con los filtros del módulo en rejilla de 2 columnas:

| Módulo (`p_module`) | Estado (`statuses`) | Ajustar filtros | Por defecto |
| --- | --- | --- | --- |
| Artículos (`articles`) | Todos · Publicados · Programados · Borradores | Categoría · Inglés · Publicado desde/hasta | La pestaña activa |
| Fichas (`items`, `category` fija por listado) | Publicadas y ocultas · Publicadas · Ocultas (`published`) | Inglés · Verificada desde/hasta | Publicadas y ocultas |
| Opiniones (`user_reviews`) | Visibles · Ocultas · Todas (Pendientes solo con premoderación) | Tipo de ficha · Idioma · Publicada desde/hasta | Visibles |
| Suscriptores (`subscribers`) | Activos · Sin confirmar · Bajas · Todos | Origen · Idioma · Texto aceptado · Alta desde/hasta (con el `seg` Alta/Confirmación/Baja si el listado lo trae) | Activos (D36) |
| Agenda (`events`) | Aprobados · Borradores · Cancelados · Descartados · Todos | Origen · Fecha del evento desde/hasta | Aprobados desde hoy |

  2. **Columnas.** Suscriptores: dos `.opt`. **Lo mínimo** (por defecto): `email, locale, status, consent_at, confirmed_at`. **Con prueba de consentimiento**: añade `id, consent_source, consent_version, consent_page, unsubscribed_at, unsubscribe_source, created_at`. Debajo, las fichas `code` y la línea «Nunca salen: tokens y enlaces de baja, la cuenta, datos del proveedor ni los suprimidos». Resto de módulos: «N columnas, con su clave técnica ▾» (desplegable con las fichas). En Opiniones va la línea «Con el nombre público del lector. Nunca su email ni su cuenta, ni las fotos». En Artículos y Fichas, la casilla «Incluir el texto completo», solo con JSON (desactivada con CSV y con la razón visible).
  3. **Formato.** `seg` CSV / JSON (240 px; ancho completo en móvil) y una línea de ayuda que cambia: «Para Excel o Numbers: separado por punto y coma, decimales con coma y acentos bien (UTF-8)» / «Para copias de seguridad o pasar a otra herramienta…». **Solo `;`**: sin opción de coma, para no añadir otro control al modal (Google Sheets y Numbers detectan el `;`).
  4. **Datos personales** (solo Suscriptores, si hay filas): ver 12.3.
  5. **Estado del resultado** (aviso en línea): 0 filas, error al contar, truncado.
  6. **Pie del cuerpo:** la línea de «Última exportación» + «Cada exportación queda en Actividad: qué, filtros, columnas, formato, filas. Nunca los datos.» (en Suscriptores: «…formato, filas y para qué. Nunca los datos.»)
- **Pie del modal** (fijo en la hoja): a la izquierda el **resumen en vivo** (`aria-live="polite"`): «**1.284** suscriptores · CSV» + nombre del archivo en mono truncado (con `title`). A la derecha, Cancelar (fantasma) y **Descargar N filas** (primario). Si está desactivado, el motivo va debajo y se enlaza con `aria-describedby`.

### 12.3 · Suscriptores: datos personales (D37: las cuatro medidas)
- Columnas mínimas por defecto (12.2).
- `banner-warn` (`shield-alert`): «**Contiene N emails.** Guárdalo en un sitio seguro, no lo compartas y bórralo cuando ya no lo necesites. Si después suprimes a alguien, bórralo también de este archivo». Si el estado no es Activos, un segundo aviso (`mail-x`): «Son N bajas» / «No han confirmado su email: no tienen consentimiento válido» / «Incluye bajas y altas sin confirmar», con «No los subas a ninguna herramienta de envío».
- **Finalidad obligatoria** (`purpose`): Copia de seguridad (`backup`) · Pasar a otra herramienta de envío (`send_tool`) · Responder a una petición, acceso o portabilidad (`data_request`) · Revisión o auditoría (`audit`) · Otro (`other`). Va al registro.
- **Casilla obligatoria**, desmarcada: «Entiendo que el archivo tiene datos personales y que soy responsable de guardarlo y borrarlo». Se desmarca si cambian el estado o las columnas, y al cerrar el modal.
- Descargar queda desactivado con el motivo «Elige para qué lo exportas y marca la casilla». No hay que escribir el email (no es irreversible).
- Sin «Exportar» en la barra de lote (12.1).

### 12.4 · Archivo
- **Nombre:** `chalkguide-{módulo}[-{estado}]-{AAAA-MM-DD}-{HHMM}.{csv|json}`, en minúsculas, sin acentos y en hora de Barcelona. Fichas: `chalkguide-fichas-{rocodromos|resoladores|pies-de-gato}-…`. «Todos» no añade sufijo.
- **CSV:** UTF-8 **con BOM**, separador **`;`**, CRLF, comillas RFC 4180. La cabecera usa la **clave técnica**, en el orden de `export.columns` (las filas jsonb llegan en orden alfabético). Decimales con coma (`4,5`). Fechas `AAAA-MM-DD HH:MM` en hora de Barcelona. Booleanos `sí`/`no`. Nulo = celda vacía. `scores`/`author_scores` → `nota_<clave>`; `details` → una columna por clave; listas unidas con ` | `. El backend devuelve los valores crudos; el front neutraliza fórmulas al generar el CSV (`app/utils/csv.ts`): prefija `'` a los textos que empiezan por `= + - @`, también tras espacios o caracteres invisibles, y entrecomilla `;`, `,`, tabuladores y saltos. Los números no se tocan.
- **JSON:** la respuesta de `admin_export` tal cual (`{ export: {…}, rows: […] }`), con 2 espacios, sin BOM.

### 12.5 · Flujo y estados (D36)
1. **Recuento:** al abrir y en cada cambio (debounce de 250 ms) se llama a `admin_export_count(p_module, p_filters)`. Si tarda más de 300 ms, sale un esqueleto en el resumen del pie con «Contando filas…» en `sr-only`, y Descargar se desactiva. No registra nada.
2. **Descargar:** una sola llamada a `admin_export(p_module, p_format, p_filters)`, que exporta y registra a la vez. Mientras dura: barra de progreso indeterminada o estimada en el cuerpo, «Preparando N filas…» en el pie, botón `aria-busy` «Preparando…» y **Cancelar**. El archivo se arma en el navegador con `export.columns` y se descarga. El modal se cierra, el foco vuelve a «Exportar» y sale el toast «Descargado · N filas · registrado en Actividad» (sin Deshacer).
3. **0 filas:** `banner-info` «Ninguna fila con estos filtros. Sin filas no se genera archivo ni se registra nada» + «Quitar filtros». Descargar desactivado.
4. **Error al contar:** `banner-err` (`role=alert`) con el código + «Reintentar». El pie dice «Sin recuento» y Descargar está desactivado.
5. **Error al exportar:** toast persistente + «Reintentar». El modal sigue abierto con los filtros y «Reintentar» solo actúa mientras el modal siga abierto. Si el servidor responde con un error (la RPC es una sola transacción, no queda registro): «No se ha podido preparar el archivo. No se ha descargado ni registrado nada». Si no hay respuesta del servidor (se cae la red, puede haber confirmado): «No se ha podido preparar el archivo. No se ha descargado; puede que quede registrada en Actividad». Si el servidor ya respondió y falla el armado o el guardado del archivo en el navegador, el registro es seguro: «No se ha podido guardar el archivo. No se ha descargado, pero la exportación quedó registrada en Actividad». Reintentar generará otra entrada.
6. **Cancelar** durante la preparación: se aborta la petición, pero **abortar el fetch no cancela la transacción en el servidor**, así que al cancelar no se sabe aún si quedó registro. El front lee la última entrada del módulo antes de llamar a `admin_export` y la relee a los **1,5 s y 4 s** de cancelar. Mientras comprueba: la barra de preparación desaparece, el foco sigue en el modal, el pie dice «Comprobando el registro…» (`aria-live`), **Descargar está desactivado** (una descarga nueva se confundiría con la cancelada) y Cancelar cierra el modal sin interrumpir la comprobación. Toast info según el resultado, porque el registro nunca debe mentir:
   - Hay entrada nueva: «Exportación cancelada · quedó registrada en Actividad», en cuanto se detecta. La línea de «Última exportación» se actualiza.
   - Sin entrada nueva a los 4 s, o no se ha podido leer: «Exportación cancelada · puede que quede registrada en Actividad».
   - Se cancela antes de enviar `admin_export` (aún en la lectura previa): «Exportación cancelada · no se ha descargado ni registrado nada», sin esperar. Es el único caso en que se puede afirmar.
7. **Más de 50.000 filas** (`truncated`): `banner-warn` «Hay N filas: se exportan las primeras 50.000 (límite por archivo). Acota con las fechas para sacar el resto». Se deja descargar.
- **Actividad (6.18):** «Exportaste 1.284 suscriptores (activos) · CSV · Copia de seguridad», con el chip «Datos personales» y el detalle (filtros, columnas, formato, filas, si se truncó). Nunca emails ni el texto de búsqueda.
- **Teclado:** Tab recorre las secciones; los `seg` son `radiogroup` (← →); los `details` se abren con Enter o Espacio; Esc cierra (salvo mientras prepara: Esc = Cancelar).

### 12.6 · Responsive
- **≥ 768:** modal de 720, cuerpo con scroll propio (`max-height: 100dvh - 32px`) y pie visible.
- **< 768:** hoja inferior de 92 dvh con asa. Las secciones se apilan con la etiqueta encima. Las fichas de filtro miden 32 de alto con una × de 28, y la fila entera queda en 44 si se toca el texto. «Ajustar filtros» tiene 44 de alto. Las `.opt` miden 56 como mínimo, y el `seg` de formato va a ancho completo. **Pie fijo**: resumen y nombre del archivo en una línea completa, debajo Cancelar y Descargar a medias (44) y el motivo de desactivado debajo. Sin scroll horizontal. Comprobado en el marco de 390 de `anchos.html` (cabecera, filtros, columnas, avisos y pie fijo) y a 1440.

### 12.7 · Para backend (jabali-javi, ya en D36)
- Contrato de filtros: el de `docs/security/F6.15-export-audit.md` («Contrato con el front»). La UI usa las mismas claves que cada listado.
- `admin_recent_exports` debe poder filtrar por módulo (o el front filtra los últimos N) para la línea «Última exportación de {módulo}».
- Después de que el front use `admin_export`, se aplica `supabase/pending/guide_f615_retire_log_export.sql`.

### 12.8 · Decisiones de Xavi (D37) y lo que sigue abierto
Cerradas: modal en cada módulo · CSV solo con `;` · las cuatro medidas en Suscriptores · Opiniones con el nombre público · cabeceras con la clave técnica · texto completo solo en JSON (D36).
Abiertas, con recomendación:
1. **Quitar «Exportar» del menú lateral** (y la ruta). **Recomiendo quitarlo:** sin página, el enlace no lleva a ninguna parte; la paleta `⌘K` cubre el acceso rápido.
2. **Cancelar después de que el servidor ya registró** (12.5.6). Cerrada en D37: el toast dice la verdad, sin borrar el registro. Corregida el 2026-10-30, porque abortar no cancela la transacción: ver la relectura y los tres textos de 12.5.6.

---

## 13 · Importar fichas (F6.15b, D50) · propuesta

Mockup: `importar.html` (sobre el shell del panel). El tipo va en `?tipo=pies|rocodromos|resoladores` y el estado en el hash:
- **Archivo:** `#subir`, `#leyendo`, `#error-formato`, `#error-plantilla`, `#error-tipo`, `#falta-columna`, `#columnas`, `#hojas`, `#vacio`, `#grande`.
- **Revisión:** `#revision` (con errores), `#revision-ok`, `#comas`, `#confirmar`, `#cambio`.
- **Importar:** `#aplicando`, `#resultado`, `#parcial`, `#detenido`.
- **Después:** `#listado`, `#lote`, `#lote-fallo`, `#portadas`.

Para verlo a 390: `anchos.html?solo=importar.html%23listado&w=390`. Revisado en Chrome a 1440 y en el marco de 390.
Backend: `docs/security/F6.15b-import-audit.md` (jabali-javi, 5 nov). Esta propuesta **sigue esa auditoría**: todo o nada por llamada, borrador si la ficha está publicada, vacío = no toca y fotos por referencia a Medios. Donde la auditoría deja una opción abierta, lo marco en 13.10.

### 13.1 · Entrada: página, no modal
- **Botón «Importar»** (fantasma, `upload`) en la cabecera de Pies de gato, Rocódromos y Resoladores, a la izquierda de «Exportar». En `< 768` no se muestra (ver 13.8). La paleta `⌘K` añade «Importar {tipo}…».
- **Página propia: `/administrador/{rocodromos|resoladores|pies-de-gato}/importar`**, con migas «{Tipo} / Importar». No va en el menú lateral. **No es un modal**, a diferencia de Exportar (D37):
  - la revisión es una tabla de 50 a 500 filas, con varios avisos por fila, filtros y paginación. En un modal de 960 eso es un scroll dentro de otro scroll, y un Esc o un clic fuera tira la revisión;
  - el flujo tiene cuatro pasos (Archivo · Revisión · Importar · Resultado) y Xavi tiene que poder ir a Medios en otra pestaña y volver;
  - la página aprovecha los 1440: tabla a ancho completo y barra de acciones fija abajo.
- Los diálogos cortos sí son modales: confirmar, publicar en lote y asignar portadas.
- **Salir de la página** durante la revisión no pregunta nada, porque no se ha escrito nada. Durante la importación hay `beforeunload` y guarda de ruta: «Se está importando. Si sales ahora, puede quedar a medias».

### 13.2 · Paso 1 · Archivo (`#subir`)
- **Dos columnas** (`1fr 360px`; se apilan en `< 1024`):
  - **Izquierda:** título «Importar {tipo}», entradilla, `dropzone` con «Elige un archivo o arrástralo aquí» y el texto «.xlsx o .csv · hasta 500 filas y 5 MB». Es un `input[type=file]` real con `accept`, dentro del `label`, y se usa con teclado.
  - **Derecha:** tarjeta «Plantilla de {tipo}» con **Descargar plantilla (.xlsx)** y el enlace «Exporta el listado en CSV, edítalo y súbelo aquí»; tarjeta **Cómo funciona** con cinco líneas: la URL identifica cada ficha · vacío no borra · todo o nada · nada se publica (y una publicada recibe un borrador) · las fotos van antes a Medios. Debajo, la línea «Última importación de {tipo}».
- **Lectura** (`#leyendo`): un chip con el archivo, una barra y el texto «Leyendo el archivo y comprobándolo con tus {tipo}. Todavía no se escribe nada…», con Cancelar. Se lee en el navegador y después se llama a `admin_import_items(…, 'dry_run')` en trozos de 100 filas. Al terminar se pasa a la revisión.
- **Formatos:**
  - **.xlsx:** se lee la hoja que se llama como el tipo («Pies de gato»…). Si no existe, se pide cuál (`#hojas`, radios con el número de filas de cada hoja; las vacías desactivadas).
  - **.csv:** UTF-8, con o sin BOM. **Separador `;` por defecto (D37).** Si la cabecera solo se puede leer con comas, se lee con comas y se avisa (`#comas`) con un `seg` «; | ,» en la barra del archivo.
  - Se rechazan .xls, .numbers, .ods y .xlsm.
- **Errores de archivo:** `banner-err` con el nombre del archivo en mono, qué pasa y qué hacer, y un botón si hay salida:

| Caso | Texto (provisional) | Acción |
| --- | --- | --- |
| Formato | «Este archivo no se puede leer. Sube un .xlsx o un .csv. En Numbers: Archivo › Exportar a › Excel.» | — |
| Sin fila de claves (plantilla anterior) | «No encontramos la fila de claves… descarga la nueva y pega tus filas debajo; las columnas siguen en el mismo orden.» | Descargar plantilla nueva |
| Otro tipo | «Este archivo es de rocódromos (trae `price_day_eur`…) y estás en Pies de gato.» Se detecta por las claves propias del tipo | Importar rocódromos |
| Falta `slug` o `name` | «Falta la columna `slug` (URL). Es la que dice qué ficha es cada fila…» | Descargar plantilla |
| Sin filas | `banner-info`: «El archivo no tiene filas de datos…» | — |
| Más de 500 filas o de 5 MB | «Tiene 640 filas y el máximo es 500. Divídelo en dos archivos…» | — |

- **Columnas desconocidas** (`#columnas`): `banner-warn` que exige decidir: «3 columnas no las reconocemos. Si sigues, se ignoran y sus datos no se importan». Debajo, la lista con letra y clave, y una sugerencia si la clave se parece a una real («`precio_desde` · ¿querías decir `price_min_eur`?»). Botones **Seguir sin esas 3** y Subir otro archivo. Las columnas de solo lectura que trae Exportar (`id`, `published`, recuentos, fechas de sistema) se ignoran siempre y se nombran en una línea aparte, sin pedir nada: así un CSV exportado se puede volver a subir tal cual. Las columnas que faltan no son error: lo que no viene, no se toca.

### 13.3 · Paso 2 · Revisión previa (`#revision`): antes de escribir nada
- **Barra del archivo:** icono, nombre en mono, «hoja "Pies de gato" · 56 filas · leído hace un momento», el `seg` del separador (solo CSV), «N columnas reconocidas ▾» (`details` con las que faltan y las ignoradas) y **Cambiar archivo**.
- **Resumen que también filtra:** 6 `stat` en fila (3 × 2 en `< 1024`). Son `button[aria-pressed]` con `aria-controls` hacia la tabla:
  - **Filas** (todas);
  - **Nuevas** · «Se crean sin publicar»;
  - **Actualizan** · «N publicadas, a borrador»;
  - **Sin cambios** · «No se tocan»;
  - **Con avisos** · «N bloquearán publicar» (número en `warn`);
  - **Con error** · «No se importan» (número y borde en `danger`).

  Es el filtro «solo errores» que se pedía, sin un control aparte. **Si hay errores, la revisión se abre ya filtrada en «Con error»**: corregir es el camino principal.
- **Aviso de fotos:** si hay portadas que no están en Medios, `banner-warn`: «23 portadas no están en Medios todavía. Puedes importar igual y asignarlas después, o subirlas ahora y comprobar de nuevo sin volver a subir el archivo». Botones «Abrir Medios ↗» (pestaña nueva) y **Comprobar fotos**, que repite el `dry_run` con el mismo archivo.
- **Tabla** (`tbl`, filas de alto variable, alineadas arriba, 25 por página):

| Columna | Contenido |
| --- | --- |
| Fila | Número de fila del Excel, en mono. Es el mismo que ve Xavi al abrir el archivo |
| Qué pasará | `chip`: **Nueva** (`st-acc`, `plus`) · **Actualiza borrador** (`st-neutral`) · **Actualiza · sigue oculta** (`st-hidden`) · **Publicada · a borrador** (`st-rev`, `git-branch`) · **Sin cambios** · **No se importa** (`st-danger`). Las filas con error llevan además una barra roja de 3 px a la izquierda |
| Ficha | Nombre y slug en mono |
| Portada | Miniatura si se encontró · «No está en Medios» con hueco discontinuo · «Sin texto alt» · «2 con este nombre» · «Sin archivo» |
| Errores, avisos y cambios | Una línea por problema: icono + **letra de columna** (`colref`, como en Excel) + **campo** + **valor** en mono + texto. Después, «N cambios ▾» (`details`) con `antes → después` (`diff-del` y `diff-add`), igual que «Ver cambios» (D23) |
| Al publicar | **Lista** (`ok`) · **Falta portada** o **N bloqueos** (`danger`) · **Publicar cambios** (`st-rev`) en las publicadas |

- **Tres niveles**, con icono y texto (nunca solo color; leyenda bajo la tabla):
  1. **Error** (`circle-x`): la fila no se puede escribir. Son los códigos de la auditoría (§4): `invalid_type`, `out_of_range`, `not_allowed_value`, `too_long`, `check:<conname>`, `slug_taken`, `brand_model_taken`, `identity_conflict`, `exists_as`, `slug_is_redirect`, `pending_draft`, `owned_only`, `unknown_criterion`, `inactive_criterion`, `media_external_url`, filas repetidas en el archivo y slug vacío o `sin-nombre`. En el slug vacío se **propone** uno («Propuesta: ocun-ozone, cópiala en la columna C»), pero no se inventa: la URL es la identidad de la ficha.
  2. **Bloqueará publicar** (`octagon-alert`): la fila entra, pero la ficha no estará lista. Son los bloqueos reales de `app/utils/*-checklist.ts` (y de `item_publish_blockers` cuando exista): portada (`media_not_found`, `media_ambiguous` o vacía), alt ES de la portada (`media_no_alt`, D27), nota de transparencia si la visita es invitada o los pies «cedidos por la marca», marca y modelo en pies de gato, horario válido en rocódromos y nombre, URL y ciudad.
  3. **Aviso** (`triangle-alert`): no bloquea. Son los avisos de las checklists: sin resumen ES, sin reseña o menos de 3 notas, verificada hace más de 6 meses, precio sin verificar o ausente (pies de gato), sin servicios (resoladores) y nota de transparencia EN. Se suman los avisos propios del importador: `review_body_kept` (ya tiene reseña y se conserva la suya), `rounded`, listas con repetidos, `looks_like_html`, código postal al que Excel quitó el 0 y nombre igual al de otra ficha con otra URL («Si has cambiado la URL, se creará otra ficha»).
- **Fichas publicadas (D23) en la revisión:** chip violeta «Publicada · a borrador», «N cambios ▾» con el diff y «Publicar cambios» en Al publicar. Lo vivo no se pisa nunca: se llama a `save_draft`. **Si ya tiene un borrador distinto, la fila da error** («Ya tiene 2 cambios sin publicar hechos en el editor y no se mezclan con el archivo. Publícalos o descártalos y vuelve a subirlo»). Las ocultas se actualizan directamente y siguen ocultas.
- **Descargar errores** (cabecera de la tabla, solo si hay errores): un CSV con fila, columna, campo, valor y problema, para tenerlo al lado mientras corrige el Excel.
- **Barra de acciones fija** (`actbar`): «**42** filas se escribirán · 10 con error quedan fuera · nada se publica» (`aria-live`).
  - **Con errores:** el primario es **Subir el archivo corregido** y el secundario «Importar sin las 10 con error…». El cliente no manda las filas con error, así que la llamada sale limpia (todo o nada).
  - **Sin errores:** el primario es «Importar N {tipo}…» y el secundario «Subir otro archivo». Si todo sale «Sin cambios», Importar queda desactivado y lo explica.
- **No hay editor de hoja de cálculo.** Desde la revisión no se edita ninguna celda.

### 13.4 · Confirmar (`#confirmar`)
Modal de 480 (`dialog`), titulado «Importar N {tipo}». Es una lista de lo que va a pasar, con icono por línea:
- Se crean N fichas nuevas, sin publicar.
- Se actualizan N sin publicar: cambian los campos que traen dato. **Esto no se puede deshacer.**
- N publicadas reciben un borrador de cambios y el sitio no cambia.
- N filas con error quedan fuera y no se envían.
- Las creadas se pueden deshacer mientras no se toquen.
- Nada se publica ni se borra, y queda en Actividad.
- Antes de escribir se comprueba todo otra vez.

Botones: «Volver a la revisión» y **Importar N {tipo}**. Se confirma siempre, porque las actualizaciones no tienen vuelta atrás. No hay que escribir nada para confirmar.

### 13.5 · Paso 3 · Importar y Paso 4 · Resultado
- **Hasta 100 filas, una sola llamada** (el caso normal: hoy hay 27 fichas y unas 75 por hoja). Barra indeterminada, «Comprobando otra vez y escribiendo…» y «o entran todas o ninguna». Sin Detener, porque son pocos segundos y cortar no deshace nada.
- **Más de 100 filas, por trozos de 100** con el mismo `batch_id`: barra por trozos («Trozo 2 de 3») y **Detener**, que para al acabar el trozo en curso. Solo se empieza si el `dry_run` de todos los trozos salió limpio.
- **`apply` vuelve a validar y exige la huella del `dry_run`.** Si algo cambió desde la revisión (`#cambio`), no escribe nada: se vuelve a la revisión con un `banner-err` («No se ha importado nada. Al comprobarlo otra vez, 1 fila ha cambiado desde la revisión…») y la fila marcada.
- **Resultado (`#resultado`):** `circle-check` + «Importación terminada · N {tipo} guardadas, ninguna publicada · Queda en Actividad». Botón «Deshacer importación…» (`undo_import_batch`): borra las creadas que nadie haya tocado y descarta los borradores nuevos; el toast dice qué no vuelve atrás («Las 6 actualizadas no cambian»). Cuatro cifras: Creadas · Actualizadas («3 publicadas, con borrador») · Sin tocar · Fuera. Después, **Y ahora**, en tarjetas con una acción cada una:
  1. **N fichas sin portada:** el camino cómodo es subir las fotos a Medios con el nombre que tienen en el archivo y **volver a subir el mismo archivo**, que las enlaza (el resto sale «Sin cambios»). La alternativa es «Asignar a mano» (13.6).
  2. **N listas para publicar** → Publicar las listas… (13.7).
  3. **N publicadas con cambios** → vista «Con cambios» del listado. Se publican una a una con su diff (D23).
  4. **N filas quedaron fuera** → Descargar errores · Subir corregido.
- **A medias (`#parcial`) y detenida (`#detenido`)**, solo con trozos: «Archivo de 240 filas en 3 trozos de 100. El trozo 2 no se escribió…». El lote queda `partial` y se ofrecen dos salidas: **Subir de nuevo**, que es seguro porque lo escrito sale «Sin cambios», o **Deshacer…**, que dice qué se deshace y qué no.
- **Actividad:** una entrada por lote: «Importaste 42 pies de gato: 35 nuevas, 4 actualizadas, 3 a borrador», sin datos ni nombre de archivo (auditoría §6). Las entradas por ficha se agrupan bajo el lote.

### 13.6 · Fotos y «Asignar portadas» (`#portadas`)
- **Lo que asume Xavi no se cumple:** una ficha no guarda una URL, sino una fila de Medios, porque ahí viven el alt (D27), el bloqueo de borrado y el reemplazo. En el archivo, la columna `cover` (y `og_image` y `gallery`, con ` | `) lleva **el nombre del archivo tal como se subió a Medios**, o su URL o su id de Medios. El servidor lo convierte en la fila de Medios. Una URL de otra web es error: no se descarga nada.
- **Estados de la foto en la revisión:** encontrada (miniatura) · **no encontrada** (aviso: entra sin portada y bloqueará publicar) · **nombre repetido en Medios** (aviso: no se elige ninguna) · **sin alt ES** (aviso: bloqueará publicar) · celda vacía.
- **Asignar portadas** es un modal `xl` que se abre desde el resultado o desde la barra de lote del listado. Lista de fichas sin portada, con las que tienen problemas primero. Cada fila tiene:
  - casilla;
  - ficha y nombre esperado;
  - miniatura y estado: **Coincide** · **Parecida, confírmala** · **Sin texto alternativo** · **2 con este nombre** (`seg` para elegir) · **No está en Medios** («Elegir de Medios…», el `MediaPicker`) · **Sin archivo**.

  En «Sin texto alternativo» va un campo de alt ES que se guarda en Medios («vale para todas las fichas que usen la foto»). Sin texto, su casilla queda desactivada. Arriba: «Subir en Medios ↗» y «Buscar de nuevo». Pie: «Asignar N portadas». Las publicadas reciben la portada en su borrador y las demás al momento. Toast con Deshacer.
- **Duda abierta (13.10, 4):** el servidor no guarda la referencia que no encontró, así que, después de importar, el modal solo puede **sugerir** por coincidencia con el slug, no por el nombre que había en el archivo. Por eso el camino principal es volver a subir el archivo.

### 13.7 · Después: el listado y «Publicar en lote» (`#listado`, `#lote`)
- **Listado con el filtro de la importación:** al llegar desde el resultado, el listado abre «Borradores y ocultos» con la ficha de filtro «Importación de hoy, 10:24 · 47 ×». Al lado va el `seg` **Para publicar: Todas · Listas · Les falta algo** y el atajo «Seleccionar las N listas».
- **Columna nueva «Para publicar»** (en Borradores y ocultos y en Todos):
  - **Lista** (`circle-check`, `ok`), con «· N avisos» si los hay;
  - **Falta portada** o el primer bloqueo (`octagon-alert`, `danger`), con «+N» si hay más;
  - en ocultas: «Oculta: publícala desde su ficha»;
  - en publicadas con cambios: «Ver cambios».

  Necesita que el servidor dé los bloqueos de cada ficha en el listado (`item_publish_blockers`, auditoría §3). No se calcula ficha a ficha en el cliente.
- **Barra de lote:** «N seleccionadas · Asignar portadas… · **Publicar…** · Eliminar…».
- **Publicar en lote** (modal `lg`; usa `PublishDialog.vue` como referencia: **bloquea y avisa**). Título «Publicar N {tipo}», con «Has elegido 16: se publican las 13 que nada bloquea. Se verán en el sitio al momento». Grupos, en este orden:
  1. **No se publican: algo lo bloquea** (`danger-soft`, `role=alert`). Ficha + el `hint` de la checklist + «Abrir».
  2. **Ocultas no se publican en lote** (`subtle`). «La ocultaste tú: si quieres que vuelva, publícala desde su ficha». Ocultar fue una decisión, y deshacerla también.
  3. «N listas: nada bloquea su publicación» (`circle-check`).
  4. **Avisos (no bloquean)** (`warn-soft`), por ficha.
  5. Una línea de transparencia (regla 7): «Las cedidas por la marca y las que tienen enlace de afiliado se marcan siempre en la ficha».

  Pie: «Seguir revisando» y **Publicar N {tipo}**, desactivado si N = 0. Las publicadas con cambios **no** entran en este lote: se publican una a una con su diff.
- **Publicación:** una llamada a `publish_items(ids)` (máximo 100) mientras el botón dice «Publicando…» (`aria-busy`). Si alguna falla en el servidor, las demás siguen. El toast de error persistente nombra cuál no se publicó y por qué, con «Abrir» (`#lote-fallo`). Si todo va bien: «13 fichas publicadas · ya se ven en el sitio · Ver». Sin Deshacer: para retirarlas está Ocultar.

### 13.8 · Responsive
- **≥ 1024:** como en el mockup.
- **768–1023:** el flujo funciona entero. El resumen pasa a 3 × 2, la ayuda va debajo de la zona de subir y la tabla se desplaza en horizontal dentro de su tarjeta (sin scroll horizontal de página).
- **< 768:** **no se ofrece importar.**
  - El botón no sale en la cabecera ni en la barra inferior.
  - Si se llega a la ruta, se ve un estado vacío: «Importar se hace en un ordenador. Revisar decenas de filas y corregir el Excel pide una pantalla grande. Desde el móvil puedes asignar portadas y publicar las fichas que ya están listas». Debajo, la tarjeta «Última importación» y dos botones de 44 px: «Ver las fichas importadas» y «Asignar portadas».
  - **Sí funcionan en móvil:** el listado con su filtro (tarjetas con casilla de 20 px, chip y «Para publicar»), Publicar en lote (hoja inferior) y Asignar portadas (hoja inferior, con cada fila apilada en dos líneas). Son tareas rápidas, como pide la guía del panel.
- Táctiles ≥ 44 en `< 768` (lo da `admin.css`). Sin scroll horizontal, comprobado en el marco de 390.

### 13.9 · Accesibilidad e interacción
- Pasos: un `ol` con `aria-current="step"` y «(hecho)» en `sr-only`.
- Los `stat` son botones con `aria-pressed` y `aria-controls`. El foco se queda en el `stat` al filtrar y el título de la tabla cambia («Con error · 10»).
- La tabla tiene `aria-labelledby` a su título. Cada problema lleva su nivel en `sr-only` («Error:», «Bloqueará publicar:», «Aviso:») y la letra de columna, `title`.
- Los errores de archivo usan `role=alert`. El resumen de la barra, el progreso y los resultados usan `aria-live=polite`, y la importación terminada se anuncia.
- Movimiento: 150 ms; la barra indeterminada se queda quieta con `prefers-reduced-motion`.
- Teclado: el `input[type=file]` va en el `label`. En los modales, Esc cierra (salvo mientras publica) y el foco vuelve al botón que lo abrió.

### 13.10 · Plantilla (`docs/contenido/plantilla-fichas.xlsx`): qué cambia para que se pueda importar
1. **Fila de claves técnicas.** Se inserta como **fila 3** con `clave` en la columna A, en mono y bloqueada. Las filas quedan así:
   - 1: Pestaña del panel;
   - 2: Campo;
   - 3: **Clave**;
   - 4: Nivel;
   - 5: Formato y reglas;
   - 6: **Ejemplo**, con `ejemplo` en A (no se importa);
   - desde la 7: datos.

   El importador busca la fila con `clave` en A, no un número de fila fijo. Como **no cambia el orden de las columnas**, quien ya tenga filas en la versión anterior puede copiarlas y pegarlas en la nueva. Hay que mover la inmovilización de paneles (`ySplit`) y las validaciones (hoy `I6:I80`, `O6:O80`…) a `7:506`.
2. **Claves:** las de la auditoría §8 (`draft_allowed_columns`), que coinciden con las cabeceras de Exportar (D37). Así un CSV exportado y editado se puede volver a subir.
   - Fotos: `cover`, `og_image`, `gallery` (con ` | `).
   - Reseña: `review_text_es`, `review_text_en`, `headline_*`, `visit_type`, `visit_date`, `disclosure_note_*`.
   - Notas: `nota_<clave del criterio>`, igual que en Exportar: `nota_comfort`, `nota_edging`, `nota_smearing`, `nota_durability` (pies de gato); `nota_setting`, `nota_variety`, `nota_crowding`, `nota_facilities`, `nota_beginner_friendly`, `nota_family_friendly`, `nota_value` (rocódromos); `nota_quality`, `nota_turnaround`, `nota_service`, `nota_value` (resoladores). El cliente las une en `scores`.
   - Horario: `opening_hours_mon` … `opening_hours_sun`, con «10:00-14:00, 17:00-23:00» o «Cerrado». El cliente lo convierte al objeto de §4.5.
3. **Columnas que salen:** «Portada: texto alt ES/EN». El alt se escribe en Medios y el servidor ignora esas columnas. Hay que quitarlas o marcarlas en gris como «no se importa, cópialo en Medios». Recomiendo quitarlas.
4. **Valores:** la plantilla sigue en español («Cordones», «Sí», «En la media», «12,5», fechas de Excel). El cliente acepta la etiqueta y también el valor de la BD (`lace`, `true`, `3`, `12.5`), y el servidor solo recibe valores de la BD. Hay que dar formato de texto al **código postal** (para que no pierda el 0) y a la **URL**.
5. **Léeme:**
   - quitar «El panel no importa archivos»;
   - cambiar «Cómo pasarlo al panel» por: 1) sube las fotos a Medios y escribe su alt; 2) rellena desde la fila 7, con el nombre de archivo de la foto; 3) en el listado, Importar → revisa → importa; 4) publica en lote las que estén listas;
   - nueva sección «Reglas de la importación»: la URL identifica; vacío no borra (para vaciar, el editor); nada se publica; publicada = borrador; si ya tiene un borrador, error; la reseña solo se escribe si la ficha no tiene una; máximo 20.000 caracteres de reseña y 500 filas por archivo;
   - los niveles OBLIGATORIO y RECOMENDADO hablan de **publicar**: añadir que para **importar** solo hacen falta `name` y `slug`.
6. **La columna de estado** (la fórmula «Lista / Faltan N», con `<f>` en cada fila) se queda como ayuda, pero va **fuera del área de datos o con su clave vacía**, para que el importador no la lea. Se elimina la referencia a la columna «texto alt».
7. **Una plantilla por tipo**, que es lo que descarga cada listado: `chalkguide-plantilla-{pies-de-gato|rocodromos|resoladores}.xlsx`, con el Léeme y su hoja. Es un archivo estático en `public/` con versión en el Léeme. El libro con las tres hojas sigue sirviendo, porque el importador lee la hoja de su tipo.

### 13.11 · Para coneja-lucky y jabali-javi
- **Front:**
  - lectura de .xlsx en el navegador con una librería sin fórmulas ni macros (leer valores cacheados), a elegir con leona-lia;
  - mapeo de etiquetas a valores;
  - partir en trozos de 100;
  - `dry_run`, revisión y `apply` con la huella;
  - el CSV de errores se genera con `app/utils/csv.ts` (BOM, `;` y fórmulas neutralizadas);
  - antes de mapear, quitar el `'` que Exportar antepone a los textos que empiezan por `= + - @`, para que un CSV exportado y vuelto a subir no gane un apóstrofo;
  - reusar los `hint` de `*-checklist.ts` para los bloqueos y avisos. Los textos de los códigos del servidor los escribe loro-lola.
- **Backend (pendiente de aprobar la auditoría):**
  - `admin_import_items`, `publish_items`, `undo_import_batch` e `item_publish_blockers`;
  - el bloqueo de cada ficha en la vista del listado (columna «Para publicar»);
  - `activity_action` `import`.

### 13.12 · Dudas para Xavi (con recomendación)
1. **Página propia o modal.** **Recomiendo página** (`/…/importar`), por el tamaño de la revisión (13.1). Exportar sigue en modal.
2. **Importar dejando fuera las filas con error.** **Recomiendo permitirlo**, como acción secundaria y con confirmación. El primario sigue siendo «Subir el archivo corregido». Si prefieres obligar a corregirlo todo, se quita ese botón y nada más cambia.
3. **Fotos desde el archivo o siempre desde el editor** (auditoría, decisión 5). **Recomiendo desde el archivo**, con nombre, URL o id de Medios: es lo que hace cómodo el «sube las fotos y vuelve a subir el Excel».
4. **Recordar el nombre de foto que no se encontró** (para que «Asignar portadas» lo use después). Hoy el servidor no lo guarda. **Recomiendo no hacerlo en v1:** volver a subir el archivo resuelve lo mismo sin tabla nueva, y el modal sugiere por slug. Si las fotos te llegan siempre después, se puede guardar en `import_batch_items` (lo decide jabali-javi).
5. **Publicar en lote los cambios de fichas ya publicadas.** **Recomiendo que no en v1:** cada uno pasa por su diff (D23). Si vas a usar la importación sobre todo para actualizar precios, lo replanteamos.
6. **Vaciar campos desde el archivo.** La auditoría dice que no en v1 (vacío no toca y `null` se rechaza). **De acuerdo:** se vacía en el editor. Lo dejo dicho en la plantilla y en «Cómo funciona».
7. **Reseña en texto plano en v1, solo si la ficha no tiene reseña.** **Recomiendo sí**, como propone jabali-javi. Al revisar se avisa de que se conserva la del panel.
8. **¿Ya has empezado a rellenar la plantilla actual?** Si es así, no se pierde nada: pegas tus filas en la nueva, porque las columnas no cambian de orden. **Recomiendo** no hacer que el importador lea también la plantilla anterior.
9. **Móvil.** **Recomiendo no ofrecer importar en `< 768`.** En móvil sí funcionan el listado, publicar en lote y asignar portadas (13.8).

---

## 14 · Inicio v2 (D52, ajusta D23) · propuesta

Mockup: `inicio-v2.html`. Estados en el hash: `#normal` (con pendiente), `#mucho`, `#vacio` (nada pendiente, nada programado y 0 suscriptores: el estado real de hoy, antes de lanzar) y `#cargando`. Para verlo a 390: `anchos.html?solo=inicio-v2.html%23mucho&w=390`. Revisado en Chrome a 1440, 768 y 390.
Parte del P2 de `.impeccable/critique/2026-11-05T19-04-08Z__app-admin.md`. Corrige cuatro cosas: el calendario ocupa la pantalla aunque no haya nada, la tarjeta de altas se estira, la sparkline plana a 0 y el título del mes partido en dos líneas.

### 14.1 · Orden de la página
| Orden | Bloque | Cambia respecto a D23 |
| --- | --- | --- |
| 1 | Saludo y fecha | Igual |
| 2 | **Pendiente**, a ancho completo | Antes: tarjeta lateral de 380 junto al calendario |
| 3 | KPIs (4) | Antes: lo primero. La sparkline solo se pinta si la serie tiene datos |
| 4 | **Calendario editorial, 2 semanas** por defecto, a ancho completo | Antes: mes entero en `1fr`. «Mes» sigue disponible |
| 5 | Altas por semana (`1fr`) · Actividad reciente (380) | `items-start`: cada tarjeta a su altura |

En `< 1280` todo se apila en ese mismo orden. En móvil, Pendiente es lo primero que se ve bajo el saludo (moderar desde el móvil es un uso declarado).

### 14.2 · Pendiente
- **Tres grupos, en orden de urgencia**. Solo se muestran los grupos que tienen filas:
  - **Moderar**: opiniones nuevas · fotos de lectores por revisar · eventos del agente por aprobar.
  - **Publicar**: cambios sin publicar (artículos, fichas, páginas) · fichas importadas sin publicar · borradores de artículo.
  - **Revisar**: fichas sin verificar hace más de 6 meses · fotos sin texto alternativo · páginas con texto provisional.
- **Rejilla**: en `≥ 1024`, una columna por grupo visible (`grid-template-columns: repeat(n, 1fr)`, separadas por `1px var(--line)`). En `< 1024`, una sola columna y los grupos uno debajo de otro, con borde superior.
- **Cabecera** (`card-h`): «Pendiente» + «5 tareas» (`text-xs muted`). A la derecha, en `≥ 768`: «De más urgente a menos».
- **Grupo**: título en sentence case, 12 px semibold `meta`, más el recuento en `muted` (no mono en mayúsculas, según la auditoría). Va en `h3` y la lista lleva `aria-labelledby`.
- **Fila** (enlace a ancho completo, `min-height: 56px`, `padding: 8px 16px`, `gap: 12px`):
  - icono de 16 en una pastilla de 32×32 y radio 8, con el tono del grupo: `acc` para moderar, `st-rev` para cambios, `subtle/meta` para borradores e importadas y `warn` para revisar;
  - línea 1: recuento + sustantivo, 13 px medium;
  - línea 2: contexto, 12 px `meta`;
  - chevron `muted`, que se desplaza 2 px en hover (150 ms, se anula con `prefers-reduced-motion`);
  - hover `subtle`; foco con `outline 2px acc`, `offset -2px`.
- **Aviso de plazo** («El primero, mañana»): icono `clock` + texto en `warn`. Solo aparece si el primer evento por aprobar cae en los próximos 7 días. No depende solo del color.
- **Destinos**, abriendo cada uno en su vista filtrada (coneja-lucky añade los parámetros que falten):

| Fila | Abre |
| --- | --- |
| Opiniones nuevas | `/administrador/opiniones` (vista Recientes, las nuevas marcadas) |
| Fotos de lectores | `/administrador/opiniones?vista=fotos` (§8) |
| Eventos por aprobar | `/administrador/agenda` (bandeja «Por aprobar») |
| Cambios sin publicar | `/administrador/articulos#cambios`. Si todos son fichas o páginas, abre su listado con la vista «Con cambios» |
| Fichas importadas sin publicar | Listado del tipo, filtrado por «Sin publicar» (§13.7) |
| Borradores | `/administrador/articulos?estado=borrador` |
| Fichas sin verificar | Listado del tipo con más fichas, filtro «Sin verificar» |
| Fotos sin alt | `/administrador/medios?filtro=sin-alt` |
| Páginas provisionales | `/administrador/paginas` |

- **Nada pendiente** (`#vacio`): la tarjeta se reduce a una fila de 56 px con un check en `ok-soft`, «Todo al día» y «Nada que moderar, publicar ni revisar». No lleva cabecera ni rejilla.
- **«Nada programado»** sale de Pendiente: no es una tarea, es el estado del calendario. Pasa al calendario (14.4).

### 14.3 · KPIs
- Mismas cuatro tarjetas y mismos enlaces que hoy.
- **Sparkline**: solo se pinta con al menos 2 puntos distintos de 0 y con alguna variación. Con la serie plana o a 0 no hay línea: la tarjeta queda con «0 altas · 0 bajas (30 d)» y sin hueco.
- El delta a 0 va en `meta`, no en `ok`.

### 14.4 · Calendario editorial
- **Vista por defecto: «2 semanas»**. Es la semana actual más la siguiente, de lunes a domingo, con 7 columnas y 2 filas de 88 px. Unos 260 px en total, frente a los ~600 del mes.
  - Los días pasados de la semana actual llevan fondo `side`. Hoy, número en círculo `acc`.
  - En cada día, el día de la semana va en minúscula y sentence case («jue 5»), sin mono en mayúsculas.
- **Navegación**: avanza y retrocede de dos en dos semanas. El rango va en una línea (`whitespace-nowrap`, sin ancho fijo): «2–15 nov 2026», «30 nov – 13 dic 2026».
- **«Mes»**: es la vista actual. Su título va **en una línea**, «Noviembre 2026» sin «de», con `whitespace-nowrap` y sin `w-32`. La vista elegida se recuerda en `localStorage` (`cg-admin-cal-view`).
- **Ventana vacía**: no se pinta la rejilla. En su lugar, una fila con icono `calendar-x`, «Nada programado en estas dos semanas» y una línea de contexto: «Último publicado: «…», 28 oct. Tienes 2 borradores». A la derecha, el botón **Programar un borrador** (→ Artículos, borradores). Las flechas siguen activas para mirar más adelante.
- **Leyenda**: «Con cambios» en lugar de «Publicado con cambios», para que quepa en una línea a 768. «Ver el mes» va a la derecha.
- **768**: la rejilla de 7 columnas cabe (unos 90 px por día). Los títulos se cortan a 2 líneas con `…` y el título completo va en `title` y en `sr-only`.
- **390**: lista de los próximos 14 días, **solo los días que tienen algo** (hoy se pintan todos). Si la ventana está vacía, se usa la misma fila vacía, con el botón a 44 px.

### 14.5 · Altas y actividad
- Rejilla `minmax(0,1fr) 380px` con **`items-start`**: cada tarjeta a su altura y sin hueco de ~350 px.
- **Altas sin datos** (todas las semanas a 0): no se pinta el gráfico. En su lugar, un estado vacío de una fila: icono `mail`, «Aún no hay altas» y «Con la primera verás aquí las altas de cada semana. La newsletter se conecta con Brevo antes del lanzamiento». La segunda frase se quita cuando haya proveedor.
- El eje pasa a 11 px (la auditoría pide nada por debajo de 11).
- Se ocultan «Estadísticas» y «Registro completo» hasta 6.16 y 6.18 (auditoría, P2 «callejones sin salida»).

### 14.6 · Cargando y error
- **Cargando**: esqueleto con la forma real. Tarjeta Pendiente con 3 columnas de barras, una banda de KPIs de 104 px y un calendario de 240 px. Barras planas, sin brillo animado (lint).
- **Error**: `AdminStateBlock` como hoy. Si falla solo el calendario, el error queda dentro de su tarjeta y Pendiente sigue visible.

### 14.7 · Para coneja-lucky
- `pages/administrador/index.vue`: cambia el orden; Pendiente sale de la rejilla de dos columnas; la fila de abajo lleva `items-start`.
- `dashboard/Pending.vue`: pasa a grupos (`{ label, rows[] }`), con la rejilla y la fila de 14.2. Se quita el pie «No hay nada programado».
- `dashboard/Calendar.vue`: añade la vista «2 semanas» y la fila vacía, y pone el título en una línea. Hace falta un `buildWeeksGrid(start, today, items)` en `utils/admin-dashboard.ts`, y que `calendarWindow` acepte también una ventana de 14 días.
- `dashboard/Kpis.vue`: añade la condición de la sparkline.
- `dashboard/Signups.vue`: añade el estado vacío con todo a 0 y oculta el enlace. `dashboard/Activity.vue`: oculta el enlace.
- Textos nuevos → loro-lola.

### 14.8 · Datos: qué hay y qué **requiere backend**
Disponible hoy (`admin_dashboard_stats` + `useAdminDashboard`): opiniones nuevas, `user_reviews_pending`, `events_drafts`, cambios sin publicar por tipo (`content_drafts`), `articles_by_status.draft`, `items_stale`, `media_without_alt`, suscriptores y altas, y la actividad. Las páginas con texto provisional ya se consultan en `services/admin/pages.ts` (sin RPC nueva). El último artículo publicado sale de una consulta simple a `articles` (sin RPC nueva).

**Requiere backend** (jabali-javi, campos nuevos en `admin_dashboard_stats`). Todos son opcionales: sin ellos, la fila sale sin esa parte de contexto.
1. `events_drafts_next_at`: fecha del primer evento por aprobar, para el aviso de plazo. Es el que más aporta.
2. `items_stale_by_category`: `{gym, resoler, shoe}`, para el desglose y para elegir el destino.
3. `review_photos_pending`: fotos de lectores por revisar (§8).
4. `items_imported_unpublished`: fichas de lotes de importación que siguen sin publicar (§13).
5. `user_reviews_low_since`: opiniones nuevas con nota ≤ 2.
6. `media_without_alt_in_use`: cuántas de las fotos sin alt están en contenido publicado.
7. `events_drafts_duplicates`: posibles duplicados entre los eventos por aprobar (Agenda ya los calcula al abrir la bandeja).

### 14.9 · Dudas para Xavi (con recomendación)
1. **KPI «Fichas por verificar»** repite una fila de Pendiente. **Recomiendo** cambiarlo por «Fichas publicadas» (por tipo; requiere backend) o dejar tres KPIs. Mientras tanto, se queda.
2. **Vista por defecto del calendario.** **Recomiendo «2 semanas»**. El mes sigue a un clic y se recuerda.
3. **Borradores de artículo en Pendiente.** No es urgente. **Recomiendo** dejarlo como última fila de «Publicar». Si te molesta, se quita sin tocar nada más.
4. **Acciones dentro de Inicio** (aprobar un evento u ocultar una opinión sin salir). **Recomiendo que no en v1**: moderar necesita el contexto de cada bandeja (impacto en la media, duplicados). La fila lleva a la bandeja filtrada.

---

## 15 · Búsqueda de contenido en ⌘K (D53, tarea 6.22) · propuesta

Mockup: `busqueda-cmdk.html`, interactivo. Escribe en la paleta. Los datos son de ejemplo y la latencia está simulada. Estados en el hash: `#resultados` («paret»), `#vacio` (sin escribir), `#cargando`, `#sin-resultados`, `#error` y `#ambito` (solo Artículos). En este mockup, ⌘K y la búsqueda del menú abren la paleta nueva. Revisado en Chrome a 1440, 768 y 390.
Sustituye a `AdminCommandPalette.vue`, que hoy solo filtra secciones y pone «La búsqueda de contenido llegará pronto».

### 15.1 · Qué se busca (prioridad)
| Prioridad | Tipo | Por qué |
| --- | --- | --- |
| 1 | Artículos | Es lo que más se edita |
| 1 | Rocódromos, Resoladores, Pies de gato | Muchas fichas (importación); hoy hay que ir al listado y filtrar |
| 2 | Agenda (eventos) | Encontrar un evento concreto para corregirlo |
| 2 | Medios | Encontrar una foto por nombre o alt, sin abrir la rejilla |
| 3 | Páginas | Son pocas, pero «aviso legal» desde ⌘K ahorra dos clics |
| No | Opiniones | Datos personales (nombre y texto del lector). Opiniones ya tiene su búsqueda. Ver la duda 15.10.1 |
| No | Suscriptores | Emails (RGPD). Solo desde Suscriptores, que tiene su propio registro |
| No | Categorías, criterios | Son pocos; se llega por «Ir a» |

### 15.2 · Anatomía
- **Diálogo** de 640 de ancho, anclado a `12vh` del borde superior, con `max-height: min(640px, 76vh)` y radio 12.
- **Campo** (52 px): icono de búsqueda, input de 15 px y `esc`. Placeholder: «Busca artículos, fichas, eventos, fotos o ve a una sección…».
- **Ámbitos** (fila de botones `aria-pressed`, 28 px): **Todo · Artículos · Fichas · Páginas · Agenda · Medios**. Con 2 letras o más, cada uno muestra su recuento. «Fichas» junta los tres tipos.
- **Resultados**: lista con scroll. Cada grupo lleva título (12 px semibold `meta` + recuento) y sus filas.
- **Fila** (48 px):
  - pastilla de icono de 28 (en Medios, miniatura de 36×28 con `dominant_color` de fondo mientras carga);
  - título de 13.5/20 medium, con la coincidencia en `<mark>` (`acc-soft` + subrayado de 1 px `acc`, para no depender solo del color);
  - subtítulo de 12/16 `meta`;
  - a la derecha, chip de estado (se oculta en `< 640`) y `↵` en la fila activa.
- **Pie** (40 px, `side`): `↑↓ moverse · ↵ abrir · ⌘↵ en pestaña nueva`. En un ámbito, además: `⌫ volver a Todo`.

**Subtítulo y chip por tipo** (los estados usan los chips del design system):
| Tipo | Subtítulo | Chip |
| --- | --- | --- |
| Artículo | Categoría · fecha de publicación o «editado hace…» | Borrador / Programado / Publicado / Con cambios |
| Rocódromo | «Rocódromo» · distrito · «verificado 12 sept» | Publicada / Sin publicar / Sin verificar |
| Resolador | «Resolador» · distrito · plazo | ídem |
| Pie de gato | «Pie de gato» · marca · precio o «afiliado» | ídem |
| Página | `/slug` · «revisada…» | Publicada / Provisional |
| Evento | fecha · lugar · «del agente» si aplica | Por aprobar / Aprobado / Cancelado |
| Foto | alt entre comillas o «Sin texto alternativo» · «en uso en N sitios» | Sin alt (si falta) |

Cuando la coincidencia no está en el título, el subtítulo pasa a ser el fragmento, en cursiva: «en el texto: «…la cuota de La Paret incluye…»». Sin fragmento, basta con «coincide en el texto».

### 15.3 · Agrupación, orden y límites
- **Sin escribir**: **Recientes** (hasta 5), **Ir a** (todas las secciones, como hoy) y **Crear** (Nuevo artículo, rocódromo, evento, Subir fotos).
- **1 letra**: solo se filtran las secciones, en el cliente. No se busca contenido.
- **2 letras o más**:
  1. **Ir a** arriba, solo si el nombre de una sección *empieza* por lo escrito («med» → Medios). Máximo 3.
  2. **Grupos de contenido en orden fijo**: Artículos, Rocódromos, Resoladores, Pies de gato, Páginas, Agenda, Medios. El orden fijo crea memoria muscular. Los grupos vacíos no se muestran.
  3. **Ir a** al final, con el resto de secciones que contienen el texto.
- **Límite**: **4 por grupo en Todo** (7 grupos, 28 como máximo) y **20 en un ámbito**.
  - Si un grupo tiene más, su última fila es «Ver los 23 de Artículos», que cambia al ámbito dentro de la paleta, sin navegar.
  - En un ámbito con más de 20, la última fila es «Abrir «paret» en Artículos» → listado con `?q=`.
- **Orden dentro de un grupo** (lo calcula el servidor): título que empieza por el texto → título que lo contiene → otros campos (slug, entradilla, lugar, marca, alt) → cuerpo del artículo. A igualdad, el `updated_at` más reciente. En eventos, primero los próximos (por fecha ascendente) y luego los pasados.
- **Recientes**: los últimos 5 elementos abiertos en un editor o drawer (desde la paleta o no), en `localStorage` (`cg-admin-recent`: `{kind, id, title, openedAt}`). Si el elemento ya no existe, se quita. Nunca entran opiniones ni suscriptores. Se borra al cerrar sesión. No necesita backend.

### 15.4 · Qué abre cada resultado
| Resultado | Destino |
| --- | --- |
| Artículo | `/administrador/articulos/{id}` |
| Rocódromo / Resolador / Pie de gato | `/administrador/rocodromos/{id}` · `/resoladores/{id}` · `/pies-de-gato/{id}` |
| Página | `/administrador/paginas/{key}` |
| Evento | `/administrador/agenda?evento={id}`: abre su drawer (en la bandeja «Por aprobar» si es borrador) |
| Foto | `/administrador/medios?medio={id}`: abre el detalle |
| «Ver los N de X» | Cambia el ámbito dentro de la paleta |
| «Abrir «q» en X» | Listado de X con `?q=` |
| Ir a / Crear | Igual que hoy |
| «Crear un artículo titulado «q»» | `/administrador/articulos/nuevo?titulo=q` |

`⌘↵` o `Ctrl+↵` abren en una pestaña nueva (`window.open`). Intro cierra la paleta y navega. Las opciones son `role="option"`, no enlaces anidados.
**Para coneja-lucky**: hacen falta los enlaces directos `?evento=`, `?medio=` y `?titulo=`, y que los listados lean `?q=`.

### 15.5 · Teclado y foco
- El foco se queda en el input (patrón *combobox*: `role="combobox"`, `aria-controls`, `aria-activedescendant` a la opción activa). La lista es `role="listbox"` con `role="group"` y `aria-labelledby` por grupo.
- `↑/↓` mueven y dan la vuelta. Pasar el ratón por encima también activa la fila.
- `↵` abre; `⌘↵` / `Ctrl+↵`, en una pestaña nueva.
- `Esc`: si hay texto, lo borra; si no, cierra. El foco vuelve a donde estaba.
- `⌫` con el campo vacío dentro de un ámbito vuelve a Todo.
- `Tab` va a los ámbitos y vuelve al campo (trampa de foco del diálogo). `⌘K` abre y cierra.
- Al terminar cada búsqueda, una región `aria-live="polite"` anuncia «9 resultados» o «Nada coincide con…».

### 15.6 · Estados
- **Cargando**: «Ir a» aparece al momento porque se filtra en el cliente.
  - En la primera búsqueda, si tarda más de 150 ms, salen 3 filas esqueleto (barras planas) y un spinner de 16 en el campo.
  - Al seguir escribiendo, no se vacía nada: los resultados anteriores quedan al 55 % de opacidad con el spinner, y `aria-busy` está en la lista.
  - **Debounce** de 150 ms. Las respuestas que llegan tarde se descartan (id de petición o `AbortController`).
- **Sin resultados**:
  - «Nada coincide con «quickdraw»» y una línea con los campos donde se busca, para que se entienda por qué no aparece.
  - Si hay un ámbito activo, una fila «Buscar en todo».
  - Siempre, una fila «Crear un artículo titulado «quickdraw»».
- **Error**: aviso dentro de la lista (`danger-soft`, icono + texto + **Reintentar**, `role="alert"`): «No se ha podido buscar el contenido. Las secciones siguen funcionando». No lleva toast.
- **Sin escribir**: 15.3.

### 15.7 · Responsive
- **≥ 768**: diálogo de 640 centrado y anclado arriba.
- **< 768**: pantalla completa (`100dvh`, sin radio), que se abre desde la lupa de la barra superior.
  - Campo de 56 px con input de **16 px** (evita el zoom de iOS) y botón **Cancelar** de 44 px en lugar de `esc`.
  - Ámbitos de 36 px con scroll horizontal.
  - Filas de **56 px**, sin `↵` ni pie de atajos.
  - Los chips de estado se ocultan en `< 640`; el estado ya va en el subtítulo cuando importa (p. ej. «Sin texto alternativo»).
- Animación de entrada de 160 ms; con `prefers-reduced-motion`, ninguna.

### 15.8 · Para backend (jabali-javi → leona-lia): campos y contrato
Propuesta: **una sola RPC** `guide.admin_search(p_query text, p_kinds text[] default null, p_limit int default 4)`.
- **Devuelve** filas `kind, id, key, title, subtitle data (jsonb), status, matched_field, snippet, rank, total_in_kind`.
- **Límite por tipo** con `row_number() over (partition by kind …)`. `total_in_kind` con `count(*) over (partition by kind)`.
- **Solo admins**: `is_admin()`. Si es `SECURITY DEFINER`, con `search_path` fijo.
- **Validación**: `p_query` recortado a 2–100 caracteres; `%`, `_` y `\` escapados. `p_limit` acotado a 1–20.
- **Comparación** sin tildes ni mayúsculas, con el diccionario `extensions.unaccent` (ya en uso). La tolerancia a erratas con `pg_trgm` queda para después; decide jabali-javi.

| Tipo | Campos que se buscan | Además devuelve |
| --- | --- | --- |
| `article` | `title_es`, `title_en`, `slug_es`, `slug_en`, `excerpt_es`, `excerpt_en`. Cuerpo con `search_es` / `search_en` (tsvector existente), en el último rango. Opcional: el título del borrador pendiente en `content_drafts` | categoría, `status`, `published_at`, `updated_at`, si tiene cambios sin publicar. Fragmento con `ts_headline` si el acierto es en el cuerpo (opcional) |
| `gym` | `items.name`, `slug`, `summary_es/en` + `gyms.district`, `city`, `address`, `metro_stations` | `published`, `verified_at`, distrito |
| `resoler` | `items.name`, `slug`, `summary_es/en` + `resolers.district`, `city` | `published`, plazo min–máx |
| `shoe` | `items.name`, `slug`, `summary_es/en` + `shoes.brand`, `model` | `published`, marca, precio, `is_affiliate` |
| `page` | `title_es`, `title_en`, `slug_es`, `slug_en`, `key` (cuerpo no, en v1) | `published`, `revised_on` |
| `event` | `title_es`, `title_en`, `location_text` y el nombre de la ficha enlazada (`item_id`). Excluye `rejected` | `status`, `source`, `starts_at`, lugar |
| `media` | `original_filename`, `alt_es`, `alt_en`, `caption_es`, `caption_en`, `credit` (lo mismo que `search_media`) | `storage_path`, `dominant_color`, si falta alt, número de usos (`media_usage`) |

No se tocan `user_reviews`, `subscribers`, `user_profiles`, `admins` ni `activity_log`.

### 15.9 · Para coneja-lucky y loro-lola
- Reka: `ComboboxRoot` (o `ListboxRoot`) con `ignore-filter`, porque el filtrado de contenido lo hace el servidor. Las secciones se filtran en el cliente, como hoy.
- Composable `useAdminSearch(query, scope)` con debounce, descarte de respuestas atrasadas y caché en memoria de las últimas 10 consultas de la sesión.
- Copy nuevo o cambiado (loro-lola): placeholder, ámbitos, «Ver los N de X», «Abrir «q» en X», estados vacío, sin resultados y error, y «Crear un artículo titulado…». Se quita «La búsqueda de contenido llegará pronto».

### 15.10 · Dudas para Xavi (con recomendación)
1. **Opiniones.** **Recomiendo no buscarlas en v1**, por los datos del lector. Como alternativa sin datos personales: bajo cada ficha encontrada, una fila «Opiniones de La Paret de Gràcia (12)» → `/opiniones?ficha={id}`. Necesita el recuento por ficha y puede ir en v1.1.
2. **Buscar en el cuerpo de los artículos.** **Recomiendo sí**, en el último rango. El índice ya existe.
3. **Campos en inglés.** **Recomiendo sí**: cuesta poco y encuentra lo que tradujiste.
4. **Recientes por dispositivo** (`localStorage`) o sincronizados (tabla nueva). **Recomiendo por dispositivo.**
5. **«Crear un artículo titulado «q»» sin resultados.** **Recomiendo dejarlo**: solo abre un borrador nuevo con el título rellenado; no guarda nada hasta que escribes.

---

## 16 · Estadísticas (6.16) · propuesta

Mockup: `estadisticas.html`. Estados en el hash: `#datos`, `#personalizado` (1 mar – 15 jun 2026, por semana), `#sin-comparacion` (1 ene 2025 – hoy: el periodo anterior cae antes del corte de 24 meses), `#rango-error` (selector abierto con un «Desde» anterior al corte), `#vacio` (el estado real antes de lanzar: 0 suscriptores, 0 opiniones, 3 artículos de prueba, ninguna ficha publicada), `#cargando` y `#error`. El periodo y la agrupación funcionan en todos. Para verlo a 390 o 768: `anchos.html?solo=estadisticas.html%23datos&w=390`. Revisado en Chrome a 1440, 768 y 390.

Una sola dirección, dentro de D23 y con los patrones de Inicio v2 (§14): banda de KPIs, tarjetas `card` con `card-h`, estados vacíos de una fila y esqueleto plano. No hay rumbo que elegir. Xavi respondió 16.9 (ver 16.9): el rango personalizado y la comparación con el periodo anterior entran en v1, y están en 16.2, 16.3 y 16.10.

Nota: no hay una skill `dataviz` instalada en el repo ni en el usuario. Los gráficos siguen las prácticas habituales (escala honesta, etiquetas directas, sin doble eje, color con significado, tabla equivalente) y quedan explicadas abajo.

### 16.1 · Orden de la página
| Orden | Bloque | Por qué |
| --- | --- | --- |
| 1 | Título, periodo y agrupación | El periodo manda sobre todo lo de abajo; se lee en una línea bajo el título |
| 2 | KPIs (4): Suscriptores activos · Artículos publicados · Opiniones recibidas · Fichas publicadas | Respuesta rápida antes de mirar gráficos |
| 3 | **Suscriptores**, a ancho completo | Es el objetivo del producto (audiencia propia) y el único gráfico con dos lecturas |
| 4 | Artículos publicados · Opiniones (2 columnas en `≥ 1024`) | Ritmo editorial y respuesta de lectores |
| 5 | Fichas publicadas · Visitas por página | Fichas es un recuento por tipo, no una serie. Visitas, el hueco de D5 |

En `< 1024` todo se apila en ese orden. Las tarjetas llevan `items-start`: cada una a su altura.

### 16.2 · Periodo y agrupación
- Dos `seg` (radiogroup) a la derecha del título: **Periodo** `30 días | 12 meses | Personalizado` (rango personalizado en 16.10) y **Agrupar por**, que cambia según el periodo: con 30 días, `Día | Semana`; con 12 meses, `Semana | Mes`. Al cambiar de periodo, si la agrupación no vale, pasa a la de defecto (30 días → Día; 12 meses → Mes).
- Por defecto: **12 meses por mes** (ver 16.9).
- En la URL: `/administrador/estadisticas?periodo=30d|12m|personalizado&agrupar=dia|semana|mes`, y con el rango personalizado también `&desde=2026-03-01&hasta=2026-06-15`. Si el rango de la URL no es válido, se usa el de defecto, sin mensaje de error. Se puede compartir y volver con el botón atrás.
- Subtítulo con el rango exacto y la agrupación, en una línea, con `aria-live="polite"`: «Dic 2025 – nov 2026 · por mes · noviembre, en curso», «8 oct – 6 nov 2026 · por día».
- Las semanas empiezan en lunes. 12 meses por mes = 11 meses cerrados más el actual; por semana = 52 semanas que terminan en la actual. 30 días incluye hoy.
- **390**: cada control ocupa una fila a ancho completo. Primero el periodo (3 columnas), luego el botón del rango (solo con «Personalizado») y después la agrupación. Los botones miden 40 px de alto, y el del rango 44 px (regla común del panel en móvil).

### 16.3 · KPIs
Banda `grid-cols-2 lg:grid-cols-4`, igual que Inicio. **No son enlaces**: aquí se mira, no se navega (en Inicio sí lo son).
| KPI | Número | Línea de contexto | Comparación (16.11) |
| --- | --- | --- | --- |
| Suscriptores activos | Total al final del periodo | «+846 en 12 meses» (`ok` si > 0, `meta` si 0 o negativo) y debajo «904 altas · 58 bajas» | **Altas** del periodo |
| Artículos publicados | Publicados en el periodo + «en 12 meses» | «27 publicados en total» | Publicados |
| Opiniones recibidas | Visibles + ocultas en el periodo | «11 ocultas (7 %)» | Visibles + ocultas |
| Fichas publicadas | Total publicadas al final del periodo | «+19 en 12 meses · 3 tipos» | **Nuevas** del periodo |
Sin datos, el número va a 0 y la línea dice «Sin altas todavía» o «Ninguna todavía». Con el rango personalizado, el contexto dice «en el periodo» en vez de «en 12 meses». Si el rango termina antes de hoy, los dos totales (suscriptores y fichas) llevan «al 15 jun» junto al número, en `meta` 13 px.

### 16.4 · Gráficos: reglas comunes
- **SVG dibujado al ancho real** del contenedor (no `viewBox` escalado), para que el texto del eje siga a 11 px en cualquier ancho. Se redibuja al cambiar de ancho (`ResizeObserver`, sin animación).
- Ejes: JetBrains Mono 11 px `muted`. Rejilla `line`, base `line-strong`. Tres marcas en el eje Y (0, mitad y máximo «redondo»).
- **Etiquetas del eje X**: se aclaran hasta dejar ≥ 44 px entre ellas, contando desde el último periodo (el actual siempre lleva etiqueta). Por día, el mes solo aparece en la primera etiqueta y cuando cambia («9 oct», 11, 13… «2 nov»).
- **Color con significado**: `acc` es la serie que se mide. Las bajas, `muted`. Las ocultas, trama diagonal `st-hidden` (no solo color). Sin paletas categóricas.
- **Periodo en curso o recortado** (el mes actual, la semana actual, hoy, y la primera semana cuando el rango empieza a mitad): barra al 45 % con contorno discontinuo `acc`, y el último tramo de la línea discontinuo. Se explica en el pie («Periodo en curso o recortado») y en el detalle («en curso, hasta el 6»). Evita leer noviembre como una caída.
- **Detalle al pasar** (ratón), al tocar (móvil) o con el teclado: banda `subtle` sobre el periodo y una tarjeta flotante (`elev`, `shadow-pop`, 12 px) con el periodo completo y los valores con su muestra. Aparece en 120 ms; sin transición con `prefers-reduced-motion`. Se coloca a la derecha del punto y salta a la izquierda si no cabe.
- **Teclado**: cada gráfico es un `role="group"` con `tabindex="0"` y un `aria-label` que dice qué es, el rango y «Usa las flechas izquierda y derecha para recorrer cada mes». `←/→` mueven, `Inicio/Fin` van al primero y al último, `Esc` cierra. El valor se anuncia en una región `aria-live="polite"`. Foco `outline 2px acc`.
- **«Ver como tabla»** en el pie de cada tarjeta (`aria-pressed`): tabla con la misma serie, periodo en la primera columna, números alineados a la derecha y `tabular-nums`. Con más de ~12 filas, scroll vertical interno de 320 px y cabecera fija. Es la alternativa accesible completa y lo que se copia para un correo.
- Sin animación de entrada en los gráficos.

### 16.5 · Las tarjetas
- **Suscriptores** (ancho completo). Dos gráficos apilados que **comparten el eje X** y el detalle (pasar por uno resalta el mismo periodo en los dos):
  1. «Total de suscriptores activos»: línea de 2 px `acc`, con el último valor escrito al final («1.284»). **El eje Y no empieza en 0** cuando el total apenas se mueve (30 días: 1.200–1.300): se marca con el primer valor del eje y es lo esperable en una línea. Sin área rellena, que con base distinta de 0 engaña.
  2. «Altas y bajas»: barras divergentes con **la misma escala** hacia arriba (altas, `acc`) y hacia abajo (bajas, `muted`). Si las bajas son pocas se ven pequeñas: es lo honesto. No hay doble eje.
  Leyenda en la cabecera: Total activos · Altas · Bajas.
- **Artículos publicados**: barras `acc`. Con **30 días**, debajo, la lista de los publicados en el periodo (título enlazado al editor y fecha). Con **12 meses**, una línea: «Último: «…», 2 nov».
- **Opiniones**: barras apiladas, visibles (`acc`) abajo y ocultas (trama) encima, con contorno `st-hidden` de 1 px. Leyenda en la cabecera.
- **Fichas publicadas**: no es una serie. Una fila por tipo (Rocódromos, Resoladores, Pies de gato) con barra horizontal proporcional al total: la parte de antes del periodo en `line-strong` y las nuevas del periodo en `acc`. A la derecha, «24 +2» (`+n` en `ok` si > 0). Pie: «71 publicadas · 19 nuevas en los últimos 12 meses. Sin contar borradores ni importadas sin publicar».
- **Visitas por página**: chip `st-draft` «Sin conectar» con `plug` en la cabecera, y estado vacío de una fila: icono `chart-no-axes-column`, «Aún no medimos visitas» y «Cuando conectemos la analítica (sin cookies) verás aquí las páginas más vistas de este periodo. No hay datos anteriores: se empieza a contar desde ese día». No hay números, ni filas de ejemplo, ni un esqueleto que sugiera que llegan datos. Su diseño con datos se hace cuando se decida D5 (Cloudflare Web Analytics o `page_views`): la tabla depende de qué dé la herramienta.

### 16.6 · Estados
- **Vacío por tarjeta**: si toda la serie del periodo es 0, no se pinta el gráfico (ni ejes a 0). En su lugar, la fila vacía de Inicio (icono en pastilla `subtle` de 32, título 13 px medium y una línea `meta`):
  - Suscriptores: «Aún no hay suscriptores» · «Con la primera alta verás aquí el total y las altas y bajas de cada periodo. La newsletter se conecta con Brevo antes del lanzamiento» (la segunda frase se quita cuando haya proveedor).
  - Artículos: «Ningún artículo publicado en este periodo» · «Tienes N borradores. Ver borradores».
  - Opiniones: «Aún no hay opiniones» · «Cuando los lectores opinen sobre una ficha, verás aquí cuántas llegan y cuántas ocultas».
  - Fichas: «Aún no hay fichas publicadas» · «Las fichas importadas siguen en borrador hasta que las publicas. Ver importadas».
  Cada tarjeta decide sola: en `#vacio` Artículos sí tiene gráfico (3 de prueba) y el resto no.
- **Cargando**: esqueleto con la forma real (banda de 104 px, tarjeta de Suscriptores con 176 + 140 px y cuatro tarjetas de 168 px), **plano, sin brillo animado**. `role="status"` con «Cargando las estadísticas». Los controles de periodo siguen activos; «Exportar CSV» se desactiva.
- **Error**: una sola llamada (`admin_stats`), así que un solo bloque (`AdminStateBlock`, `role="alert"`): icono `circle-alert` en `danger-soft`, «No se han podido cargar las estadísticas», «Puede ser la conexión o el servidor. Tus datos no se han tocado. Vuelve a intentarlo; si sigue fallando, prueba en unos minutos» y **Reintentar** (`btn-ghost btn-sm`, 44 px en móvil). Si Visitas llega de otra fuente, su error queda dentro de su tarjeta.
- Al cambiar de periodo con datos ya pintados: los gráficos se quedan y se atenúan (`opacity .6`) hasta que llega la respuesta; sin esqueleto de nuevo. No está en el mockup.
- **Sin datos comparables** (`previous: null`): cada KPI dice «— Sin datos comparables» y la nota de debajo explica el motivo (16.11).
- **Rango no válido**: el error sale dentro del selector y no se aplica nada (16.10).

### 16.7 · Responsive
- **1440**: Suscriptores a ancho completo; debajo, rejilla de 2 columnas. Barras de 32 px como máximo (62 % del hueco).
- **768**: una columna (sidebar en iconos). Los gráficos usan el ancho y el eje X aclara etiquetas solo.
- **390**: KPIs en 2×2. Gráficos a ~320 px: con 12 meses salen etiquetas cada 2 meses; con 30 días por día, cada 4–5 días. Detalle al tocar una barra. «Ver como tabla» con 44 px de alto. **Exportar CSV no aparece en móvil** (es una tarea de escritorio, como Importar). Sin scroll horizontal.

### 16.8 · Para coneja-lucky y jabali-javi
- Página `pages/administrador/estadisticas.vue` y componentes en `components/admin/stats/` (`StatsKpis`, `StatsCard`, `StatsLineChart`, `StatsBarChart`, `StatsTable`, `StatsFichas`, `StatsVisitsEmpty`). SVG propio, como `dashboard/Signups.vue`: sin librería de gráficos (D7: gráficos ligeros).
- `useAdminStats(periodo, agrupar, desde, hasta)` lee y escribe la URL y llama a `admin_stats`. Componentes nuevos: `StatsRangePicker` (popover en escritorio, hoja en móvil) y `StatsDelta` (la línea de comparación de cada KPI). Las etiquetas de fecha en `Intl` `es-ES`, pero con separador de miles siempre (`1.284`: `es-ES` no agrupa 4 cifras por defecto).
- Activar «Estadísticas» en el menú y volver a mostrar el enlace en la tarjeta de altas de Inicio (§14.5 lo ocultó hasta 6.16).
- **Contrato que necesita la UI de `admin_stats`** (jabali-javi, en curso): por periodo y agrupación, una lista de periodos `{ bucket_start, bucket_end, partial, subs_in, subs_out, subs_total, articles_published, reviews_visible, reviews_hidden }`, y aparte `{ items_published: {gym, resoler, shoe}, items_new_in_range: {gym, resoler, shoe}, articles_published_total }`. `partial` = periodo en curso o recortado por el rango. `subs_total` = activos al final de cada periodo (no se puede reconstruir en el cliente sin el total inicial).
- **Ampliación del contrato (rango y comparación):** `admin_stats(p_from date, p_to date, p_grain)` con días completos de Madrid: desde `p_from 00:00 Europe/Madrid` hasta `p_to + 1 día 00:00 Europe/Madrid` (exclusivo). En la salida, `current_totals` y `previous`, los dos con `{ subs_in, subs_out, subs_total_end, articles_published, reviews_visible, reviews_hidden, items_new_in_range }`. El periodo anterior son **los mismos N días justo antes** de `p_from`. Si empieza antes del corte de 24 meses, `previous: null`. La API también rechaza un `p_from` anterior al corte, un `p_to` posterior a hoy, `p_from > p_to` y una agrupación no permitida (16.10). Los KPI salen de `current_totals`, no de sumar periodos en el cliente.
- La lista de artículos de 30 días (título, fecha, id) sale de una consulta simple a `articles`, como «Último publicado» en Inicio. Sin RPC nueva. Con el rango personalizado no se muestra la lista ni la línea «Último».
- Textos nuevos → loro-lola.

### 16.9 · Dudas para Xavi · respondidas

Respuestas de Xavi (6 nov 2026):
- 1: **12 meses por mes**, como se recomendaba.
- 3: **sí al CSV** de la vista actual.
- 4 y 5: **comparación y rango personalizado en v1**, en contra de la recomendación. Están en 16.10 y 16.11.
- Ajuste posterior: el rango llega como máximo a **24 meses atrás**, porque el registro se purga a los 24 meses. La comparación es con **los mismos días justo antes**.

Texto original de las dudas:
1. **Periodo por defecto.** **Recomiendo 12 meses por mes.** Inicio ya enseña los últimos 30 días; aquí se viene a ver la tendencia. Si la URL no trae parámetros, se usa la última elección, guardada en `localStorage` (`cg-admin-stats-range`).
2. **Qué KPI va primero.** **Recomiendo Suscriptores activos**, porque es el objetivo del proyecto (audiencia propia). Después artículos, opiniones y fichas. Alternativa: poner «Altas netas del periodo» como número grande y el total en la línea de contexto.
3. **Exportar.** **Recomiendo sí, en v1, un CSV de la vista actual**: solo recuentos por periodo, sin emails ni datos personales, así que no lleva aviso de datos personales (D37). Queda en Actividad como las demás exportaciones. Solo en escritorio. Si no lo necesitas, se quita y «Ver como tabla» basta para copiar.
4. **Comparar con el periodo anterior** (delta en los KPIs, «+12 % frente a los 12 meses anteriores»). **Recomiendo dejarlo para v1.1**: pide a `admin_stats` el doble de rango y, con meses de poco volumen, los porcentajes engañan.
5. **Rango personalizado** (desde–hasta). **Recomiendo que no en v1**: con dos rangos fijos se cubre el uso y no hay calendario que diseñar ni probar.

### 16.10 · Rango personalizado (v1)
- **Dónde**: tercera opción del `seg` de periodo, «Personalizado». Al pulsarla se abre el selector y el periodo **no cambia hasta «Aplicar»**. Si cancelas, se queda el que había. Con un rango aplicado aparece, entre el periodo y la agrupación, un botón `btn-ghost` con `calendar` y el rango («1 mar – 15 jun 2026»). Ese botón vuelve a abrir el selector (`aria-haspopup="dialog"`, `aria-expanded`). Al volver a «30 días» o «12 meses», el botón desaparece. El último rango se recuerda durante la sesión.
- **Selector** (`role="dialog"`, título «Rango personalizado»): en `≥ 768` es un popover de 360 px bajo los controles, alineado a la derecha (`elev`, `shadow-pop`, radio 10, aparece en 150 ms). Se cierra con Esc, con «Cancelar» o al hacer clic fuera, y el foco vuelve a quien lo abrió. En `< 768` es una hoja inferior con asa y velo. Ahí es modal: el tabulador da la vuelta dentro de la hoja, y «Cancelar» y «Aplicar» van a mitad de ancho y 44 px de alto.
- **Contenido**: «Desde» y «Hasta», dos `input type="date"` nativos en 2 columnas. Así el móvil usa su selector del sistema y el teclado funciona sin código propio. Llevan `min` (el corte) y `max` (hoy). Debajo va la ayuda «Días completos en hora de Madrid, del 7 nov 2024 a hoy (se guardan 24 meses)». Si el rango vale, un resumen vivo (`aria-live`) lo confirma: «9 ago – 6 nov 2026 · 90 días · agrupar por semana o mes». Al abrir por primera vez, el selector propone los últimos 90 días.
- **Hora de Madrid**: las fechas son días naturales de Madrid y los dos extremos están incluidos. «Hoy» es la fecha de Madrid, no la del navegador.
- **Límites**: «Hasta» no pasa de hoy. «Desde» no puede ser anterior al corte (**hoy − 24 meses + 1 día**, hoy el 7 nov 2024), porque el registro se purga a los 24 meses. Por eso el rango nunca pasa de 24 meses.
- **Errores** (al pulsar «Aplicar»; después, en vivo al editar). Van en una sola línea `.err` con `circle-alert`, bajo los dos campos, y el campo afectado lleva `aria-invalid` y el foco:
  - vacío: «Indica la fecha de inicio.» / «Indica la fecha de fin.»
  - futuro: «La fecha de fin no puede ser posterior a hoy (6 nov 2026).» (y lo mismo con la de inicio)
  - orden: «La fecha de inicio es posterior a la de fin. Cámbialas de orden.» (marca las dos)
  - corte: «Solo hay datos de los últimos 24 meses: empieza el 7 nov 2024 o después.»
  «Aplicar» nunca se desactiva: si se pulsa con un error, el error se explica.
- **Agrupación según la duración**: con **≤ 62 días**, Día o Semana; con más, Semana o Mes. Con un rango personalizado el `seg` muestra siempre `Día | Semana | Mes`, y la opción que no vale queda atenuada con `aria-disabled` y un texto oculto que da el motivo («no disponible: solo por día, hasta 62 días»). Sigue enfocable, para que el lector de pantalla lea por qué. Al aplicar se mantiene la agrupación si vale. Si no, se usa la de defecto: Día hasta 62 días, Semana hasta 183 y Mes a partir de ahí.
- **Subtítulo**: «1 mar – 15 jun 2026 · 107 días · por semana». Cuando el rango corta un mes o una semana, los periodos de los extremos son **recortados** y siguen la regla de 16.4: atenuados, con contorno discontinuo, y en el detalle «semana recortada por el periodo» o «recortado, del 1 al 15».
- **Barras** con muchos periodos (hasta 105 semanas): el ancho mínimo baja a 1 px y el eje X aclara las etiquetas solo. En 390 conviene agrupar por mes, pero no se fuerza.

### 16.11 · Comparación con el periodo anterior (v1)
- **Solo en los 4 KPI. Sin línea fantasma en los gráficos** (recomendación). Suscriptores ya cruza dos series y las barras divergentes. Una tercera serie en gris compite con el periodo en curso, que ya va discontinuo, y con semanas y meses recortados no se alinea periodo a periodo. Los KPI responden a «¿voy mejor o peor?» y el gráfico, a «¿cuándo?». Si Xavi lo echa de menos, la opción más sobria para v1.1 sería añadir el valor anterior en el detalle al pasar, no una serie.
- **Qué periodo**: los **mismos N días justo antes** del inicio, en todos los periodos. Con 12 meses por mes (1 dic 2025 – 6 nov 2026, 341 días), el anterior es 25 dic 2024 – 30 nov 2025. Debajo de la banda va una nota `xs meta` (`#cmpNote`, enlazada con `aria-describedby`): «Comparación con 14 nov 2025 – 28 feb 2026, los 107 días justo antes».
- **Línea de cada KPI** (`.delta`, 12/16, `meta`, 8 px bajo el contexto). Lleva un icono de 14 px, la cifra en `fg` semibold y después «frente a N en el periodo anterior». La frase es la misma en todos los periodos, porque el anterior no siempre mide «12 meses» exactos: el detalle va en la nota. En Suscriptores dice «altas» y en Fichas, «nuevas».
  - **Sube**: `arrow-up-right` en `ok` + «**+92 %** altas frente a 470 en el periodo anterior».
  - **Baja**: `arrow-down-right` en `meta` (no rojo: con poco volumen, una bajada no es una alarma) + «**−13 %** frente a 69…».
  - **Igual**: `equal` en `muted` + «**= 0 %** frente a…» o, con valores pequeños, «**= 7** igual que en el periodo anterior».
  - **No depende del color**: el signo (`+`, `−` con U+2212, `=`) y la dirección de la flecha llevan el significado. El icono es `aria-hidden` y el texto se lee completo.
  - **Pocos datos**: si el anterior es < 10, va la **diferencia absoluta** («**−1** frente a 9»), no el porcentaje: de 2 a 5 no es un «+150 %». A partir de 10, porcentaje entero (`> +999 %` como tope).
  - **Anterior = 0** y actual > 0: chip `st-acc` «Nuevo» + «0 altas en el periodo anterior». Sin porcentaje.
  - **Los dos en 0**: «= 0 también en el periodo anterior». Es el caso de `#vacio`.
  - **`previous: null`** (el periodo anterior empieza antes del corte de 24 meses): «— Sin datos comparables» en los 4 KPI. La nota explica: «Sin comparación: el periodo anterior empezaría el 26 feb 2023 y solo se guardan datos de los últimos 24 meses (desde el 7 nov 2024)». Con los rangos fijos no pasa: el anterior de 12 meses empieza a finales de 2024, dentro del corte.
- 390: la línea pasa a 2 o 3 renglones dentro de la tesela de la rejilla 2×2. No se trunca.

### 16.12 · CSV de la vista actual (v1)
- «Exportar CSV» (solo escritorio) baja **lo que se ve**: periodo, rango y agrupación. Nombre: `estadisticas_2026-03-01_2026-06-15_semana.csv` (fechas ISO en todos los periodos).
- Una fila por periodo: `periodo_inicio, periodo_fin, parcial, altas, bajas, suscriptores_total, articulos_publicados, opiniones_visibles, opiniones_ocultas`. UTF-8 con BOM y separador `;` para que Excel en español lo abra bien. Solo recuentos, sin emails (sin aviso D37). Se registra en Actividad.
- **No incluye columnas del periodo anterior.** `previous` son totales, no periodos, así que no hay un valor anterior por fila que poner. Repetirlo en cada fila confundiría, y mezclar una fila de totales rompe el formato tabular. La comparación vive en los KPI y en la nota con las fechas. Si hiciera falta, la v1.1 sería un segundo CSV de resumen (`métrica, actual, anterior, diferencia`).

---

## 17 · Autor del sitio y Autores (D51, D57, D60) · propuesta

Mockup: `ajustes-autores.html`. Tiene dos vistas en el mismo archivo y los estados van en el hash.
- **Ajustes**: `#autor`, `#autor-vacio` (estado real hoy, D46), `#autor-foto`, `#autor-error` y `#autor-conflicto`.
- **Autores**: `#autores`, `#autores-vacio`, `#autores-cargando`, `#autores-error`, `#autor-nuevo`, `#autor-editar`, `#autor-borrar` (Ana, 12 artículos) y `#autor-borrar-sin` (sin artículos).

Revisado a 1440 y en `anchos.html` a 768 y 390. «Laia Ferrer» es un autor de ejemplo, marcado así en la lista.

### 17.1 · Dónde va cada cosa (recomendación)

| Opción | Cómo | A favor | En contra |
| --- | --- | --- | --- |
| **A · Todo en Ajustes** | Sección «Autor del sitio» y, debajo, «Autores» con su lista | Un solo sitio para todo lo que firma | Mezcla dos formas de guardar: Ajustes guarda en bloque con la barra de cambios y `admin_update_settings`, y cada autor se guarda por fila en el drawer. Ordenar y borrar dentro de una página de formularios queda raro. Ajustes está pensada para tocarse poco |
| **B · Autor en Ajustes y Autores en Editorial (recomendada)** | «Autor del sitio» es una sección de Ajustes. «Autores» es una pantalla propia en Editorial, debajo de Categorías, y muestra arriba al autor del sitio fijo con «Editar en Ajustes» | Cada pantalla tiene un solo modelo de guardado. Usa el mismo patrón que Categorías (lista ordenable + drawer + borrar con aviso). Queda junto a Artículos, que es donde se usa | Lo que firma vive en dos pantallas. Lo compensan los enlaces cruzados: «Otros autores →» en Ajustes y la fila fija del autor del sitio en Autores |

El autor del sitio no pasa a `guide.authors`. Sigue en `site_settings` porque además alimenta «Sobre mí» (frase, «En números»). En el selector del editor sale como «Autor del sitio (Xavi)», como ya hace `Inspector.vue`.

### 17.2 · Ajustes → «Autor del sitio» (`site_settings`)

- Va **después de General** en el submenú. Se guarda con la barra flotante de Ajustes (`admin_update_settings(p_changes, p_base)`), con marca «Sin guardar» por campo.
- **Foto** (`author_photo_media_id`): miniatura 4:5 de 96 × 120, «Elegir de Medios…», «Cambiar…» y «Quitar». Debajo va siempre el aviso que pidió leona-lia: *«Al guardar, la foto pasa a ser pública: sale en "Sobre mí" y en tu firma, aunque no esté en ningún artículo. Al quitarla, vuelve a ser privada si no se usa en otro sitio.»* Sin foto, el texto explica qué pasa en el sitio. Elegir o quitar la foto cuenta como un cambio sin guardar y se aplica al guardar.
- **Nombre** (≤ 80). **Rol** ES/EN (≤ 80). **Frase de «Sobre mí»** ES/EN (`author_lede_*`, ≤ 120): es el H1 de la página. **Bio corta** ES/EN (≤ 160): va en la firma del final del artículo. Todos los campos llevan contador; avisa al 90 % y marca error por encima del límite.
- **«En números»** (`author_stats`): un `fieldset` con hasta **2 filas**: cifra (≤ 24, mono), etiqueta ES (≤ 60) y etiqueta EN (≤ 60, opcional), más «Quitar» (44 px en móvil) con toast «Deshacer». «Añadir cifra» se desactiva con 2 filas y lo explica al lado. Debajo, las 2 cifras calculadas (rocódromos con ficha, pies de gato comparados) en solo lectura, con borde discontinuo.
  - Validación en el cliente, igual que `guide.author_stats_valid`: la cifra y la etiqueta ES son obligatorias en cada fila (1 a 24 y 1 a 60 tras `trim`). Una fila vacía de golpe se descarta al guardar, no da error. `label_en` vacío no se envía; leona-lia pidió tratarlo como ausente.
- **Vista previa** «Así se ve»: segmentado Firma / Sobre mí y ES / EN. Es aproximada. En «Sobre mí», con menos de 2 cifras la fila de números no se pinta (§13.8 del sitio).
- **Estados**: vacío (D46: banner informativo, sin barra); error (campo con borde, icono y texto; el toast de Guardar dice cuántos errores hay y lleva «Ir al primero»); conflicto (`p_base` detecta que otra pestaña cambió una columna: banner con «Ver la otra versión» / «Guardar la mía»; no se guarda nada de la sección hasta decidir); éxito (toast).
- **Tu cuenta**: se quita «Contraseña cambiada hace…» (D60). La fila «Contraseña» se queda solo con «Cambiar…». También aplicado en `ajustes.html`.

### 17.3 · Selector de foto (`MediaPicker`, modal `lg`; hoja en móvil)

- Buscador, filtro Todas / Verticales y rejilla de 5 columnas (3 en móvil) que respeta el formato de cada foto. Es un `radiogroup` y la elegida lleva un anillo de 2 px y un check.
- **Alt obligatorio** (`alt_es` y `alt_en`): las fotos sin alt completo salen atenuadas, con chip «Sin alt», «Falta alt EN» o «Falta alt ES», y `aria-disabled` + `aria-describedby` con la explicación. Al pulsarlas no se eligen: sale un toast con «Ir a Medios». La explicación y el enlace «Complétalo en Medios» van bajo la rejilla.
- Banner fijo: *«La foto que elijas será pública al guardar, aunque hoy no salga en ninguna página.»*
- Pie: «Subir en Medios» (enlace, a la izquierda), «Cancelar» y «Usar esta foto». Es el mismo componente desde Ajustes y desde el drawer de autor; solo cambia el subtítulo.

### 17.4 · Editorial → Autores (`guide.authors`)

- **Menú**: «Autores» (icono `users-round`) en Editorial, debajo de Categorías. Ruta `/administrador/autores`. El mockup lo inyecta con JS; hay que añadirlo a `assets/admin.js` y al `AdminSidebar` al aprobarse.
- **Cabecera**: «Autores N» (cuenta también al autor del sitio) y «Nuevo autor» (en móvil, «Nuevo»).
- **Autor del sitio**: tarjeta fija arriba, que no se ordena ni se borra. Lleva foto, nombre, chip «Por defecto», rol, artículos con `author_id` nulo, chip EN y «Editar en Ajustes ↗» (enlace a `ajustes#autor`).
- **Otros autores**: lista ordenable, como en Categorías (`sort_order`): asa, avatar de 40 (foto o inicial sobre `subtle`), nombre y rol (la fila entera abre el drawer), «N artículos» o «Sin artículos», chip EN y lápiz. Al soltar: toast «Orden guardado» con «Deshacer». Teclado: Espacio, flechas y Escape. El orden sirve para el selector «Autor» del editor.
- **Chip EN** según `has_en` (rol y bio en inglés): `lang-ok` si están los dos, `lang-part` si falta uno y `lang-miss` si no hay ninguno.
- **Lateral (xl)** «Cómo funciona la firma»: dónde se asigna, qué es EN completo y qué pasa al eliminar. En < 1280 baja debajo de la lista.
- **Estados**: cargando (esqueleto de 2 filas), vacío («Solo firmas tú» + «Nuevo autor»; la tarjeta del autor del sitio sigue arriba) y error (código + «Reintentar»).

### 17.5 · Drawer de autor (440 px; hoja en < 768)

- **Foto** circular de 64 con «Elegir de Medios…» / «Cambiar…» y «Quitar», y el aviso de que será pública al guardar. Sin foto, se pinta la inicial y la firma sale sin círculo.
- **Nombre*** (≤ 80; error «Escribe el nombre con el que firma»). **Identificador** (`slug`): se rellena con el nombre solo al crear; en mono; texto de ayuda «no es una URL pública». Si choca con `authors_slug_key`, banner de error con enlace al campo.
- **Rol** ES/EN (≤ 80) y **Bio** ES/EN (≤ 160) con contador. Debajo, el estado EN en vivo: completo, a medias (qué falta) o sin inglés.
- **«Así firma»**: vista previa de la firma completa.
- **«Dónde firma»** (solo al editar): «12 artículos · 12 publicados» y «Ver en Artículos». Necesita un filtro `?autor=` en Artículos (coneja-lucky).
- **Pie**: «Eliminar…» (solo al editar), «Cancelar» y «Guardar» / «Crear autor». Se guarda al momento, sin borrador, como Categorías. Si hay cambios y se cierra con Esc o con el scrim, se pregunta «¿Descartar cambios?».

### 17.6 · Eliminar autor (`alertdialog`; hoja en móvil)

- **Con artículos**: «Firma **12 artículos (12 publicados)**. Pasarán a firmarlos **Xavi**, el autor del sitio». Debajo, los 3 primeros títulos con su estado y «y 9 más». Banner de aviso: en los publicados la firma cambia al momento, sin «Publicar cambios» (la exención `detach_author` de D57). Los borradores también pasan a Xavi y no hay deshacer en bloque. Si tiene foto, se dice que se queda en Medios. El botón dice lo que hace: **«Eliminar y pasar 12 artículos a Xavi»**. El foco empieza en «Cancelar».
- **Sin artículos**: texto corto y «Eliminar».
- Después: toast sin «Deshacer» («Ana eliminado · 12 artículos firmados ahora por Xavi») y anuncio por `aria-live`. Queda registrado en Actividad (trigger `log_activity`).
- Los recuentos salen de `articles` por `author_id` (total y vivos con `article_is_live`). Se piden al abrir el diálogo, no se calculan en el cliente.

### 17.7 · Responsive y accesibilidad

- 1440: Ajustes en una columna de 760 con submenú; Autores con lista de 760 y lateral de 320. 768: sin submenú ni lateral, y el drawer encima. 390: drawer, diálogo y selector como hoja; filas de cifra en 2 columnas (cifra + quitar, y debajo las etiquetas); botones y filas ≥ 44 px; sin scroll horizontal.
- Labels visibles, `lang-tag` en cada par ES/EN y contadores fuera del label accesible. Errores con icono + texto + `aria-invalid` / `aria-describedby`. Foco atrapado en drawer y modales, y devuelto al disparador al cerrar. Animaciones de 150–200 ms, sin ellas con `prefers-reduced-motion`.

### 17.8 · Para backend y frontend

- **jabali-javi**: ningún cambio de schema. Hace falta una lectura de recuentos por autor (`count` total y vivos), que puede ser una vista `security_invoker` o el `select` con agregado de PostgREST. Opcional: una RPC `admin_reorder_authors(ids uuid[])` para guardar el orden en una sola transacción, como en Categorías.
- **coneja-lucky**: ruta `autores.vue` (componentes en `components/admin/authors/`; prefijo de carpeta, ver la memoria del proyecto), sección `AdminSettingsAuthor` en Ajustes, `MediaPicker` con filtro de alt completo y prop de subtítulo, filtro `?autor=` en Artículos y enlace «Gestionar autores» al final del selector «Autor» del editor.
- **loro-lola**: todos los textos nuevos (es). El panel es solo español.

### 17.9 · Preguntas para Xavi (con recomendación)

1. **¿Opción B (Autores en Editorial, Autor del sitio en Ajustes)?** Recomiendo B: un solo modelo de guardado por pantalla y el mismo patrón que Categorías.
2. **`is_primary`**: la columna existe, pero hoy nada la usa, porque el autor por defecto es `author_id` nulo, es decir, tú. **Recomiendo no mostrarla** hasta que tenga un uso. Si la quieres, el uso razonable sería «autor por defecto en artículos nuevos» (p. ej. si Ana escribe la mayoría), con un interruptor en el drawer y como máximo uno activo.
3. **Orden de autores**: solo se ve en el selector del editor. ¿Lo mantenemos ordenable o basta con el orden alfabético? Recomiendo mantenerlo: cuesta poco y reutiliza Categorías.
4. **Página pública por autor** (`/autores/ana`): hoy no existe y el slug solo sirve para los datos estructurados. ¿Más adelante? Recomiendo esperar a que haya más de un autor con volumen.
5. **Borrar con artículos publicados**: hoy pasan a ti al momento. ¿Prefieres que se pida antes reasignarlos a otro autor (como al borrar una categoría)? Recomiendo dejarlo como está, con el aviso: con 1–2 autores, pasar a ti es casi siempre lo que quieres.
6. **Foto del autor del sitio**: ¿siempre vertical 4:5 (la de «Sobre mí»), o una cuadrada aparte para la firma? Recomiendo una sola foto 4:5, que la firma recorta en círculo centrado arriba.

---

## 18 · Suscriptores: consentimiento de afines (D66) · propuesta (pendiente de Xavi)

Mockup: `suscriptores-afines.html` (copia de `suscriptores.html` con lo de D66; el original no cambia). Estados nuevos con hash: `#ficha` (afines dados), `#ficha-afines-pendiente`, `#ficha-afines-retirado` y `#retirar-afines`; el resto, como §11. Verificado en Chrome headless a 1440, 768 y 390: sin scroll horizontal y sin texto por debajo de AA. Amplía §11, no la sustituye. Datos: `admin_list_subscribers` (`related_*` por fila y `related_counts`), `admin_get_subscriber` (`related_*`, eventos con `purpose`, `related_consent_texts`) y `admin_withdraw_related(p_id, p_reason)`.

### 18.1 · Modelo

| BD (`related_status`) | Etiqueta | Token · icono |
| --- | --- | --- |
| `none` | — (`muted`, `aria-label` «Sin dar») | — |
| `pending` | Pendiente | `st-warn` · `clock` |
| `granted` | Dado | `st-pub` · punto |
| `withdrawn` | Retirado | `st-neutral` · `megaphone-off` |

- **Orígenes nuevos** (`related_consent_source`): Página de newsletter · Preferencias · Lista de espera de Chalk app; el resto, como §11.1.
- **Vía de retirada** (`related_withdraw_source`): Enlace del email · Desde sus preferencias · Proveedor de email · Desde su cuenta · Desde el panel. `erase` no se ve: las filas suprimidas no se listan.
- **Regla 8, otra vez:** la cuenta no da afines. La ficha lo dice cuando está en `none`.
- **Sin alta ni reactivación desde el panel**, igual que la newsletter: no hay «Dar afines».

### 18.2 · Listado

- **Columna «Afines»** al final de todas las vistas, antes de ⋯. El encabezado es un `abbr` con el título «Avisos de Chalk app y productos afines». La celda muestra la etiqueta de 18.1. La tabla mantiene `min-w-[940px]` con scroll dentro de su contenedor.
- **Tarjetas (< 768):** si no es `none`, se añade «Afines» + la etiqueta en la línea de datos.
- **Filtro «Afines»** en la barra (icono `megaphone`): casillas Dado · Pendiente · Retirado · Sin dar, con recuento de `related_counts`. Va en la URL como `afines=dado,pendiente…`.
- **Resumen:** la celda Activos añade «· N con afines» (de `related_counts.granted`). No hay celda nueva.
- **Menú de fila:** «Retirar afines…» (`megaphone-off`) tras «Dar de baja…», solo con `granted` o `pending`. **Sin lote:** la RPC es de uno en uno.

### 18.3 · Ficha

- **Sección nueva «Avisos de Chalk app y productos afines»** entre la prueba de la newsletter y el historial, con la etiqueta de estado al lado del título y la misma caja `proof`:
  - **Cuándo** (hora de Barcelona) · **Desde dónde** (origen; con Preferencias: «con el enlace de sus emails, sin login») · **Texto aceptado** («Versión 1 · ES» + «Ver el texto exacto» de `related_consent_texts`) · **Estado** («Vigente desde {fecha} · con el doble opt-in / desde sus preferencias» o «Pendiente: se activa si confirma el email; si caduca, se descarta») · **Retirada** (fecha + vía + motivo, o —).
  - Con `withdrawn`: `banner-info` «No recibe avisos afines. Solo esta persona puede volver a darlos, desde sus preferencias» (+ «La newsletter sigue activa» si lo está).
  - Con `none`: una línea «No los ha dado» + por dónde puede darlos (y que iniciar sesión no cuenta). Sin caja.
  - Pie: «Independiente de la newsletter: dar de baja no la retira, y retirarla no da de baja».
- **Historial:** una sola línea de tiempo con las dos finalidades, en orden cronológico. Los eventos de afines llevan delante la etiqueta «Afines» (`acc-soft`, 11 px). Eventos: Marcó la casilla de afines (texto vN) · Dio los avisos afines (al confirmar el email / desde Preferencias) · Retiró los avisos afines (vía, motivo) · Se descartó (caducó sin confirmar). «Copiar como texto» añade el bloque de afines.
- **Pie del drawer:** «Dar de baja…» · **«Retirar afines…»** (fantasma, solo con `granted`/`pending`) · «Suprimir datos…» a la derecha. La línea de ayuda dice que la baja y la retirada son independientes y no se deshacen desde el panel.

### 18.4 · Retirar afines (`#retirar-afines`): patrón de la baja (§11.4, D35)

- `alertdialog` con foco en **Cancelar**. Título «¿Retirar los avisos afines de {email}?». Texto: «Dejará de recibir avisos de Chalk app y productos afines. **La newsletter no cambia.** **Desde el panel no se puede deshacer:** solo esa persona puede volver a darlos, desde sus preferencias».
- **Motivo obligatorio** (radios → `p_reason`): Me lo pidió (email, mensaje o en persona) `request` · Email erróneo o de prueba `wrong` · Lo marcó alguien que no era esa persona `abuse` · Otro `other`. Botón desactivado hasta elegir.
- Nota: «Queda en su historial como "Afines · retirado desde el panel" con la fecha y el motivo. La prueba de que los dio se conserva».
- `btn-danger` «Retirar afines» con `aria-busy` («Retirando…»). Sin escribir el email: no borra datos.
- **Toast sin Deshacer:** «Afines retirados a {email} · la newsletter no cambia». La ficha se queda abierta y refleja el nuevo estado. Error 22023 (ya retirado): toast «Ya no tenía afines vigentes» y recarga de la ficha. Otro error: toast persistente con Reintentar.
- En hoja (< 768), botones a ancho completo, como §11.7.

### 18.5 · Para backend y frontend

1. **jabali-javi:** `admin_list_subscribers` necesita `p_related guide.related_consent_status[]` para el filtro «Afines» (hoy no existe). `export_subscribers` debería incluir `related_status` y `related_consent_at` (6.15). leona-lia revisa.
2. **coneja-lucky:** `AdminStatusChip` con los tres tipos de 18.1; la columna, el filtro, la sección de la ficha, la etiqueta de finalidad en el historial y el diálogo (reutiliza el de la baja con otra configuración).
3. **loro-lola:** textos nuevos del panel (solo es).

### 18.6 · Preguntas para Xavi

1. **Columna siempre visible** o solo en Activos y Todos. **Recomiendo siempre:** una baja con afines `granted` sigue recibiendo avisos, y en Bajas es justo donde más importa verlo.
2. **Historial único con etiqueta** o dos historiales separados. **Recomiendo único:** el orden real de los hechos es la prueba.

---

## 19 · F8: Noticias, Newsletter semanal, Ingesta y ajuste de Agenda (D70–D76, tarea 8.2) · propuesta (pendiente de Xavi)

Mockups: [`noticias.html`](noticias.html) (`#lote`, `#editar`, `#publicadas`, `#categorias`; estados en el selector), [`newsletter.html`](newsletter.html) (`#scheduled`, `#sending`, `#sent`, `#nobrevo`, `#empty`, `#aprobar`, `#historial`), [`ingesta.html`](ingesta.html) (`#alerta`, `#fuentes`, `#tokens`, `#token-creado`) y [`agenda-f8.html`](agenda-f8.html). La vista previa de la carta carga la plantilla real: [`../site/pages/email-newsletter.html`](../site/pages/email-newsletter.html). Revisados en Chrome headless a 1440 y en iframe de 390: sin scroll horizontal de página (solo pestañas, filtros y tablas dentro de su contenedor).

No hay direcciones alternativas: es la dirección A «Consola» (D23) con patrones ya aprobados. Noticias usa la bandeja de Agenda (§9.3) y la tabla de Artículos. Newsletter usa el editor con vista previa y los diálogos de confirmación. Ingesta usa la tabla con fila desplegable y los modales de Exportar. En cada pantalla se descartó una opción, que va anotada.

### 19.1 · Menú y rutas

| Ruta | Grupo del menú | Contador |
| --- | --- | --- |
| `/administrador/noticias?vista=revisar\|publicadas\|rechazadas\|todas&categoria=&alcance=&fuente=&recogida=&q=` | Editorial, tras Artículos | `count` naranja = borradores por revisar |
| `/administrador/newsletter` (`?vista=historial`) | Comunidad, tras Suscriptores | ninguno; punto naranja si hay borrador listo sin aprobar |
| `/administrador/ingesta` (`#fuentes`, `#tokens`) | Datos, tras Actividad | punto rojo si la salud falla |

- **Inicio (§14, «Pendiente»)** suma tres tareas: «N noticias por revisar», «Carta de la semana lista para aprobar» y «Sin recogida correcta desde hace N días» (`st-danger`, primera de la lista).
- **Nuevo** gana «Noticia» (atajo N).
- **⌘K** busca también en noticias.
- `sparkles` sigue reservado para «viene del agente». Para la sección Ingesta se usa `bot`.
- **Una palabra por concepto.** En la interfaz, cada ejecución se llama **recogida**; «run» queda para el código y `ingest_runs`. `dry_run` se muestra tal cual y con la explicación «no escribe».

### 19.2 · Noticias (`noticias.html`)

**Modelo que asume** (`guide.news`, 8.5). Estados:

- `draft`: «Por revisar», `st-warn`, `circle-dashed`.
- `published`: «Publicada», `st-pub`.
- `rejected`: «Rechazada», `st-hidden`.

El origen (agente o manual) va en un chip aparte, igual que en Agenda. Regla 6 y D74: nada del agente se publica sin una acción de Xavi.

**Cabecera:**

- Chip de la regla D73: «Sin “Nota de Xavi”, la ficha va con noindex».
- Botones Categorías (drawer), Exportar (modal D37) y **Nueva noticia**.
- Debajo, una franja `side` con la última recogida, cuántas noticias nuevas y duplicadas trajo, la próxima recogida y el enlace a Ingesta. Si la salud falla, la franja pasa a `banner-err`.

**Vistas y barra:**

- Vistas: Por revisar (`count`), Publicadas, Rechazadas y Todas. Si hay borradores, se abre en Por revisar.
- Filtros:
  - Búsqueda (`/`), en título, resumen y fuente.
  - **Categoría**: menú de casillas con recuento.
  - **Alcance**: segmentado Todo / Cataluña / España / Intl.
  - **Fuente**: casillas, con el enlace «Gestionar fuentes» a Ingesta.
  - **Recogida**: las de los últimos 30 días.
- Fichas de filtros activos, y todo el estado en la URL.

**Bandeja «Por revisar»** (lista de 420 px + detalle desde 1024; por debajo, lista sola y detalle en hoja):

- **Fila:**
  - Casilla.
  - Título (2 líneas).
  - «Fuente: X · fecha de la fuente · categoría».
  - Chips: Agente, alcance, confianza (5 segmentos con texto sr-only), avisos y `EN`.
- **Avisos** (`st-warn` con `triangle-alert`):
  - «Confianza baja» (< 0,65).
  - «Parecido alto · N %» (≥ 35 %, ver 19.6).
  - «Posible duplicado».
- Orden: lo más reciente de la fuente arriba.
- **Detalle, en este orden:**
  1. Chips de estado, origen, alcance y categoría.
  2. Título y «Recogida del … · recogida #N» (enlaza a Ingesta).
  3. **Fuente**, siempre arriba y nunca plegada:
     - Medio.
     - URL completa (`break-all`).
     - Fecha de publicación de la fuente.
     - Idioma de la fuente.
     - Tasa de aprobación de esa fuente.
     - Botón «Abrir ↗», con el texto sr-only «se abre en otra pestaña».
  4. **Resumen** ES con contador `/600`, y medidor de **parecido con la fuente** (verde < 35 %, ámbar a partir de 35 %). El inglés va en un `details`.
  5. **Indexación:** sin nota, `banner-info` «Sin nota: la ficha sale con noindex» con el botón «Añadir nota», que abre el editor con el foco en la nota.
  6. **Qué encontró el agente:**
     - Confianza 0–1.
     - Nota.
     - Campos deducidos (`sparkles deducido`).
     - Imagen propuesta y licencia, o «ninguna».
     - Cita literal (`lang` de la fuente), con la aclaración «solo para verificar; nunca se publica».
  7. **Así sale en /noticias:** vista previa ES/EN de la fila del sitio con la marca «Resumen de ChalkGuide · Fuente: X». Debajo, el impacto: «sale en menos de 10 minutos y entra en el borrador de la carta de esta semana».
- **Acciones** (pie fijo del detalle):
  - **Rechazar ▾** (`D`), que abre un menú de motivos: Duplicada · No es de escalada · Fuera de alcance · Poco relevante · Datos incorrectos · Fuente poco fiable · Sin motivo. Al elegir, rechaza al momento con el toast «Rechazada · el agente no la volverá a proponer» y Deshacer.
  - **Editar** (`E`).
  - **Aprobar** (`A`, primaria).
  - Después de cada acción, el foco pasa a la siguiente. J/K para moverse.
  - En la lista (< 1024): Aprobar, Editar y × de 44.
- **Lote:**
  - Casillas, «Seleccionar todas» y barra flotante con `aria-live` «N seleccionadas · Aprobar · Rechazar… · ×».
  - Si ninguna seleccionada tiene avisos, **Aprobar en lote** publica al momento con Deshacer.
  - Si alguna tiene avisos, abre un diálogo con la lista de avisos y tres salidas: Cancelar · Aprobar las N · **Aprobar las M sin avisos** (primaria). Así se puede aprobar rápido sin publicar a ciegas lo dudoso.
  - **Descartado:** aprobar en lote siempre sin diálogo. Con 40 borradores por recogida, el diálogo solo aparece cuando aporta algo.
- **Vacío (al día):** «Nada por revisar» y la fecha de la próxima recogida, sin acción primaria.

**Publicadas y Todas** (`AdminDataTable`):

- Columnas:
  - Casilla.
  - Publicada (descendente).
  - Noticia (título y «Fuente: X» debajo).
  - Categoría (≥ 1024).
  - Alcance (≥ 1024).
  - **Indexación**: «Con nota · indexable» (`st-pub`) o «noindex» (`st-neutral`).
  - Origen (≥ 1280).
  - EN.
  - ⋯
- Una franja resume «86 publicadas · 12 con nota · 74 con noindex».
- Menú de fila: Editar · Ver en el sitio · Abrir la fuente · **Retirar** (vuelve a borrador; `alertdialog` sin peligro) · Eliminar… (solo manuales; si vino del agente, ofrece «Rechazar en su lugar», como en §9.6).
- < 768: tarjetas.

**Editor** (drawer de 640, hoja en < 768; autoguardado con «Guardado · hace N s», sin borrador de cambios porque es una entidad pequeña, como los eventos):

| Campo | Regla |
| --- | --- |
| Banner del agente | Solo en borradores del agente: fecha y qué significa «deducido» |
| Texto ES / EN | Pestañas locales con punto ámbar si el EN está incompleto. **Título** ES * 140. **Resumen propio** ES * 600, con medidor y la ayuda «Con tus palabras: nunca frases copiadas de la fuente», más el parecido en vivo. **Nota de Xavi** (opcional, 600): debajo, el chip `noindex` que pasa a «indexable» (`st-pub`) en cuanto la nota tiene texto. EN: título y resumen van juntos; uno sin el otro da error en línea («sin los dos, no sale en /en/news») |
| Fuente * | **Medio** (nombre corto, «Fuente: FEEC»), **Publicada el** (fecha) y **Enlace a la noticia original** (afijo `https://`). No se puede vaciar. Al cambiar el enlace de una publicada, se avisa: el agente lo usa para deduplicar |
| Clasificación | **Categoría** * (select de `news_categories`) y **Alcance** * (segmentado de 3), los dos con «deducido». **Etiquetas** internas (búsqueda y carta; no salen en el sitio en v1). URL `/noticias/` con slug, con la regla de slug de 4.2 (fija al publicar) |
| Imagen | Radio en tarjeta: **Sin imagen** (por defecto) / **De Medios, con licencia**. La segunda pide licencia * (Propia · Cedida con permiso · CC BY 4.0 · CC BY-SA 4.0 · CC0) y crédito *, y el alt ES obligatorio de Medios (D27). Sin licencia y crédito no se publica con imagen. Nunca se enlaza la imagen de la fuente |
| Lo que leyó el agente | Plegado, de solo lectura: cita y confianza |

Pie: Rechazar… · Guardar (sigue por revisar) · **Guardar y publicar**. En una publicada: Retirar… · Cancelar · **Guardar**. Los errores al publicar siguen el patrón `banner-err` con enlaces a cada campo.

**Categorías de noticias** (drawer): lista ordenable con nombre ES y EN y recuento. Son distintas de las del blog. Borrar una categoría con noticias pide reasignarlas (patrón de Categorías). Los nombres son provisionales hasta 8.3 (loro-lola).

**Descartado:** editor a página completa como el de artículos. Una noticia tiene 6 campos y se edita en mitad de la cola. El drawer mantiene el contexto y el foco vuelve a la fila.

### 19.3 · Newsletter (`newsletter.html`)

**Estados (`newsletter_issues.status`) y chips:**

| Estado | Chip |
| --- | --- |
| `draft` | Borrador (`st-draft`) |
| `scheduled` | Programada (`st-sched`, `clock`) |
| `sending` | Enviando (`st-acc`, spinner) |
| `sent` | Enviada (`st-pub`) |
| `cancelled` | Cancelada (`st-hidden`) |
| `failed` | Fallida · parcial (`st-danger`) |

**Vistas:** Esta semana / Historial.

**Esta semana:**

- **Barra de la carta:**
  - «Semana 47 · 16–22 nov», el chip de estado y «Compuesta por el agente el lun …».
  - El autoguardado, o quién aprobó y cuándo.
  - Acciones: Vista previa (solo < 1280), **Enviarme una prueba** (al email del admin; toast) y **Aprobar y programar** (primaria).
- **Editor** (columna izquierda) y **vista previa** (columna de 652 px, `sticky`, desde 1280):
  - **Versión:** pestañas Español · N / Inglés · N, con punto ámbar si está incompleta, y la ayuda «Dos campañas: cada suscriptor recibe la de su idioma».
  - **Asunto** * (80; ideal 30–55, con medidor).
  - **Preheader** (110).
  - **Introducción** (600), con «la escribió el agente», que se quita al editar. Va firmada como Xavi.
  - **Contenido**, en grupos fijos y en este orden: **Del blog** (1, el último publicado, con «Cambiar» y texto corto editable) · **Noticias** (aprobadas en los últimos 7 días) · **Agenda** (próximos 14 días).
  - Cada ítem: asa (arrastrar y teclado, §4.2), tipo y «Fuente: X», título, texto corto para la carta (200, editable; no cambia la ficha) y × para quitarlo.
  - «Añadir» abre un modal con Noticias / Eventos / Artículos publicados. Un borrador nunca puede entrar en la carta.
  - **Envío** (tarjeta):
    - Destinatarios activos por idioma.
    - «Sale 1 h después de aprobarla».
    - **Cupo de Brevo hoy**: barra de «usados + esta carta» sobre 300, ámbar desde 250 y roja si no cabe, con el desglose (confirmaciones de alta de hoy + destinatarios) y el margen.
    - Aviso fijo: el cupo se comparte con el doble opt-in, y con más de ~250 activos hay que repartir el envío o subir de plan (D75).
    - Si no cabe, **Aprobar** se desactiva con el motivo.
- **Inglés incompleto:** `banner-warn` en la pestaña EN con «Ver qué falta». Los ítems sin inglés se omiten en la versión EN. Qué reciben los suscriptores en inglés si no hay versión EN es la decisión 4 (§19.7).
- **Aprobar:** diálogo con asunto, destinatarios, «sale hoy a las HH:MM (dentro de 1 h)» y una checklist:
  - Fuentes en todas las noticias.
  - Baja y preferencias en el pie.
  - Cabe en el cupo.
  - Estado del inglés.

  Al aprobar pasa a `scheduled` con el toast «Programada para las HH:MM».
- **Programada:**
  - Tarjeta de cuenta atrás: «Sale a las 19:42 · hoy», reloj `mm:ss` en mono a 30 px (`aria-live="off"`, con un aviso sr-only cada 5 minutos) y barra.
  - Botones **Editar** y **Cancelar envío** (`btn-danger-ghost`).
  - El formulario queda en solo lectura, con un banner que lo explica.
  - **Editar** abre un `alertdialog` («¿Volver a borrador?»): la carta deja de estar programada y, al aprobarla otra vez, cuenta otra hora (decisión 3).
  - **Cancelar** abre un `alertdialog` con el foco en «No cancelar», y la carta queda «Cancelada».
  - A la hora de envío, la carta se bloquea.
- **Enviando:** barra de progreso (`role=progressbar`) con «140 de 243» y el estado de cada campaña. No se puede cancelar.
- **Enviada:** fecha, destinatarios por idioma y «Ver en Brevo ↗» para aperturas y clics. Sin píxel propio.
- **Fallida:** `banner-err` con el código, cuántos se enviaron y **Reintentar solo los pendientes** (requiere que 8.13 guarde el progreso por destinatario o por lote).
- **Antes de F4.6:** `banner-warn` «Brevo aún no está conectado» y **Aprobar** desactivado con `aria-describedby`. Se puede preparar y enviar una prueba (cuando exista el envío de pruebas).
- **Sin borrador:** vacío con la explicación de qué compone el agente el lunes y el botón **Componer ahora**.

**Historial:** tabla con Semana · Asunto · Estado · Destinatarios · Salió · ⋯ (Ver · Duplicar como borrador · Ver en Brevo). < 768: tarjetas.

**Descartado:** un editor de bloques libre (tipo Ghost). La carta es semanal y casi siempre la compone el agente: con grupos fijos y orden dentro de cada grupo, Xavi revisa en 2 minutos y la plantilla nunca se rompe.

### 19.4 · Ingesta (`ingesta.html`)

**Salud** (arriba, siempre):

- Correcta: `banner-info` con `circle-check` en `ok`: «Todo en marcha. Última recogida correcta: … Próxima: …».
- Alerta (cron de salud: ninguna correcta en 4 días): `banner-err` `role=alert` con los días, el último error en mono y dos salidas: **Crear token nuevo** (va a Tokens) y **Runbook: rotar el token ↗**.

**Recogidas:**

- KPIs de 30 días: correctas / total · borradores creados · % aprobados de esos · duplicados evitados.
- Tabla:
  - Columnas: ▸ · Empezó · Estado · Modo (≥ 1024) · Duración (≥ 1024) · Encontrados · **Nuevos** · Duplicados · Rechazados · Errores (rojo si > 0).
  - Estados: En curso (`st-sched`), Correcta (`st-pub`), Con avisos (`st-warn`), Fallida (`st-danger`).
  - Modo: Real, o el chip `dry_run · no escribe`.
- **Fila desplegada** (`aria-expanded`, `aria-controls`) en tres columnas:
  - Nuevos por tipo, con enlaces «Ver noticias de esta recogida» y «Ver eventos» (filtro `recogida=`).
  - Avisos (por ejemplo, «Tope de 40 filas alcanzado: 4 no entraron»).
  - Errores con código mono y fuente.
- < 768: tarjetas con la línea de contadores.
- Nota al pie: «Rechazados» son las filas que la base de datos no aceptó, no las que rechaza Xavi. También se citan los topes.

**Fuentes:**

- Búsqueda y segmentado Todas / Eventos / Noticias.
- Tabla:
  - Columnas: Fuente (nombre, y dominio mono debajo) · Para · Alcance · Idioma (≥ 1024) · Última vez (≥ 1280) · Aprobadas % (≥ 1024) · **Activa** (switch en la fila) · ⋯
  - Las inactivas, en `meta`.
- **Drawer de fuente:**
  - Nombre *.
  - Web * (afijo, «la página de noticias o calendario, no la portada»).
  - Para * (Eventos / Noticias / Las dos).
  - Alcance * (con la nota «eventos solo de Barcelona y Cataluña», D71).
  - Idioma.
  - **Indicaciones** (280, «qué mirar y qué no; nunca enlaces ni datos personales»).
  - Activa.
- Una fuente con borradores no se elimina: se desactiva.

**Tokens:**

- `banner-info` con el alcance:
  - Solo crea borradores, con topes.
  - Se guarda la huella SHA-256.
  - Máximo 2 activos, para rotar sin cortar.
- Lista: nombre, chip de estado, prefijo mono (`cgi_7f3a…`), creado, último uso, caducidad y **Revocar…**.
- **Crear token:**
  1. Modal con nombre y caducidad (90 días recomendado; aviso en Inicio 7 días antes).
  2. `alertdialog` «Copia el token ahora» con el token en mono (`break-all`), **Copiar** (anuncia «Token copiado») y la casilla «Lo he copiado y guardado en la rutina».
  3. **Hecho** queda desactivado hasta marcar la casilla. Al cerrar, el token desaparece de la interfaz y de la memoria del cliente.
- **Revocar:** `alertdialog`, foco en Cancelar. Si es el único activo, banner ámbar: la rutina deja de escribir y saltará la alerta. «No se puede deshacer».

**Descartado:** meter Ingesta dentro de Ajustes. Tiene estado vivo (salud, recogidas) que se mira cada semana; Ajustes es configuración que se toca una vez.

### 19.5 · Agenda: ajuste F8 (`agenda-f8.html`)

- El chip «Agente» ya existe (F6.12) y se mantiene.
- **Nuevo en la fila de la bandeja:** una línea bajo la fila con el **dominio de la fuente** como enlace (`external-link`, solo el dominio, sin `www.`) y «Recogida lun 16 nov».
  - Va fuera del botón de la fila: nada de interactivos anidados.
  - Mide 24 px, y 44 en táctil o en < 768.
  - Sin `source_url` (eventos manuales), no se pinta.
- **Tabla (Próximos, Pasados, Todos; ≥ 1280):** columna Origen = chip y dominio enlazado. En tarjetas (< 768), la línea va bajo el lugar.
- **Detalle:** el bloque **Fuente** (el mismo componente que en Noticias, `AdminSourceCard`) sube arriba del todo, con «recogida #N» enlazada a Ingesta. «Qué encontró el agente» pierde la fila de fuente para no repetirla.
- **Filtro Origen:** se añade «Recogida».
- **Textos (loro-lola):** el pie de la bandeja pasa de «una vez por semana» a «lunes y jueves», y el vacío muestra la fecha de la próxima recogida.

### 19.6 · Para backend (jabali-javi → leona-lia)

1. **`news`:**
   - Lo que la interfaz necesita: `title_es/en`, `summary_es/en` (CHECK ≤ 600), `note_es/en` (nota de Xavi, ≤ 600), `source_name`, `source_url` (no nula), `source_published_at`, `source_lang` y `source_title` (titular original, opcional; sale en la ficha), `category_id`, `scope` (`cat|es|intl`), `tags text[]`, `media_id` (con `image_license` y `image_credit` obligatorios si hay imagen, por CHECK), `slug`, `status`, `reject_reason`, `published_at`, `run_id` y `source_id`.
   - `agent_meta`: `{confidence, note, excerpt, inferred[], duplicate_of, similarity}`, con la misma forma que los eventos (§9.8) más `similarity`.
2. **Parecido con la fuente:** `similarity` 0–1 entre el resumen y `excerpt` (trigramas, `pg_trgm`), calculado al insertar y al guardar el resumen. La interfaz marca a partir de 0,35. No bloquea.
3. **`indexable`:** columna generada `note_es is not null and length(trim(note_es)) > 0` (y su par EN). Así sitemap, robots y la interfaz leen lo mismo (D73, lince-max).
4. **RPC de admin:**
   - `approve_news(uuid[])` y `reject_news(uuid[], reason)` en lote.
   - `reopen_news(id)` para Retirar y Deshacer.
   - Recuentos para el menú y para Inicio.
   - El agente no vuelve a proponer un `dedupe_key` que exista en cualquier estado.
5. **`newsletter_issues`:**
   - `status`, `week_start`, `subject_es/en`, `preheader_es/en`, `intro_es/en`, `intro_by_agent bool`, `approved_at`, `scheduled_for` (= `approved_at` + 1 h), `sent_counts jsonb` por idioma, `error_code` y `brevo_campaign_ids`.
   - `newsletter_issue_items`: `issue_id`, `kind` (`article|news|event`), `ref_id`, `position`, `blurb_es/en` (≤ 200).
   - RPC:
     - `approve_issue(id)`.
     - `unschedule_issue(id)`, que vuelve a borrador y limpia `scheduled_for`.
     - `cancel_issue(id)`.
     - `compose_issue(week)`, que es «Componer ahora».
     - `send_test_issue(id)`, en la Edge Function de 8.13.
     - Todas rechazan desde `sending` o `sent`.
   - El lock de `sending` lo pone la función de envío.
6. **Cupo:** `newsletter_quota_today()` con lo enviado hoy por Brevo (confirmaciones de alta y cartas) para la barra y la desactivación de Aprobar.
7. **Ingesta:**
   - `ingest_runs` con contadores por tipo, `mode`, `errors jsonb [{code, source_id, message}]`, `warnings jsonb` y `finished_at`.
   - `news_sources` con `kind`, `scope`, `lang`, `instructions` (≤ 280), `active` y `last_seen_at`.
   - Tasa de aprobación por fuente (vista).
   - `ingest_tokens` con `name`, `prefix` (los 8 primeros caracteres, en claro), `hash`, `expires_at`, `last_used_at`, `revoked_at` y `revoked_by`.
   - Máximo 2 activos por CHECK o trigger.
   - El token en claro lo genera el servidor y se devuelve una sola vez (lo cierra leona-lia en 8.1).

### 19.7 · Decisiones para Xavi (máximo 5, con recomendación)

1. **Bloque de noticias en la home:** sección propia entre Blog y Newsletter (B, **recomendada**), dentro de Blog (A) o ninguno. Ver `site/pages/home-noticias.html` y el README del sitio, §15.
2. **«Noticias» en el menú del sitio,** tras Blog (**recomendado**). Si no, solo en el pie, la home y la carta.
3. **Editar una carta programada:** vuelve a borrador y, al aprobarla de nuevo, cuenta otra hora (**recomendado**, sin riesgo de que salga a medio editar) o se edita sin perder la hora (más rápido para erratas, pero con autoguardado podría salir un cambio a medias).
4. **Suscriptores en inglés sin versión EN esa semana:** reciben la española con una línea «This week only in Spanish» (**recomendado**, mantiene el ritmo semanal) o no reciben nada esa semana. D75 dice «sin versión en inglés, solo en español»: confirma cuál de las dos lecturas es la buena.
5. **Aprobar noticias en lote:** al momento con Deshacer, y diálogo solo si hay avisos (**recomendado**), o diálogo siempre.
