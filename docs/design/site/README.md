# ChalkGuide · Diseño del sitio público

Autor: Búho-Pixel · F1.1 (brief) y F1.2 (direcciones) · 4 oct 2026 · Estado: **F1.3 (E · Pizarra) y F1.4 (mapa del sitio, §6) aprobados. F1.5 design system v1 en revisión (§7, [`design-system.html`](design-system.html))**

Mockups (abrir en navegador, 1440 y 390 px): [`index.html`](index.html) ·
[`direccion-a-libreta.html`](direccion-a-libreta.html) · [`direccion-b-topo.html`](direccion-b-topo.html) ·
[`direccion-c-magnesio.html`](direccion-c-magnesio.html) ·
[`direccion-d-mezcla.html`](direccion-d-mezcla.html) (iteración 1, §4) ·
**[`direccion-e-pizarra.html`](direccion-e-pizarra.html)** (iteración 2, recomendada, §5)

> Los rocódromos de los mockups (Bloc Poblenou, Vertical Sants, La Paret Gràcia, Roca Sant Andreu) son
> **ficticios** y sus datos, de ejemplo. Los pies de gato son modelos reales con precios orientativos.

---

## 1 · Brief de diseño (F1.1)

### Qué es
Un medio editorial de escalada en Barcelona con **voz de autor** (Xavi: 6 años escalando en BCN, 7b a los
41, empezó sin a quién preguntar) y **datos ordenados y comparables** que hoy están dispersos. Referencia
de producto: *Mama Proof para escaladores*.

### Audiencia
| Grupo | Qué necesita | Implicación de diseño |
| --- | --- | --- |
| **Quien empieza** (1–2 meses, entusiasmo + dudas) | Respuestas claras: qué rocódromo, qué pies de gato, cuánto cuesta | Entrada guiada, jerga explicada, índices fáciles de leer ("para empezar 8,7/10") |
| **Escalador constante** (2–3 veces/semana, años, no pro) | Comparar rápido, datos fiables, opinión con criterio | Tablas densas pero legibles, fecha de verificación, filtros |
| **Locales y expats** (es / en) | Mismo contenido en dos idiomas | Selector de idioma visible, layouts que aguantan +30 % de texto |
| Posible subtarget: **+40** | Credibilidad, legibilidad | Cuerpo ≥ 17 px, contraste alto, nada de microtexto gris |

### Objetivos
1. **Negocio:** altas a la newsletter (canal propio). CTA presente en home, artículos y fichas, sin dark patterns.
2. **Confianza:** que se note que una persona real visita, paga (o declara que no) y opina.
3. **Utilidad:** encontrar y comparar un dato (precio mensual, índice principiante, nota) en < 10 s en móvil.
4. **Recurrencia:** agenda mensual y blog con ritmo editorial que den motivos para volver.

### Principios
1. **El autor primero, la multitud después.** La reseña de Xavi domina; las opiniones de usuarios van debajo y con menos peso. Media de usuarios solo con ≥ 3 opiniones; si no, estado vacío digno ("aún sin media"), nunca un "0".
2. **Datos que se comparan igual.** Mismo formato, mismas unidades, mismas posiciones en todas las fichas. Números tabulares. Los índices calculados se distinguen de la opinión y enlazan a "cómo lo calculo".
3. **Transparencia a la vista, no en la letra pequeña.** "Visita invitada", "enlace de afiliado" y "verificado el …" son componentes de primer nivel (badges), no notas al pie.
4. **Práctico antes que bonito.** Cada bloque responde una pregunta concreta. Sin carruseles automáticos ni heros vacíos.
5. **Respeto al lector.** Newsletter con casilla desmarcada, sin pop-ups al entrar, sin urgencias falsas. Login con Google ≠ suscripción.

### Referencias y qué tomo de cada una
| Referencia | Qué tomo | Qué evito |
| --- | --- | --- |
| **Mama Proof** | Voz de autor cercana, artículos prácticos, recomendaciones concretas y listas útiles | Saturación de banners y afiliación poco señalizada |
| **Wirecutter** | "Nuestra elección" razonada, metodología pública, transparencia de afiliados | Textos muy largos antes del veredicto |
| **Alpinist y revistas impresas** (para A) | Jerarquía tipográfica de revista, filetes, capitulares | Densidad de portada que en móvil se vuelve ruido |
| **Croquis de escalada y guías de vías** (para B) | Datos codificados (grados, colores, símbolos), curvas de nivel, rigor | Hermetismo para quien empieza |
| **theCrag / 27crags** (para B) | Fichas técnicas comparables, iconografía de datos | Estética de base de datos sin voz |
| **Headspace, Duolingo, Patagonia Stories** (para C) | Calidez, entrada guiada por perfil, color como señal | Infantilizar a un público adulto |
| **Ghost / Substack** | CTA de newsletter limpio, foco en lectura | Monocultivo de texto sin datos |

### Restricciones
- **Mobile-first.** 390 px es el caso principal (Instagram → web). Táctiles ≥ 44 px, sin scroll horizontal de página (solo carruseles internos con snap y pista visible).
- **WCAG 2.2 AA.** Texto 4.5:1, texto grande y UI 3:1, foco visible propio, labels visibles, `aria-*` en estados, navegación por teclado, `prefers-reduced-motion`.
- **Bilingüe es/en.** Selector visible en cabecera y footer; layouts probados con textos +30 %; no meter texto en imágenes.
- **Datos densos legibles en móvil.** Las tablas se transforman en filas-ficha (`dl` con 3 datos clave) en < 768 px; nunca una tabla de 6 columnas con scroll.
- **Rendimiento.** Máx. 2 familias de Google Fonts (variable, `display=swap`, subset latin), imágenes AVIF/WebP con `aspect-ratio` reservado (CLS ≈ 0), placeholders de color de la propia paleta, sin JS para lo que puede hacer CSS (menú con `<details>` en mockup). Objetivo LCP < 2,5 s en 4G.
- **RGPD.** Casilla de consentimiento desmarcada, enlace a privacidad, registro de origen (lo implementa backend).
- **Sin identidad previa.** Marca provisional "ChalkGuide"; las direcciones proponen logotipo tipográfico, no definitivo.

---

## 2 · Direcciones (F1.2)

Las tres comparten contenido y arquitectura de la home (hero, artículos, rocódromos, comparador, agenda,
newsletter, footer) para que la comparación sea justa. Lo que cambia es **concepto, tipografía, color,
rejilla, foto y lenguaje de datos**.

### A · Libreta — *la revista del autor*
[`direccion-a-libreta.html`](direccion-a-libreta.html)

**Concepto.** El cuaderno de un escalador que apunta todo: una revista de autor con papel cálido, titulares
serif y tablas con filetes como la página de resultados de un periódico deportivo. La voz de Xavi
aparece desde el hero (columna "Hola, soy Xavi" con capitular). Transmite criterio e independencia.

**Paleta**
| Token | Hex | Uso | Contraste clave |
| --- | --- | --- | --- |
| `paper` | `#F5F0E6` | Fondo | — |
| `paper-2` | `#EDE5D6` | Bandas de sección | — |
| `ink` | `#1C1915` | Texto, filetes fuertes, footer | 15.4:1 sobre paper |
| `muted` | `#5E554A` | Texto secundario | 6.4:1 sobre paper · 5.8:1 sobre paper-2 |
| `terra` | `#A63D1C` | Acento (Montserrat al atardecer), CTA, kickers | 5.6:1 sobre paper · blanco sobre terra 6.4:1 |
| `olive` | `#4F5B3A` | Categorías, barras de índice | 6.4:1 sobre paper |
| `rule` | `#D9CFBE` | Filetes finos (decorativo, no informativo) | — |

**Tipografía.** **Fraunces** (variable, opsz 9–144, 600) para titulares, cifras grandes y citas en cursiva ·
**Source Sans 3** (400/600/700) para texto, UI y datos con `tabular-nums`. Small caps para kickers.
Escala: 17 / 20 / 24 / 30 / 36 / 60 px.

**Ritmo y rejilla.** 12 columnas, máx. 1200 px, gutter 40 px; columna de lectura 68ch. Separadores
editoriales (filete doble, filete 2 px ink) en vez de tarjetas. Espaciado amplio, base 4 px (8/16/24/40/56).

**Foto.** Cálida y documental: Xavi y la gente real en el muro, luz natural. Tratamiento con grano sutil y
ligeramente desaturado hacia tonos tierra; pie de foto siempre. Placeholder: degradado tierra + grano SVG.

**Datos.** Tabla con filetes en desktop (nombre en serif, cifras tabulares, barra fina de índice en olive,
nota del autor grande en Fraunces); en móvil, filas-ficha con 3 datos en `dl`. Badge "Visita invitada"
con borde terra. Comparador como dos columnas enfrentadas con lista de specs y cita "lo que aprendí".

| Pros | Contras |
| --- | --- |
| La voz de autor (el diferenciador) es el centro visual | Puede leerse "lenta" o menos moderna para el público más joven |
| Credibilidad e independencia: encaja con afiliación y patrocinios futuros sin parecer catálogo | Exige buenas fotos propias; con fotos flojas pierde mucho |
| Envejece bien; sistema sobrio y fácil de mantener | Los datos tienen menos "punch" que en B |
| Serif + cuerpo 17 px: muy legible para +40 | Serif en titulares largos en inglés/español ocupa más altura en móvil |

### B · Topo — *la guía técnica*
[`direccion-b-topo.html`](direccion-b-topo.html)

**Concepto.** Un croquis de escalada convertido en web: grafito, lima de señalización y curvas de nivel.
Los datos son el producto (hero con panel de cifras: 14 rocódromos, cuota media 61 €/mes…). Secciones
numeradas `01 / ROCÓDROMOS` como un manual. La voz de autor aparece, pero en segundo plano.

**Paleta**
| Token | Hex | Uso | Contraste clave |
| --- | --- | --- | --- |
| `bg` | `#FAFAF7` | Fondo | — |
| `ink` | `#121417` | Texto, bandas oscuras | 17.6:1 sobre bg |
| `muted` | `#555B66` | Secundario | 6.5:1 sobre bg |
| `lime` | `#D9F24A` | Señal: CTA en oscuro, nota destacada | ink sobre lime 14.7:1 · lime sobre ink 14.7:1 (**nunca lime sobre claro**) |
| `blue` | `#1F4FD1` | Enlaces, CTA en claro | 6.5:1 sobre bg · blanco sobre blue 6.8:1 |
| `on-dark muted` | `#9AA0AA` | Secundario sobre ink | 7.0:1 |
| `line-2` | `#8A909A` | Bordes de controles | 3.1:1 (UI) |
| `g3` naranja | `#C2410C` | Badge transparencia | 4.95:1 sobre bg |

**Tipografía.** **Archivo** variable (eje de anchura 62–125): expandida 118 % extrabold en mayúsculas para
titulares de sección, condensada 82 % para titulares de artículo, normal para texto · **IBM Plex Mono**
para cifras, etiquetas y metadatos. Escala: 16 / 18 / 24 / 36 / 68 px.

**Ritmo y rejilla.** 12 columnas visibles, máx. 1280 px; esquinas rectas, bordes de 1 px, rejilla
de 1 px entre tarjetas (`gap-px`) y fondo de papel milimetrado. Ritmo denso, compacto.

**Foto.** Secundaria; recortes cuadrados pequeños en listados y 16:9 en destacados, alto contraste,
pensada para fotos de muro/presas. Placeholder: grafito con curvas de nivel lima en SVG y etiqueta mono.

**Datos.** Filas de ficha en rejilla de 12 columnas que en móvil pasan a 3 columnas (mensual / índice /
nota) bajo el nombre; índice como barra segmentada de 5 bloques + cifra; nota del autor resaltada en lima.
Botones de orden (nota, precio, principiante). Comparador como **matriz de specs** con la fila de precio
resaltada: escala a 3–4 modelos lado a lado incluso a 390 px.

| Pros | Contras |
| --- | --- |
| La lectura de datos más rápida y escalable (comparador, filtros) | Frío: la voz de Xavi se diluye; parece un agregador más |
| Diferenciación fuerte frente a blogs de escalada | Intimida a quien lleva 1 mes escalando |
| Muy reconocible en Instagram (lima + grafito) | Mayúsculas expandidas en titulares largos (es/en) exigen cuidado |
| Mono + tabulares = cero ambigüedad en precios | Tendencia "tech" que puede caducar antes |

### C · Magnesio — *el club cercano*
[`direccion-c-magnesio.html`](direccion-c-magnesio.html)

**Concepto.** Lo que se siente al entrar en un buen rocódromo de barrio: color, magnesio en las manos,
alguien que te saluda. Verde pino de Collserola, coral y sol; formas redondeadas, pegatinas, medallas de
nota. La home pregunta "¿por dónde quieres empezar?" con dos puertas: *Acabo de empezar* / *Ya escalo
cada semana*.

**Paleta**
| Token | Hex | Uso | Contraste clave |
| --- | --- | --- | --- |
| `cream` | `#FFF8EE` | Fondo | — |
| `green` | `#0E3B2C` | Texto, bordes, bloques | 11.9:1 sobre cream · 9.1:1 sobre sun · 9.2:1 sobre pink |
| `muted` | `#4A5A52` | Secundario | 6.9:1 sobre cream · 5.7:1 sobre mint |
| `coral` | `#E5533C` | **Solo formas/fondos decorativos** | 3.5:1 sobre cream (no apto para texto) |
| `coral-dk` | `#B83A22` | CTA newsletter, hover | blanco sobre coral-dk 5.7:1 |
| `sun` | `#FFD94D` | Medallas de nota, footer, chips | green sobre sun 9.1:1 |
| `pink` / `mint` | `#FFD4C4` / `#CDEBD9` | Superficies de tarjeta y sección | green encima > 9:1 |

**Tipografía.** **Bricolage Grotesque** (variable, opsz, 700–800) para titulares con carácter ·
**Figtree** (400–700) para texto y UI, muy legible y amable. Escala: 17 / 20 / 24 / 36 / 48 / 72 px.

**Ritmo y rejilla.** 12 columnas, máx. 1240 px; tarjetas con radios grandes (24–40 px), borde 2 px green y
sombra dura de 4 px ("pegatina"). Mucho color por bloques; secciones alternadas en mint/cream.

**Foto.** Gente y manos, momentos de grupo; recortes redondeados y composiciones superpuestas tipo collage.
Placeholder: bloques de color con patrón de puntos de magnesio (CSS radial-gradient).

**Datos.** Tarjetas de rocódromo con **medalla** de nota del autor, dos "pastillas" de dato (al mes / para
empezar) y línea de usuarios; en móvil, carrusel con scroll-snap y pista "desliza". Comparador como
**cara a cara** ("vs") de dos modelos con "lo que aprendí". Agenda como chips de calendario de colores.

| Pros | Contras |
| --- | --- |
| La más acogedora para quien empieza; la entrada por perfil reduce dudas | Los datos densos (tablas de 14 rocódromos, 32 pies de gato) encajan peor en tarjetas |
| Muy compartible en Instagram, alta afinidad emocional | Riesgo de verse "app de fitness" o infantil para el escalador veterano |
| Encaja con la futura Chalk app (marca paraguas más amable) | Más color = más disciplina de contraste (coral no sirve para texto) |
| CTA de newsletter muy visible sin ser agresivo | Menos sensación de criterio editorial independiente |

---

## 3 · Recomendación

**Dirección A · Libreta**, incorporando dos piezas de las otras:

1. **De C:** la entrada por perfil *Acabo de empezar / Ya escalo cada semana* bajo el hero. Resuelve la
   audiencia doble sin cambiar el tono.
2. **De B:** el rigor de datos, con cifras tabulares, botones de ordenación en listados y la **matriz de specs**
   para el comparador de pies de gato cuando haya más de 2 modelos.

**Por qué.** El diferenciador de ChalkGuide no son los datos (se pueden copiar) sino **la persona que los
interpreta**. A es la única dirección en la que la voz de Xavi y la transparencia son la identidad visual,
y eso es lo que convierte a la newsletter: uno se suscribe a una persona, no a una tabla. Además es la que
mejor sostiene la regla "ninguna vía compra una reseña" cuando lleguen afiliados y patrocinios, la más
legible para el subtarget +40 y la que menos caduca. Su riesgo (parecer lenta) se compensa con el
terracota como energía, las bandas de datos en sans y las dos mejoras anteriores.

**Si Xavi prefiere más energía:** C con la tabla de rocódromos de A es la segunda opción viable. B solo la
recomendaría si el producto girase a herramienta/comparador antes que medio editorial.

**Siguiente paso (F1.3):** Xavi elige y comenta sobre los mockups; itero la dirección elegida y paso a
mapa del sitio (1.4) y design system v1 con tokens `@theme` (1.5).

---

## 4 · Dirección D · Mezcla (F1.3, iteración 1)

[`direccion-d-mezcla.html`](direccion-d-mezcla.html) · Petición de Xavi: mezcla de las tres, con botones,
hovers, transiciones y microinteracciones al nivel de 2025–2026.

### Qué toma de cada una y por qué
| De | Qué entra | Por qué |
| --- | --- | --- |
| **A · Libreta** (base) | Papel, tinta y terracota; Fraunces + Source Sans 3; cabecera de revista; columna "Hola, soy Xavi" con capitular; tabla con filetes; filas-ficha en móvil; cita "lo que aprendí" | La voz de autor sigue siendo la identidad y el motivo para suscribirse |
| **C · Magnesio** | Entrada por perfil *Acabo de empezar / Ya escalo cada semana*; radios más generosos (6/12/20 px); superficies cálidas (`terra-5`, `olive-5`, `ochre-5`); marcador ocre bajo la frase clave | Resuelve la audiencia doble y añade calidez sin convertirlo en una app infantil |
| **B · Topo** | Matriz de specs del comparador con chips de filtro; barras de índice; control de orden en listados; franja de cifras clave (14 · 61 € · 32 · 6); ticker de agenda sobre fondo tinta | Rigor y rapidez de lectura de datos |

**Qué no entra, para que no sea un collage:** ni la lima ni el grafito de B, ni sus mayúsculas expandidas,
ni IBM Plex Mono (sería una tercera familia y rompe el presupuesto de 2 fuentes). El rigor numérico se
consigue con `tabular-nums` de Source Sans 3. De C no entran el coral, el verde ni las sombras "pegatina".

### Paleta final
| Token | Hex | Uso | Contraste clave |
| --- | --- | --- | --- |
| `paper` | `#F5F0E6` | Fondo | — |
| `paper-2` | `#EDE5D6` | Bandas, pista del segmented | — |
| `surface` | `#FBF8F2` | Tarjetas, formularios | muted 6.9:1 |
| `ink` | `#1C1915` | Texto, indicador del segmented, chips activos, footer | 15.4:1 sobre paper · 17.5:1 con blanco |
| `muted` | `#5E554A` | Secundario | 6.4:1 paper · 5.8:1 paper-2 |
| `rule` | `#D9CFBE` | Filetes, pista de barras (decorativo) | olive sobre rule 4.7:1 |
| `terra` | `#A63D1C` | Primario, kickers, anillo de foco, checkbox marcado | 5.6:1 paper · blanco sobre terra 6.4:1 |
| `terra-7` | `#8A3116` | Pressed/hover alternativo | blanco 8.3:1 |
| `terra-5` | `#F3DDD1` | Tarjetas perfil "empiezo", fondo ghost hover | ink 13.4:1 · terra 4.9:1 |
| `olive` | `#4F5B3A` | Barras de índice, categorías, éxito | 6.4:1 paper |
| `olive-5` | `#DFE4D2` | Tarjetas perfil "habitual" | olive 5.6:1 |
| `ochre` | `#E9C77B` | Marcador de texto, acentos sobre tinta | ink 10.8:1 |
| `ochre-5` | `#F6E7C4` | Nota del autor destacada, fila de precio | ink > 12:1 · muted 6.0:1 |
| `error` | `#9B2C1A` | Mensajes de error (icono + texto) | 7.2:1 sobre surface |
| `disabled` | fondo `#E3DACB` / texto `#6F665A` | Botón deshabilitado | 4.1:1 (exento AA, aun así legible) |

### Tipografía final
- **Fraunces** (variable, opsz 9–144, 600): titulares, cifras grandes (notas, contadores), citas y menú móvil.
- **Source Sans 3** (400/600/700): texto, UI, tablas; `font-variant-numeric: tabular-nums lining-nums` en todo dato.
- Small caps para kickers. Escala: 15 / 17 / 20 / 24 / 30 / 36 / 60 px. Cuerpo 17 px.

### Spec de motion

**Tokens**
```css
--dur-fast: 120ms;     /* press, color de chip, iconos */
--dur-base: 200ms;     /* hover de color, opacidad, subrayado de nav */
--dur-slow: 360ms;     /* barridos de botón, lift de tarjeta, indicador del segmented, sheet, View Transitions */
--dur-reveal: 640ms;   /* entrada al hacer scroll (stagger 70 ms por elemento, máx. 4) */
--dur-count: 900ms;    /* contadores y relleno de barras (con 150 ms de retraso) */
--ease-out: cubic-bezier(.22, 1, .36, 1);     /* por defecto: todo lo que entra o responde al usuario */
--ease-in-out: cubic-bezier(.65, 0, .35, 1);  /* desplazamientos de ida y vuelta (reservado) */
--ease-pop: cubic-bezier(.34, 1.56, .64, 1);  /* solo micro-rebotes de ≤ 6 % (checkbox) */
--ring: 0 0 0 2px var(--paper), 0 0 0 4px var(--terra);
--lift: 0 14px 28px -16px rgb(28 25 21 / .35), 0 2px 6px -2px rgb(28 25 21 / .12);
```

**Qué se anima:** solo `transform`, `opacity`, `background-size`, colores y `box-shadow` (que es barato en
hover). **Qué no se anima:** `width`/`height`/`top` de layout (salvo el `width` del indicador del segmented,
acotado a un elemento), tipografía, el scroll de la página (sin scroll-jacking ni parallax), contenido que
el usuario está leyendo. Nada se mueve en bucle salvo el ticker, que tiene pausa. Sin cursor magnético
(no aporta a un medio editorial y falla en táctil).

**Inventario de componentes interactivos**
| Componente | Reposo | Hover (solo `hover:hover`) | Active / press | Focus-visible | Otros estados |
| --- | --- | --- | --- | --- | --- |
| Botón primario | Terra, texto blanco | Relleno tinta barre de izq. a dcha. (slow) + flecha +4 px | `scale(.97)` fast | `--ring` | Disabled: `#E3DACB`/`#6F665A`, sin barrido · Loading: `aria-busy`, spinner centrado, ancho fijo, sin doble envío |
| Botón secundario | Borde tinta 1.5 px | Relleno tinta sube desde abajo, texto paper | `scale(.97)` | `--ring` | Disabled, loading iguales |
| Botón ghost | Texto terra | Fondo `terra-5` en fade (base) | `scale(.97)` | `--ring` | — |
| Link editorial | Subrayado 1 px `rule` siempre visible | Barra terra 2 px se dibuja de izq. a dcha. (slow) | — | Barra completa + ring | — |
| Nav | Texto | Subrayado terra entra desde la izq. (base) | — | ring | `aria-current`: subrayado fijo |
| Tarjeta (artículo, perfil) | Borde `rule` | `translateY(-4px)` + `--lift` + imagen `scale(1.04)` (700 ms) + subrayado del título | — | `:focus-within` → ring en toda la tarjeta | Toda la tarjeta clicable (enlace estirado) |
| Segmented / tabs | Pista `paper-2` | Texto pasa a ink | — | ring en el botón | Indicador tinta se desliza (slow). Tabs: flechas ←/→, `aria-selected`, panel entra con fade+8 px |
| Ordenar listado | Segmented `aria-pressed` | ídem | — | ídem | Reordena filas con View Transitions (fallback instantáneo) + `aria-live` "Ordenado por…" |
| Chip de filtro | Borde `#B8AC98` | Borde ink + fondo `paper-2` | `scale(.96)` | ring | `aria-pressed=true`: fondo ink + tick que entra (width+opacity). Contador de resultados `aria-live` |
| Barra de índice | Pista `rule` | — | — | — | Se rellena con `scaleX` al entrar en pantalla (900 ms) |
| Contador | Valor final en HTML | — | — | — | Cuenta de 0 al valor con ease-out-quart al entrar (900 ms) |
| Checkbox | Caja 24 px, borde muted | — | — | ring en la caja | Marcado: fondo terra + `scale(1.06)` pop + check dibujado con `stroke-dashoffset` · Error: borde rojo + mensaje |
| Campo de texto | Borde `#8C8173` | — | — | Borde ink + halo terra 25 % | Error: borde `error` + icono + texto + `aria-invalid` |
| Newsletter | Formulario | — | — | — | Validación al enviar (no en vivo) → loading 1 s → éxito con círculo y check dibujados, foco al mensaje (`role=status`) |
| Barra sticky | Oculta | — | — | — | Aparece (`translateY`, slow) al salir la cabecera; fondo paper 82 % + `backdrop-filter: blur(12px)`. Inerte (`tabindex=-1`, `aria-hidden`) mientras está oculta |
| Menú móvil | — | — | — | Foco al primer enlace, Esc cierra y devuelve foco | Scrim en fade + panel baja 16 px |
| Ticker de agenda | Desplazamiento lineal 48 s | Pausa | — | Pausa con foco dentro | Botón pausar/reanudar (WCAG 2.2.2) · duplicado `aria-hidden` |
| Reveal | — | — | — | — | Secciones entran con opacidad + 18 px, una vez, stagger 70 ms |
| Marcador ocre | — | — | — | — | Se pinta de izq. a dcha. una vez (900 ms, 400 ms de retraso) |

**Reglas de reduced-motion** (`prefers-reduced-motion: reduce`)
1. Todo el contenido es visible desde el inicio: los estados ocultos de reveal, barras y marcador solo se
   aplican dentro de `@media (prefers-reduced-motion: no-preference)` **y** con la clase `.js` (sin JS también
   se ve todo).
2. Duraciones y retrasos a 0: los estados cambian (color, check, indicador), pero sin recorrido.
3. Sin View Transitions (se llama a la función directamente), sin contadores (se muestra el valor final),
   sin `scroll-behavior: smooth`.
4. El ticker se convierte en una lista estática con scroll horizontal propio, sin duplicado y sin botón de pausa.
5. El spinner deja de girar y se muestra estático; el texto del botón comunica igualmente `aria-busy`.

**Reglas generales:** el hover nunca lleva información exclusiva (todo hover está tras `@media (hover:hover)`
y su estado tiene equivalente en foco o en reposo). Objetivos táctiles de ≥ 44 px (chips, segmented,
botones, ticker, checkbox con la etiqueta entera clicable). El foco siempre se ve (`--ring`, invertido sobre tinta).

### Para pasar a `@theme` (coneja-lucky)
Colores como `--color-*` (`paper`, `paper-2`, `surface`, `ink`, `muted`, `rule`, `terra`, `terra-7`,
`terra-5`, `olive`, `olive-5`, `ochre`, `ochre-5`, `error`), fuentes `--font-serif` / `--font-sans`, radios
`--radius-sm|md|lg` (6/12/20) y los tokens de motion como `--duration-*` y `--ease-*`. Los componentes
`.btn`, `.link`, `.card`, `.seg`, `.chip`, `.bar`, `.check`, `.field` y `.sticky-bar` del mockup son la referencia
de CSS. La lógica (reveal, contadores, tabs, ordenación, filtros, ticker, newsletter) cabe en unos pocos
composables de Vue o directivas (`v-reveal`, `v-count`).

---

## 5 · Dirección E · Pizarra (línea Chalk app) — F1.3 · **aprobada**

[`direccion-e-pizarra.html`](direccion-e-pizarra.html) · Petición de Xavi: seguir la línea de Chalk app
([`docs/DESIGN.md`](../../DESIGN.md)) y adaptar solo lo que aporte valor a un medio editorial. Criterio validado por SúperXavi.

> No pude ver https://chalk-app.netlify.app/ en el navegador (la extensión deniega permiso en ese dominio).
> La dirección se basa solo en `DESIGN.md`. Conviene contrastarla con la app real.

### Qué se hereda, qué se adapta y qué se añade
| | Elemento | Decisión | Por qué |
| --- | --- | --- | --- |
| **Hereda** | Metáfora de pizarra | Fondo `#0f0f0f` (pared), `board #1a1a1a` (pizarra), `elevated #242424` | Marca paraguas: la guía y la app deben sentirse de la misma familia |
| | Tiza | Texto `#F0EDE8`, un solo acento `#E8923A`, texto `#1a0a00` sobre primario | Ídem; el naranja marca acción y "voz del autor" |
| | Bordes 0.5 px y profundidad por capas | Tarjetas y separadores a 0.5 px; hover sube de `board` a `elevated`, **sin sombras** | Coherencia con la app; en oscuro las sombras apenas se leen |
| | Inter + JetBrains Mono | Mono para precios, notas, índices, fechas, horas, grados y metadatos de verificación | Los datos técnicos se reconocen igual que en la app (`6c+`, `19:30`) |
| | Radios 4/8/12/16, escala de 4 px, 44 px táctiles, success/danger | Igual que la app | — |
| | Badges de la app | `bg-elevated` + mono para datos; `accent-muted` + acento para "visita invitada", "afiliado", "autor" | La transparencia usa el mismo lenguaje que "Tú" en la app |
| | Menú móvil como bottom sheet | Asa, `rounded-t-2xl`, scrim al 70 %, 300/250 ms | Patrón ya aprendido por los usuarios de la app |
| **Adapta** | Escala tipográfica | Cuerpo 16 px en UI y 17–18 px / 1.7 en lectura; titulares hasta 60 px | La app (14 px) se lee de pie en el gimnasio; aquí se leen artículos |
| | "Sin bold" | **Se mantiene**: solo 400 y 500. La jerarquía va por tamaño, color y tracking (`-0.025em` en display) | Inter 500 a 36–60 px sobre negro ya pesa lo bastante; añadir 600/700 rompería la familia sin ganar jerarquía |
| | Anchos | Medida de lectura `max-w-read` 680 px; página 1200 px; tablas y comparador a ancho completo | La app vive en 576 px; un medio necesita tablas anchas |
| | Contraste | `hint #444440` **solo decorativo** (1.8:1). Nuevo `meta #A19D94` para metadatos (≥ 5.7:1 en todas las superficies). `muted #888880` solo sobre background/board | `muted` cae a 4.35:1 sobre `elevated` |
| | Bordes de controles | Inputs, ghost y chips con borde **1 px `control #75716A`** (≥ 3.2:1) | Un borde 0.5 px `#2a2a2a` no cumple el 3:1 de componentes (WCAG 1.4.11) |
| | Texto de error/éxito | `danger-text #F06A68` y `success-text #3DBE93` para texto; `danger`/`success` siguen para rellenos e iconos | `#E24B4A` da 4.4:1 en board y 3.95:1 en elevated |
| | Motion | De D quedan solo los gestos sutiles, con 150/200/300 ms. **Fuera el marquee y los contadores** | "Pasivo y calmado", como la app |
| **Añade** | Textura de pizarra | Rejilla de 32 px al 1.4–2.2 % de opacidad (`.board-tex`) en hero, rocódromos, agenda y newsletter; rayado de 56 px en la pizarra del mes | Es lo que DESIGN.md §7 sugiere, sin llegar a ruido |
| | Trazos de tiza (SVG) | Subrayado a mano bajo una palabra clave del titular; círculo de tiza para destacar el evento recomendado. Se dibujan una vez | Destacar como lo haría alguien con tiza, sin iconos ni colores nuevos |
| | Notas manuscritas | **Caveat 500** solo en frases cortas (≤ 2 líneas, ≥ 24 px): cita del autor, "Lo que aprendí", cabecera "Octubre", anotación de la agenda. El texto largo sigue en Inter | Da la voz de Xavi sin perder legibilidad; es la única licencia tipográfica (1 peso, ~20 KB) |
| | Pizarra del mes | La agenda es un panel `board` rayado, con fechas en mono y anotación a mano | Convierte la agenda en el "corcho del rocódromo" |
| | Encuentra compañero | Vista previa de la pizarra de un rocódromo con entradas de la app y estado bloqueado ("Hay 4 personas más…", sin nombres), CTA a la app y a la lista de espera | Puente visual directo con Chalk app; reutiliza su patrón honesto de recuento sin nombres |
| **Se mantiene de D** | Entrada por perfil, orden de rocódromos con barras, matriz de pies de gato con chips, newsletter con casilla desmarcada y estados, transparencia visible | — | Ya validado en la iteración 1 |

### Tokens finales para `@theme`
```css
@theme {
  /* superficies (app) */
  --color-background: #0f0f0f;  --color-board: #1a1a1a;  --color-elevated: #242424;
  --color-line: #2a2a2a;        --color-line-strong: #333333;
  --color-control: #75716A;     /* NUEVO: borde de inputs, ghost y chips (≥3:1) */
  /* acento (app) */
  --color-accent: #E8923A;  --color-accent-hover: #C4721F;  --color-accent-muted: #3a2010;
  --color-on-accent: #1a0a00;
  /* texto */
  --color-foreground: #F0EDE8;
  --color-meta: #A19D94;        /* NUEVO: metadatos y texto secundario en cualquier superficie */
  --color-muted: #888880;       /* solo sobre background/board */
  --color-hint: #444440;        /* solo decorativo: separadores "·", asa del sheet */
  /* semánticos */
  --color-success: #1D9E75;  --color-success-text: #3DBE93;  --color-success-muted: #0a2a1e;   /* -text NUEVO */
  --color-danger: #E24B4A;   --color-danger-text: #F06A68;   --color-danger-muted: #2a0a0a;    /* -text NUEVO */
  /* tipografía */
  --font-sans: "Inter", system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, monospace;
  --font-hand: "Caveat", cursive;   /* NUEVO, solo notas cortas */
  /* radios (app) */
  --radius-sm: 4px; --radius-md: 8px; --radius-lg: 12px; --radius-xl: 16px;
  /* anchos (NUEVOS) */
  --container-page: 1200px; --container-read: 680px;
  /* motion */
  --duration-fast: 150ms; --duration-base: 200ms; --duration-slow: 300ms; --duration-draw: 600ms;
  --ease-out: cubic-bezier(.2,.8,.2,1); --ease-standard: cubic-bezier(.4,0,.2,1); --ease-in: cubic-bezier(.4,0,1,1);
}
```
Bordes decorativos: `0.5px` por lado (`border-t-[0.5px]`, `border-[0.5px]`…). Foco: `box-shadow: 0 0 0 2px var(--color-background), 0 0 0 4px var(--color-accent)`.

### Escala tipográfica
| Rol | Móvil | Desktop | Peso / interlineado | Fuente |
| --- | --- | --- | --- | --- |
| Display (H1) | 38 px | 60 px | 500 · 1.04–1.08 · `-0.025em` | Inter |
| H2 de sección | 28 px | 36 px (newsletter 48) | 500 · 1.1 · `-0.025em` | Inter |
| H3 tarjeta | 18–24 px | 18–30 px | 500 · 1.25 | Inter |
| Lectura (entradillas, artículo) | 17–18 px | 18 px | 400 · 1.7 · máx. 680 px | Inter |
| UI / cuerpo | 16 px | 16 px | 400 · 1.6 | Inter |
| Botón, chip, segmented | 15 px | 15 px | 500 | Inter |
| Secundario | 14–15 px | 14–15 px | 400 · `meta` | Inter |
| Kicker / etiqueta | 12–13 px | 13 px | 400 · mayúsculas · `tracking-wide` | JetBrains Mono |
| Dato (precio, nota, índice, hora) | 15–16 px | 15–16 px | 400–500 · tabular | JetBrains Mono |
| Nota manuscrita | 24–28 px (título 44) | ídem | 500 · 1.15 | Caveat |

### Spec de motion (actualizada)
**Tokens:** `fast 150ms` (hover de color, nav, press) · `base 200ms` (estados, chips, links de nav) · `slow 300ms`
(segmented, barrido del primario, reveal, sheet, View Transitions) · `draw 600ms` (solo trazos de tiza, barras de índice y check de éxito, una vez).
Easings: `ease-out cubic-bezier(.2,.8,.2,1)` para entradas y respuestas; `ease-standard cubic-bezier(.4,0,.2,1)` para colores;
`ease-in cubic-bezier(.4,0,1,1)` solo para salidas (cerrar el sheet, 250 ms).

**Se anima:** colores (todos los interactivos, como en la app), `transform` (press 0.98, flecha +3 px, indicador, sheet, zoom de foto 1.03), `opacity`, `background-size` (subrayados), `stroke-dashoffset` (tiza, check).
**No se anima:** sombras (no existen), layout, tipografía, nada en bucle, nada de contadores, marquee, parallax ni cursor magnético. Reveal con solo 8 px de recorrido.

| Componente | Reposo | Hover (solo `hover:hover`) | Press | Foco | Otros estados |
| --- | --- | --- | --- | --- | --- |
| Primario | `accent` / `on-accent` | `accent-hover` barre de izq. a dcha. (slow) + flecha +3 px | `scale(.98)` | ring | Disabled `elevated`/`muted` · Loading `aria-busy` + spinner, ancho fijo |
| Ghost | Borde 1 px `control`, texto foreground | Fondo `elevated`, borde `meta` | fondo `elevated` | ring | Disabled |
| Discreto (`quiet`) | `accent-muted` + texto acento | Fondo `elevated` | `scale(.98)` | ring | — (es el botón "Escribir" de la app) |
| Link | Subrayado 1 px `control` | Barra acento 1.5 px se dibuja (slow) | — | barra completa + ring | Variante acento |
| Nav | `meta` | `foreground` + subrayado acento (base) | — | ring | `aria-current` fijo |
| Tarjeta | `board`, borde 0.5 `line` | `elevated`, borde `line-strong`, foto 1.03 (600 ms), subrayado del título | — | ring en toda la tarjeta | Enlace estirado |
| Segmented / tabs | Pista `background` | Texto a foreground | — | ring | Indicador `elevated` con borde acento 0.5 px se desliza (slow); flechas ←/→; panel entra con fade |
| Ordenar | ídem | ídem | — | ídem | View Transitions + `aria-live` |
| Chip | Borde 1 px `control`, radio 4 | `elevated` | `scale(.97)` | ring | Activo: `accent-muted` + borde y texto acento + tick que entra |
| Barra de índice | Pista `elevated` | — | — | — | Relleno acento `scaleX` al entrar (draw) |
| Trazo de tiza | — | — | — | — | Se dibuja una vez al entrar (draw, 200 ms de retraso) |
| Checkbox | 22 px, borde `control` | — | — | ring | Marcado `accent` + check `on-accent` dibujado (slow) · Error borde `danger-text` + mensaje |
| Campo | `elevated`, borde `control` | — | — | Borde acento | Error: borde e icono + texto `danger-text` + `aria-invalid` |
| Newsletter | — | — | — | — | Validación al enviar → loading → éxito con círculo `success-text` dibujado; foco al mensaje |
| Barra sticky | Oculta | — | — | — | Aparece (slow) con `background/78` + blur 12 px; inerte mientras está oculta |
| Bottom sheet | — | — | — | Foco al primer enlace; Esc cierra y devuelve el foco | Entra 300 ms ease-out, sale 250 ms ease-in |

**Reduced motion:** como en D. El contenido y los trazos se ven completos sin JS y con `reduce`, porque los estados
iniciales ocultos solo existen bajo `no-preference` + `.js`. Duraciones a 0, sin View Transitions y spinner estático.

### Contrastes medidos (WCAG 2.x)
| Par | Ratio | Uso |
| --- | --- | --- |
| foreground / background · board · elevated | 16.4 · 14.9 · 13.3 | Texto principal |
| meta / background · board · elevated · accent-muted | 7.1 · 6.4 · 5.7 · 5.6 | Metadatos |
| muted / background · board · elevated | 5.4 · 4.9 · **4.35 ✗** | Por eso `muted` solo va sobre background/board |
| hint / board | **1.8 ✗** | Solo decorativo |
| accent / background · board · elevated · accent-muted | 7.9 · 7.1 · 6.4 · 6.2 | Kickers, badges, precios |
| on-accent / accent · accent-hover | 7.9 · 5.3 | Primario en reposo y hover |
| control / board · elevated | 3.6 · 3.2 | Bordes de controles (≥ 3:1) |
| danger / board · elevated | **4.4 · 3.95 ✗** → `danger-text` 5.8 · 5.2 | Errores |
| success / elevated → `success-text` | 4.6 → 6.6 | Éxito |
| line-strong / board | 1.4 | Decorativo (0.5 px), nunca como único límite de un control |

### Riesgos y siguientes pasos
- El tema oscuro editorial cansa más en lecturas largas. Propuesta para 1.5: el **artículo** usa el mismo sistema con
  cuerpo de 18 px / 1.7 a 680 px (probado aquí en entradillas); si Xavi lo pide, un modo "papel" opcional para artículos.
- Las fotos sobre negro necesitan un tratamiento consistente (ligeramente desaturadas y oscurecidas). Hay que definirlo con fotos reales.
- Revisar con la app real (no la he podido ver) antes de cerrar los tokens.

### 5.1 · Ajustes de aprobación (iteración 3)

**1 · Menos carga en la home.** Regla aplicada: cada sección responde **una** pregunta, tiene **un** CTA principal y
enseña lo mínimo para decidir si se hace clic. El resto vive en su página.

| Bloque | Antes | Ahora | Por qué / a dónde va |
| --- | --- | --- | --- |
| Hero | Entradilla larga, foto, meta, columna de autor con 3 badges + texto + link | Kicker, titular, entradilla de 1 frase, **1 CTA** ("Leer la guía") + fecha de verificación. Autor: cita manuscrita y una línea | La foto vive en el artículo y los badges en *Sobre mí*. Más aire: `py-24` en desktop |
| Por dónde empiezas | Tarjetas con número, título y subtítulo | Número + título | El subtítulo repetía el título |
| Rocódromos | 4 filas × 6 columnas (tipo, usuarios, verificación por fila) + párrafo de método + CTA | **3 filas × 3 datos** (mensual, índice principiante, nota del autor) + 1 línea de verificación + 1 CTA | Opiniones de usuarios, tipo detallado y fecha por ficha → listado `/rocodromos`. "Visita invitada" **se queda** (la transparencia no se recorta) |
| Pies de gato | 4 modelos × 4 filas + 3 chips de filtro + contador + aviso de scroll | **3 modelos × 3 filas** (cierre, rigidez, precio), sin chips | Los filtros son del comparador (`/pies-de-gato`); en la home es un vistazo. Cabe a 390 sin scroll horizontal. "Afiliado" se queda |
| Agenda | 4 eventos con hora y precio | 3 eventos con rocódromo; la hora y el precio, en la agenda | Pizarra más limpia; la anotación manuscrita se acorta |
| Blog | Bento de 5 piezas con tiempos de lectura | 3 piezas (1 grande + 2), solo categoría y título | Tiempos y entradillas, en el índice del blog |
| Encuentra compañero | 2 CTA, texto largo, 1 entrada + 2 bloqueadas, semana | **1 CTA**, una frase, 1 entrada + 1 bloqueada | La lista de espera por rocódromo va en su ficha, que es donde tiene sentido |
| Newsletter | Título largo + texto + aviso de Google | Título corto + una frase; el aviso de Google pasa a la página de opinar | El aviso aplica al login, no a la newsletter |
| Muestrario | Siempre visible | Plegado en `<details>` | Es material de revisión, no de producto |
| Orden de bloques | Hero · Perfil · Blog · Rocódromos · Compañero · Pies + Agenda · Newsletter | Hero · Perfil · **Rocódromos · Pies + Agenda · Blog** · Compañero · Newsletter | Primero los datos (el diferenciador), después la lectura y al final los puentes de conversión |

Resultado: de ~14 CTA y enlaces compitiendo a **1 CTA principal por sección**, y alrededor de un 40 % menos de texto
visible en la home.

**2 · Menú con submenú "Guías".** La navegación principal queda en **Guías ▾ · Blog · Agenda · Sobre mí** (+ idioma).
- *Desktop:* patrón **disclosure** (APG "navigation menu button"; no `role="menu"`, porque son enlaces). `<button aria-expanded aria-controls>`
  + lista de enlaces con título y una línea de descripción, lo que permite crecer (cuerdas, arneses, sectores de roca).
  Clic o Enter/Espacio abre y cierra; **↓** abre y lleva el foco al primer enlace; ↑/↓/Inicio/Fin navegan; **Esc** cierra y
  devuelve el foco al botón; salir con Tab o hacer clic fuera cierra. Hover opcional solo con `(hover:hover) and (pointer:fine)`:
  abre a los 120 ms y cierra a los 300 ms para que no parpadee al cruzar. Panel `board` con borde 0.5 px y radio 12;
  entra con opacidad + 4 px en 200 ms y el chevron gira 180° en 200 ms.
  La barra compacta reutiliza el mismo componente y queda `inert` mientras está oculta.
- *Móvil:* dentro del bottom sheet, "Guías" es un **acordeón** (`aria-expanded`, `grid-template-rows 0fr→1fr` en 200 ms;
  los enlaces cerrados no reciben foco). El foco entra al primer control del sheet y Esc lo cierra.
- *Reduced motion:* mismos estados, sin recorrido.

**3 · Etiqueta junto al logo.** "escalar en Barcelona" (manuscrita) → **BARCELONA** con `label-mini`: JetBrains Mono 12 px,
mayúsculas, `letter-spacing: .14em`, color `meta`. Es el mismo estilo que los kickers ("COSTES · GUÍA PRÁCTICA"), ahora
unificados en la clase `.label-mini`. Visible también en móvil (cabe a 390 px junto al logo de 22 px); corregido el 5.10.26, antes decía que se ocultaba por debajo de 640 px.

---

## 6 · Mapa del sitio y navegación (F1.4) · **aprobado**

Aprobado por Xavi el 5 oct 2026 con **todos** los cambios SEO de lince-max (§6.x). **Esta sección es la fuente de verdad**
de rutas, indexación y navegación; §6.x queda como registro de la revisión.

### Convenciones de rutas
- Español sin prefijo y por defecto; inglés bajo `/en` (Nuxt i18n `prefix_except_default`). `/es/*` → 301 a la ruta sin prefijo.
- Slugs en minúsculas, con guiones, sin tildes ni ñ y **sin barra final** (301 de `/ruta/` a `/ruta`). La ciudad va en title y H1, no en la URL.
- **Guías en primer nivel**: cada categoría es su propia raíz (`/rocodromos`, `/pies-de-gato`, `/resolar-pies-de-gato`).
  "Guías" es solo un menú de navegación, **sin URL**. Una categoría nueva (cuerdas, arneses…) será otro primer nivel.
- Entidades con nombre propio: **mismo slug** en los dos idiomas (`bloc-poblenou`). Artículos: slug traducido.
- `barrio` queda reservado: no se puede usar como slug de rocódromo.
- El estado de la UI (`?orden`, `?barrio`, `?precio`, `?comparar`, `?vista`) lleva canonical a la ruta sin query, no va al
  sitemap y no se enlaza con `<a href>` desde plantillas indexables (botones con `aria-pressed` que actualizan la URL por JS).
  No se bloquea en `robots.txt`; solo `Disallow: /api/`.
- Cambio de slug → 301 y actualizar el hreflang del par.
- Migas de pan = URL: Inicio › Rocódromos › Bloc Poblenou · Inicio › Blog › Categoría › Artículo (`BreadcrumbList`).

### Tabla de rutas final
| Página | ES | EN | Índice | Sitemap | Contenido (resumen) / notas |
| --- | --- | --- | --- | --- | --- |
| Home | `/` | `/en` | sí | sí | Hero, por dónde empiezas, 3 rocódromos, vistazo a pies de gato, pizarra del mes, 3 artículos, Encuentra compañero, newsletter |
| Rocódromos | `/rocodromos` | `/en/climbing-gyms` | sí | sí | Listado completo con orden y filtros en cliente (barrio, tipo, precio, índices), lista o mapa, metodología. HTML servido sin filtrar |
| Ficha de rocódromo | `/rocodromos/[slug]` | `/en/climbing-gyms/[slug]` | sí | sí | Reseña del autor (dominante, "visita invitada"), ficha técnica (verificado el…), índices, opiniones por criterios (media con ≥ 3), Encuentra compañero + lista de espera, eventos. Opinar en bottom sheet `#opinar`. Schema `SportsActivityLocation` + `Review` |
| Resolar pies de gato | `/resolar-pies-de-gato` | `/en/climbing-shoe-resoling` | sí | sí | Comparativa de resoladores: precio por par, rand, plazo, envío, gomas |
| Ficha de resolador | `/resolar-pies-de-gato/[slug]` | `/en/climbing-shoe-resoling/[slug]` | sí | sí | Experiencia del autor, datos, opiniones. `LocalBusiness` |
| Pies de gato (comparador) | `/pies-de-gato` | `/en/climbing-shoes` | sí | sí | Filtros, rango de precio, hasta 4 modelos lado a lado (`?comparar=` → `noindex`, canonical aquí); afiliado y fecha de precio |
| Ficha de pie de gato | `/pies-de-gato/[slug]` | `/en/climbing-shoes/[slug]` | sí | sí | Specs, "lo que aprendí", dónde comprar (`rel="sponsored nofollow"`), similares. `Product` |
| Blog | `/blog` | `/en/blog` | sí (EN con ≥ 3 artículos) | sí | Índice por pilares y destacados; `?pagina=N` con self-canonical |
| Categoría | `/blog/categoria/[slug]` | `/en/blog/category/[slug]` | solo con ≥ 3 artículos y texto propio; si no, `noindex,follow` | solo si es indexable | `empezar-a-escalar`↔`getting-started`, `donde-escalar`↔`where-to-climb`, `material`↔`gear`, `progresion-y-cuidado`↔`progress-and-care`, `costes`↔`costs`, `comunidad`↔`community` |
| Artículo | `/blog/[slug]` | `/en/blog/[slug]` | sí | sí | Plano, sin categoría ni fecha en la URL. Lectura a 680 px. `Article` + `Person` |
| Agenda | `/agenda` | `/en/events` | sí | sí | URL perenne: próximos ~60 días, filtro por rocódromo y tipo |
| Agenda de un mes | `/agenda/[aaaa-mm]` | `/en/events/[yyyy-mm]` | mes en curso o futuro con ≥ 1 evento; pasados o vacíos `noindex,follow` | solo en curso y futuros | Calculado en render. Sin páginas por evento ni `Event` JSON-LD en el MVP |
| Sobre mí | `/sobre-mi` | `/en/about` | sí | sí | Quién escribe y por qué (`Person`) |
| Transparencia | `/transparencia` | `/en/transparency` | sí | sí | Cómo valoro, índices, afiliados, visitas invitadas; enlazada desde cada ficha |
| Newsletter | `/newsletter` | `/en/newsletter` | sí | sí | Única landing de conversión, con un ejemplo de carta |
| Confirmada / baja | `/newsletter/confirmada`, `/newsletter/baja` | `/en/newsletter/confirmed`, `/en/newsletter/unsubscribed` | `noindex,nofollow` | no | Estados del doble opt-in y la baja |
| Entrar | `/entrar` | `/en/sign-in` | `noindex,nofollow` | no | Login con Google; aclara que no suscribe a la newsletter |
| Legal | `/privacidad`, `/cookies`, `/aviso-legal` | `/en/privacy`, `/en/cookies`, `/en/legal-notice` | `noindex,follow` | no | Desde el footer |
| 404 | — | — | `noindex`, HTTP 404 real | no | Buscador + enlaces a las guías; nunca redirige a la home |

**Idioma (D3):** una URL `/en/...` existe solo si hay versión inglesa real (si no, 404). hreflang `es`/`en` sin región, más
`x-default` → ES, **solo entre versiones que existen**. Un listado EN es indexable con ≥ 3 elementos (≥ 5 en rocódromos).
El selector de idioma enlaza al par, o al índice EN más cercano, o se deshabilita: nunca a un 404.
**Sitemap** por locale, con `lastmod` real y alternates solo cuando existen los dos idiomas.

### Navegación
- **Principal (desktop):** Logo + BARCELONA · **Guías ▾** (botón sin URL que despliega Rocódromos `/rocodromos`, Resolar pies de gato
  `/resolar-pies-de-gato` y Pies de gato `/pies-de-gato`; crece con nuevas categorías) · Blog `/blog` · Agenda `/agenda` ·
  Sobre mí `/sobre-mi` · ES/EN. [Newsletter] `/newsletter` aparece solo en la barra compacta.
- **Móvil:** Menú → bottom sheet con acordeón Guías, Blog, Agenda, Sobre mí e idioma.
- **Etiquetas del menú:** "Rocódromos", "Resolar pies de gato", "Pies de gato". En inglés: "Climbing gyms", "Shoe resoling", "Climbing shoes".
- **Footer:** Guías (las 3) · Medio (Blog, Agenda, Newsletter, Sobre mí) · Cuentas claras (Transparencia, Privacidad, Cookies,
  Aviso legal) · Chalk app (`app.chalkguide.com`, con el rocódromo preseleccionado desde la ficha) · idioma ·
  "Ninguna reseña se compra. Lo pagado se marca."

### 6.x Revisión SEO (lince-max) · **incorporada en §6** (registro)

Revisor: Lince-Max · 4 oct 2026 · **Veredicto: CAMBIOS** (el árbol es sólido; hay 5 cambios de ruta/reglas que conviene cerrar antes de implementar F1.4. Sin ellos, no bloquea el diseño visual).

Revisado a partir del brief y de la config i18n (`prefix_except_default`, `es` por defecto, `en-GB`). Intención de búsqueda razonada con el vocabulario real de la zona; **sin datos de volumen**: validar con Search Console tras 4-6 semanas de indexación y ajustar (los slugs con 301 son baratos de cambiar al inicio y caros después).

#### Cambios obligatorios (resumen)
1. **Quitar el nivel `/guias`** (pregunta 1): rutas de primer nivel. El hub tiene poco valor de búsqueda ("guías de escalada" es genérico) y cuesta un nivel de profundidad y un contenido casi vacío. "Guías" se queda como menú de navegación, no como URL.
2. **Resoladores → `/resolar-pies-de-gato`** (en: `/en/climbing-shoe-resoling`): la consulta real es "resolar pies de gato (barcelona)", no "resoladores".
3. **Agenda**: el mes en curso y `/agenda` no pueden competir; regla de canonical y `noindex` para meses pasados (abajo).
4. **hreflang selectivo** por D3: nunca emitir alternate a un `/en/...` que no existe; ningún `/en` con texto en español.
5. **Sitemap por locale** y `canonical` sin query (los defaults de i18n/sitemap no lo hacen solos; ver "Implementación").

#### Respuestas a las 4 preguntas abiertas
1. **`/guias/...` o primer nivel:** **primer nivel** (`/rocodromos`, `/pies-de-gato`, `/resolar-pies-de-gato`). Las URLs cortas con la keyword al principio son más legibles en SERP y en Instagram, las fichas quedan a profundidad 2 (`/rocodromos/bloc-poblenou`) y las migas coinciden con la URL (Inicio › Rocódromos › Bloc Poblenou). El "crecer con cuerdas, arneses…" no necesita el prefijo: cada categoría nueva es otro primer nivel. Si algún día hay ≥ 6 categorías y el hub tiene contenido propio, se crea `/guias` como página nueva (sin redirecciones que rehacer). Mientras, "Guías ▾" es un botón de menú, sin URL.
2. **`resoling` o `resolers`:** `resoling`, pero con la acción completa en el slug: **`/en/climbing-shoe-resoling`**. "Resolers" casi no se busca; la gente busca "climbing shoe resoling Barcelona" / "resole climbing shoes". En español, **`/resolar-pies-de-gato`** (infinitivo = la forma en que se teclea la necesidad; "resolado" queda para el H1/título como variante).
3. **`/en/events` o `/en/whats-on`:** **`/en/events`**. El expat busca "climbing events Barcelona" / "bouldering events"; "what's on" es coloquial y no contiene la keyword. En español se queda `/agenda`.
4. **Filtros indexables (p. ej. barrio):** de acuerdo, **fuera del MVP**. Con 14 rocódromos en ~10 barrios habría 1-2 por barrio: páginas finas y casi duplicadas del listado. Reevaluar cuando un barrio tenga ≥ 4 fichas **y** texto propio (p. ej. Gràcia, Poblenou, Sants) y Search Console muestre impresiones para "rocódromos gràcia". Entonces: `/rocodromos/barrio/[slug]` (reservar ya `barrio` como slug prohibido de rocódromo). El patrón "X vs Y" del comparador es el siguiente candidato (ver comparador).

#### Tabla de rutas final recomendada

Slugs: minúsculas, guiones, sin tildes, sin barra final (301 de `/ruta/` a `/ruta`), `/es/...` no existe (301 a la ruta sin prefijo). Ciudad solo en `title`/H1 ("Rocódromos en Barcelona"), no en la URL: el sitio es Barcelona y el slug corto envejece mejor.

| Página | ES | EN | Índice | Sitemap | Canonical / notas |
| --- | --- | --- | --- | --- | --- |
| Home | `/` | `/en` | sí | sí | propio |
| Rocódromos (listado) | `/rocodromos` | `/en/climbing-gyms` | sí | sí | sin query. Title: "Rocódromos en Barcelona: precios, horarios y opinión" |
| Ficha de rocódromo | `/rocodromos/[slug]` | `/en/climbing-gyms/[slug]` | sí | sí | slug de entidad igual en ambos idiomas. Schema `SportsActivityLocation` + `Review` |
| Resoladores (listado) | `/resolar-pies-de-gato` | `/en/climbing-shoe-resoling` | sí | sí | sin query |
| Ficha de resolador | `/resolar-pies-de-gato/[slug]` | `/en/climbing-shoe-resoling/[slug]` | sí | sí | `LocalBusiness` |
| Pies de gato (comparador) | `/pies-de-gato` | `/en/climbing-shoes` | sí | sí | canonical sin query. Incluir "zapatillas de escalada" en title/H1 como variante |
| Ficha de pie de gato | `/pies-de-gato/[slug]` | `/en/climbing-shoes/[slug]` | sí | sí | `Product`; enlaces de afiliado `rel="sponsored nofollow"` |
| Blog (índice) | `/blog` | `/en/blog` | sí | sí | paginación `?pagina=N` con self-canonical (cuando exista) |
| Categoría de blog | `/blog/categoria/[slug]` | `/en/blog/category/[slug]` | sí **si** ≥ 3 artículos y texto introductorio propio; si no, `noindex,follow` | solo si indexable | slugs de categoría de §6 sin cambios |
| Artículo | `/blog/[slug]` | `/en/blog/[slug]` | sí | sí | plano, sin categoría ni fecha en la URL. `Article` + autor `Person` |
| Agenda (hub) | `/agenda` | `/en/events` | sí | sí | "próximos eventos" (ventana móvil ~60 días), canonical propio |
| Agenda de un mes | `/agenda/[aaaa-mm]` | `/en/events/[yyyy-mm]` | mes en curso y futuros con ≥ 1 evento: sí. Pasados o vacíos: `noindex,follow` | solo en curso + futuros | ver reglas de agenda |
| Sobre mí | `/sobre-mi` | `/en/about` | sí | sí | señal de autoría (`Person`) |
| Transparencia | `/transparencia` | `/en/transparency` | sí | sí | pieza clave de confianza; enlazar desde cada ficha |
| Newsletter (landing) | `/newsletter` | `/en/newsletter` | sí | sí | única landing de conversión; title con "newsletter de escalada en Barcelona" |
| Confirmada / baja | `/newsletter/confirmada`, `/newsletter/baja` | `/en/newsletter/confirmed`, `/en/newsletter/unsubscribed` | `noindex,nofollow` | no | |
| Entrar | `/entrar` | `/en/sign-in` | `noindex,nofollow` | no | |
| Legal | `/privacidad`, `/cookies`, `/aviso-legal` | `/en/privacy`, `/en/cookies`, `/en/legal-notice` | `noindex,follow` | no | enlazadas desde el footer |
| 404 | — | — | `noindex`, **status HTTP 404** | no | sin redirigir a home (soft-404) |
| ~~Guías (hub)~~ | ~~`/guias`~~ | ~~`/en/guides`~~ | eliminado del MVP | | |

Cambios respecto a §6: eliminados `/guias` y `/en/guides` (prefijo de los tres bloques); `resoladores/resoling` pasan a `resolar-pies-de-gato`/`climbing-shoe-resoling`; todo lo demás se mantiene.

#### Reglas de indexación

**Idioma y D3 (inglés opcional)**
- Una URL `/en/...` existe **solo si** hay versión inglesa real. Si no, responde 404 (nunca redirige al español, nunca muestra el texto en español bajo `/en`).
- hreflang **solo entre versiones que existen**. Par es+en: `es`, `en` y `x-default` → URL española, cada una con su par y autorreferencia. Página solo en español: un único `hreflang="es"` (autorreferencia) y `x-default` a sí misma; sin `en`.
- El selector de idioma en una página sin inglés enlaza al índice inglés más cercano (`/en/blog`, `/en/climbing-gyms`) o, si tampoco existe, se oculta/deshabilita. Nunca a un 404.
- Un listado `/en/...` es indexable solo si tiene ≥ 3 elementos traducibles (≥ 5 recomendado para rocódromos); si no, `noindex,follow` hasta que los haya. `/en/blog` igual (≥ 3 artículos).
- Valores hreflang recomendados: `es` y `en` **sin región** (los expats en Barcelona no son solo británicos); `en-GB` puede seguir en `<html lang>`/ortografía del texto. Prioridad baja.
- Catalán futuro: `prefix_except_default` ya admite `/ca/...` sin romper nada; no pre-crear rutas.

**Parámetros, filtros y comparador**
- Toda la UI de estado (`?orden`, `?barrio`, `?precio`, `?comparar`, `?vista`) lleva `canonical` a la ruta **sin query**, no entra en sitemap y no se enlaza con `<a href>` desde plantillas indexables (botones/`aria-pressed` que actualizan la URL con JS o enlaces con `rel="nofollow"` si deben ser `<a>`).
- **No bloquear con `robots.txt`** las URLs con query (`Disallow: /*?`): Google no vería el canonical. Solo `Disallow: /api/`.
- El HTML servido (SSR/prerender) de `/pies-de-gato` y `/rocodromos` es siempre el listado completo sin filtrar; los filtros se aplican en cliente.
- `?comparar=a,b` queda `noindex` (canonical al comparador). Segunda fase si hay demanda: páginas curadas `/pies-de-gato/comparar/[a]-vs-[b]` solo para pares con intención clara y texto propio de Xavi, nunca generadas combinatoriamente.
- Canibalización: el comparador y el listado atacan el término principal ("pies de gato", "rocódromos barcelona"); los artículos atacan colas largas ("mejores pies de gato para empezar") y **enlazan** a ellos. No crear un artículo que repita el listado.

**Agenda (contenido efímero)**
- `/agenda` (en: `/en/events`) es la URL perenne y se indexa con canonical propio; muestra los próximos ~60 días.
- Mes en curso y futuros (`/agenda/2026-11`): indexables **solo con ≥ 1 evento**; canonical propio. El mes en curso comparte contenido con el hub: aceptable porque el hub es más amplio; no canonicalizar uno a otro.
- Meses pasados: **`noindex,follow`**, fuera del sitemap, página accesible (enlaces desde la fila de meses). No 404 ni redirección: conservan utilidad para el usuario y no pierden enlaces. Pasa a `noindex` el día 1 del mes siguiente (regla calculada en render, no a mano).
- Mes futuro sin eventos: `noindex,follow` hasta que tenga uno; no enlazar más allá de +3 meses.
- No hay páginas por evento en MVP; sin `Event` JSON-LD hasta que cada evento tenga URL propia (Google lo exige en la página del evento, no en listados). Reevaluar si se añade ficha de evento.

**Blog**
- **Plano** (`/blog/[slug]`) frente a anidado: plano. El slug no cambia si el artículo cambia de pilar, evita duplicados por varias categorías y reduce 301. La relevancia temática se da con migas (`BreadcrumbList`: Inicio › Blog › Categoría › Artículo), enlaces internos y la página de categoría.
- Slug de artículo: la keyword principal sin fechas ni stopwords innecesarias, traducido por idioma. Ej.: `cuanto-cuesta-escalar-en-barcelona` ↔ `how-much-does-climbing-cost-in-barcelona` (correcto; "climbing cost Barcelona" cabe en title).
- Cambio de slug → 301 permanente, y actualizar hreflang del par.

**Utilidad y legales**
- Legales: `noindex,follow`, fuera del sitemap, accesibles desde el footer. Confirmación/baja/entrar: `noindex,nofollow`. No bloquear en `robots.txt` (el `noindex` debe poder leerse). `/api/**` sí en `Disallow`.
- 404 con código 404 real y `noindex`. La página buscador/enlaces a guías se mantiene.
- Fichas con `?` de login/retorno (`#opinar`) usan fragmento, sin efecto SEO. Bien.

**Sitemap (`@nuxtjs/sitemap`)**
- Incluye solo URLs indexables (tabla anterior), con `lastmod` real (fecha de verificación de datos / de edición, no la del build) y alternates `es`/`en` **únicamente cuando ambos existen**.
- Borradores y entidades sin traducción: no generan alternate. Meses pasados, vacíos, legales, utilidad y todo lo de query: fuera.

#### Implementación (para coneja-lucky, y para mí en metadatos)
- Slugs traducidos por idioma vía `i18n.customRoutes` / `defineI18nRoute`; las fichas dinámicas (rocódromos, modelos, artículos) necesitan una fuente de sitemap que sepa qué idiomas tiene cada registro (campo `locales` o presencia de la traducción). Sin eso, el módulo generará alternates a `/en/...` inexistentes.
- `canonical` computado desde `route.path` sin query (revisar `canonicalQueries` de `@nuxtjs/i18n` en la versión instalada; vacío = sin query).
- `robots` por página con `useSeoMeta({ robots: 'noindex, follow' })` en legales/agenda pasada; confirmar que `@nuxtjs/robots` emite `X-Robots-Tag`/meta también en prerender.
- Netlify: forzar sin barra final y 301 `/es/*` → `/*` en `netlify.toml`/`routeRules`.
- Dominio pendiente (.com o .es): para público de Barcelona, `.es` suma una señal geográfica leve; con `.com` hay que cubrir con contenido y `hreflang`. Decidir antes de lanzar, porque cambiarlo después es una migración.
- Revisión posterior (no bloquea F1.4): títulos y descripciones únicos por página (propuesta a loro-lola), JSON-LD por tipo de página según `.ai/marketing-seo.md`, y `BreadcrumbList` con las migas ya definidas.

---

## 7 · Design system v1 (F1.5) · sitio público

Referencia viva y navegable: **[`design-system.html`](design-system.html)**. Se construye sobre la Dirección E aprobada y es
la fuente de verdad visual para coneja-lucky. Esta sección resume lo que se pega en código; los estados de cada componente
se ven en la página.

### Decisiones
- **Tema único oscuro.** Es la marca Chalk y la app es oscura. Un tema claro duplicaría el QA de contraste sin demanda.
  Queda abierto (fuera de v1) un modo "papel" solo para la lectura de artículos largos, si las métricas de lectura lo piden.
- **Logo oficial** (`public/brand/`, de Xavi): monocromo, sin el cuadrado naranja. En el tema oscuro, `logo-white.svg`. El acento `#E8923A` (el mismo naranja de los isotipos) ya no está en el header: vive en la acción y la señal (ver "Logo").
- **Nombre de marca:** en textos, **ChalkGuide** (una palabra, C y G mayúsculas). Nunca "ChalkGuide". "chalkguide" en minúsculas es solo el wordmark del logo.
- **Iconos: Lucide** (`lucide-vue-next`, importados uno a uno; ISC). Trazo 1.75, extremos redondos, `currentColor`;
  tamaños 16 (con caption), 20 (por defecto) y 24 (navegación y estados vacíos).

### Tokens para `app/assets/css/main.css` (Tailwind v4)
```css
@import "tailwindcss";

@theme {
  /* --- Color: superficies (Chalk app) --- */
  --color-background: #0f0f0f;
  --color-board: #1a1a1a;
  --color-elevated: #242424;
  --color-line: #2a2a2a;          /* bordes 0.5px decorativos */
  --color-line-strong: #333333;
  --color-control: #75716A;       /* borde 1px de inputs, ghost y chips (≥3:1) */
  /* --- Color: acento --- */
  --color-accent: #E8923A;        /* = naranja del logo */
  --color-accent-hover: #C4721F;
  --color-accent-muted: #3a2010;
  --color-on-accent: #1a0a00;
  /* --- Color: texto --- */
  --color-foreground: #F0EDE8;
  --color-meta: #A19D94;          /* secundario, válido en cualquier superficie */
  --color-muted: #888880;         /* solo sobre background/board */
  --color-hint: #444440;          /* solo decorativo */
  /* --- Color: semánticos --- */
  --color-success: #1D9E75;  --color-success-text: #3DBE93;  --color-success-muted: #0a2a1e;
  --color-danger: #E24B4A;   --color-danger-text: #F06A68;   --color-danger-muted: #2a0a0a;

  /* --- Tipografía --- */
  --font-sans: "Inter", ui-sans-serif, system-ui, sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, monospace;
  --font-hand: "Caveat", cursive;
  --font-weight-normal: 400;
  --font-weight-medium: 500;      /* máximo: no hay bold */
  --text-display: clamp(2.375rem, 1.6rem + 3.2vw, 3.75rem);  --text-display--line-height: 1.04;  --text-display--letter-spacing: -0.025em;
  --text-title-1: clamp(2.125rem, 1.6rem + 2.2vw, 3rem);      --text-title-1--line-height: 1.08;  --text-title-1--letter-spacing: -0.025em;
  --text-title-2: clamp(1.75rem, 1.45rem + 1.2vw, 2.25rem);   --text-title-2--line-height: 1.12;  --text-title-2--letter-spacing: -0.025em;
  --text-title-3: clamp(1.375rem, 1.2rem + 0.8vw, 1.75rem);   --text-title-3--line-height: 1.2;
  --text-title-4: 1.25rem;    --text-title-4--line-height: 1.3;
  --text-body-lg: 1.125rem;   --text-body-lg--line-height: 1.7;   /* lectura */
  --text-body: 1rem;          --text-body--line-height: 1.6;
  --text-body-sm: 0.9375rem;  --text-body-sm--line-height: 1.5;   /* controles */
  --text-caption: 0.875rem;   --text-caption--line-height: 1.45;
  --text-label: 0.75rem;      --text-label--line-height: 1;  --text-label--letter-spacing: 0.14em;  /* mono, mayúsculas */
  --text-data: 0.9375rem;     --text-data--line-height: 1.4;  /* mono, tabular-nums */
  --text-hand: 1.625rem;      --text-hand--line-height: 1.15;
  --text-hand-lg: 2.75rem;    --text-hand-lg--line-height: 1;

  /* --- Espaciado (escala de 4px; v4 deriva p-1 = 4px…) --- */
  --spacing: 0.25rem;

  /* --- Radios (Chalk app) --- */
  --radius-sm: 4px;   /* chip, badge */
  --radius-md: 8px;   /* botón, input, fila */
  --radius-lg: 12px;  /* tarjeta, panel, dropdown */
  --radius-xl: 16px;  /* sheet, bloque destacado */

  /* --- Anchos y breakpoints --- */
  --container-read: 680px;
  --container-page: 1200px;
  --breakpoint-sm: 40rem;   /* 640 */
  --breakpoint-md: 48rem;   /* 768 */
  --breakpoint-lg: 64rem;   /* 1024 */
  --breakpoint-xl: 80rem;   /* 1280 */

  /* --- Motion --- */
  --ease-out: cubic-bezier(.2, .8, .2, 1);
  --ease-standard: cubic-bezier(.4, 0, .2, 1);
  --ease-in: cubic-bezier(.4, 0, 1, 1);
  --animate-skeleton: skeleton 1.4s linear infinite;
}

:root {
  /* v4 no tiene namespace de duración: variables CSS + utilidades duration-150/200/300 */
  --duration-fast: 150ms;   /* hover de color, nav, press */
  --duration-base: 200ms;   /* estados, chips, dropdown, acordeón */
  --duration-slow: 300ms;   /* segmented, barrido del primario, reveal, sheet, toasts, View Transitions */
  --duration-draw: 600ms;   /* trazos de tiza, barras, check de éxito (una vez) */
  --border-hair: 0.5px;     /* utilidad: border-[0.5px] */
  --ring: 0 0 0 2px var(--color-background), 0 0 0 4px var(--color-accent);
  color-scheme: dark;
}
```
Los componentes se escriben como clases en `@layer components` o como componentes Vue (`.btn`, `.btn-ghost`, `.btn-inline`,
`.link`, `.navlink`, `.card`, `.seg`, `.chip`, `.badge`, `.bar`, `.check`, `.field`, `.dd`, `.acc`, `.toast`, `.sk`, `.chalk-ul`,
`.chalk-circle`, `.label-mini`). El CSS de referencia está en el `<style>` de `design-system.html`.

### Escala tipográfica
| Token | Móvil → desktop | Uso |
| --- | --- | --- |
| `display` | 38 → 60 | H1 del hero |
| `title-1` | 34 → 48 | H1 de página y ficha |
| `title-2` | 28 → 36 | H2 de sección |
| `title-3` | 22 → 28 | Tarjeta destacada, H3 de artículo |
| `title-4` | 20 | Títulos de tarjeta y fila |
| `body-lg` | 18 / 1.7 | Lectura (artículos, reseñas, entradillas), máx. 680 px |
| `body` | 16 / 1.6 | UI general |
| `body-sm` | 15 | Botones, chips, segmented, menú |
| `caption` | 14 | Metadatos (`meta`) |
| `label` | 12 mono, .14em | Kickers, cabeceras de tabla, BARCELONA |
| `data` | 15 mono, tabular | Precios, notas, índices, horas, grados |
| `hand` / `hand-lg` | 26 / 44 Caveat | Notas del autor (≤ 2 líneas) y cabeceras de pizarra |

### Rejilla
Contenedor de 1200 px; gutter de 16 en móvil y 24 desde 768. Rejilla de 4 columnas en móvil y 12 desde `md`. Lectura a
680 px (artículo, reseña del autor); datos a ancho completo (tablas, comparador, listados). Ritmo de sección: 64 px en móvil
y 96 en desktop; 32 entre título y contenido. Por debajo de `md`, las tablas pasan a filas-ficha; las matrices de 4 o más
columnas hacen scroll interno con la primera columna fija.

### Componentes (estados documentados en la página)
| Componente | Estados |
| --- | --- |
| Botón primario / ghost / inline | default, hover, focus-visible, active, disabled, loading (`aria-busy`). El error va en el campo o en un toast |
| Enlace (editorial, acento, externo) | default, hover, focus-visible |
| Header + desplegable Guías | cerrado, abierto, ítem con foco, navlink actual; teclado completo; barra compacta |
| Menú móvil | bottom sheet abierto y cerrado, acordeón abierto y cerrado, foco atrapado |
| Footer | — |
| Tarjeta de artículo | default, hover, focus-visible, sin imagen, loading |
| Fila de rocódromo | default, hover, con visita invitada, sin dato, loading, fila-ficha móvil |
| Tarjeta de pie de gato | default, seleccionada para comparar, con "lo que aprendí", sin precio, tope de 4 (disabled) |
| Tabla / matriz | default, columna ordenada (`aria-sort`), vacío por filtros |
| Chips de filtro | default, hover, focus-visible, active, pressed, disabled |
| Segmented / tabs | seleccionado, hover, focus, teclado, disabled (`aria-disabled`) |
| Badges | visita invitada, afiliado, verificado, dato antiguo (> 6 meses), neutros, autor |
| Nota por criterios | autor, usuarios con ≥ 3, usuarios con < 3 (sin media), vacío |
| Newsletter | default, error (email y consentimiento), loading, éxito |
| Input / select / textarea | default, focus, error, disabled, ayuda, contador |
| Toast | éxito, info (se van a los 5 s), error (persistente, `role="alert"`) |
| Skeleton | artículo, rocódromo, opiniones, agenda (estático con reduced motion) |
| Estado vacío | agenda sin eventos, búsqueda sin resultados |
| Trazos de tiza | subrayado, círculo, flecha (≤ 1 por pantalla, `aria-hidden`) |
| Nota manuscrita | cita, "lo que aprendí", cabecera de pizarra |
| Encuentra compañero | rocódromo en la app (recuento bloqueado), lista de espera (default, loading, apuntado) |

### Logo y marca
| Versión | Archivo | Cuándo |
| --- | --- | --- |
| Logo completo, blanco | `logo-white.svg` (2073×384) | **Por defecto en el sitio**: header, footer, barra compacta en desktop, OG oscuras |
| Logo completo, oscuro | `logo-dark.svg` (#181818) | Fondos claros: emails, OG claras, PDF e impresos |
| Marca de barras | Sin archivo: las 4 barras del logo, `viewBox="0 22 315 338"`, `fill="currentColor"` (blanco) | Solo donde el logo completo no cabe: barra compacta en móvil. Mínimo 16 px |
| Isotipo naranja | `iso-chalk-white.svg` / `iso-chalk-dark.svg` | **Fuera de la interfaz**: favicon, iconos de app, avatar en redes. Nunca junto al wordmark, en el header ni en la barra compacta |

- **Nombre:** en textos, títulos, `alt` y metadatos, **ChalkGuide**. "chalkguide" en minúsculas solo existe dentro del logo. Nunca "ChalkGuide".
- **Unidad x** = ancho de una barra = 69/384 ≈ 0,18 × la altura del logo. **Área de respeto: 2x** (≈ 0,36 × alto) por los cuatro lados; 10 px con el logo a 28.
- **Mínimos:** logo completo, 20 px de alto (108 px de ancho; x-height del wordmark ≈ 9 px). Por debajo, la marca de barras (mín. 16 px).
- **Tamaños:** header 28 (desktop) / 22 (móvil) · barra compacta: logo a 20 (desktop) o barras a 24 (móvil) · footer 24 · OG 64–96.
- **BARCELONA:** no es parte del logo. Va en `label-mini` a la derecha, separada ≥ 2x (12 px en móvil, 16 en desktop), con su línea base
  alineada con la del wordmark. Esa línea base está al **19,2 %** de la altura del logo desde abajo:
  `align-items:flex-end` + `padding-bottom: calc(h × .192 − 2px)` (clase `.logo-tag`). Solo en header y footer; nunca con la marca de
  barras ni en la barra compacta. El enlace se anuncia "ChalkGuide Barcelona, inicio".
- **Equilibrio y acento:** el header queda monocromo a propósito (logo blanco a la izquierda, navegación al centro, idioma a la derecha).
  El naranja aparece donde hay acción o señal: subrayado del enlace activo, botón Newsletter de la barra compacta, kicker y CTA del
  hero, anillo de foco y badges de transparencia. Así cada pantalla tiene un solo punto naranja dominante, y es el útil.
- **No:** deformar, colorear el logo (tampoco en acento ni a `foreground`), juntar el isotipo naranja con el wordmark, usar la versión
  blanca sobre claro, ponerlo sobre una foto sin capa oscura, rotar, añadir sombras o efectos, rehacer el wordmark con Inter ni animar
  o separar las barras (salvo la marca de barras definida).
- En los mockups se referencian con `../../../public/brand/…`, así que para verlos hay que servir desde la raíz del repo.

### Accesibilidad y motion (reglas)
- Texto ≥ 4.5:1 (`foreground`, `meta`, `accent`, `*-text`); UI ≥ 3:1 (`control`). `hint` y `line` son solo decoración.
- Foco visible con `--ring` en todo; táctiles ≥ 44 px (el inline amplía su área con `::after`).
- Labels visibles; errores con icono + texto + `aria-invalid` + `aria-describedby` y foco al primer error.
- El color nunca va solo: las barras llevan cifra, los badges texto y los estados activos tick o forma.
- Teclado: skip link, desplegable (↓ ↑ Inicio Fin Esc), tabs (← →), sheet con foco atrapado y Esc.
- Motion: 150/200/300 + 600 (solo trazos y barras). Se animan color, opacity, transform, background-size y stroke-dashoffset.
  Nada en bucle salvo spinner y skeleton. Hover solo con `(hover:hover)` y nunca con información exclusiva.
- `prefers-reduced-motion: reduce`: duraciones a 0. Los estados ocultos (reveal, barras, trazos) solo existen con
  `no-preference` + JS, así que todo se ve igual. Sin View Transitions; spinner y skeleton estáticos.

---

## 8 · Páginas clave (F1.6) · en revisión

Mockups en [`pages/`](pages/), enlazados desde [`index.html`](index.html). Están construidos sobre el design system aprobado,
con los datos del seed (`supabase/seed/guide_dummy.sql`) y los textos de `i18n/locales/es.json` (F1.7). Para que cargue el logo,
hay que servirlos desde la raíz del repo. Cada página muestra arriba una barra de mockup con su ruta real ES/EN (§6).

**Base compartida (`pages/_shared/`)**
- `chalk.css`: CSS del design system más los añadidos de F1.6.
- `tw.js`: configuración de Tailwind.
- `layout.js`: header con el desplegable Guías, barra compacta, menú móvil, footer, iconos y la barra de mockup.
- `chalk.js`: comportamiento común (desplegable, sheets con foco atrapado, tabs y segmented, ordenación con View Transitions,
  chips, toasts, newsletter y lista de espera).

| Página | Archivo | Ruta | Notas |
| --- | --- | --- | --- |
| Rocódromos | `rocodromos.html` | `/rocodromos` | 5 publicados. Orden por nota, precio o principiante; 4 filtros; dato antiguo (> 6 meses) marcado; los 2 "en preparación" se nombran |
| Ficha de rocódromo | `rocodromo-ficha.html` | `/rocodromos/la-paret-de-gracia` | La única visita invitada del seed. Reseña dominante, aviso de transparencia, precios con fecha, instalaciones, índices, nota por criterios, 2 opiniones (sin media), Opinar → login, lista de espera |
| Resoladores | `resolar-pies-de-gato.html` | `/resolar-pies-de-gato` | 3 talleres; orden por nota, precio o plazo; filtro de envío por correo |
| Ficha de resolador | `resolador-ficha.html` | `/resolar-pies-de-gato/taller-goma-fina` | Reseña y criterios; opiniones vacías |
| Comparador | `pies-de-gato.html` | `/pies-de-gato` | 15 modelos; filtros (nivel, perfil, cierre, rango de precio, "los he usado yo"); hasta 3 lado a lado; afiliado marcado (`rel="sponsored nofollow"`); "Lo que aprendí" en los 3 que tiene Xavi |
| Blog | `blog.html` | `/blog` | 5 publicados; solo se muestran las categorías con artículos |
| Categoría | `blog-categoria.html` | `/blog/categoria/donde-escalar` | 2 artículos y la guía relacionada |
| Artículo | `blog-articulo.html` | `/blog/cuanto-cuesta-escalar-en-barcelona` | Prosa a 680 px con tabla, nota manuscrita, figura y cita; autor; relacionados; newsletter |
| Agenda | `agenda.html` | `/agenda` | Próximos ~60 días: octubre y noviembre como pizarras; filtro por tipo; solo eventos aprobados |
| Sobre mí | `sobre-mi.html` | `/sobre-mi` | Texto del seed; los huecos `[XAVI: …]` quedan marcados |
| Opinar | `opinar.html` | ficha `#opinar` | Diálogo (sheet en móvil): login con Google, formulario 1–5 × 7 criterios + texto, error de validación y de red, enviada, editar |
| Newsletter | `newsletter-confirmada.html`, `newsletter-baja.html` | `/newsletter/confirmada`, `/newsletter/baja` | Doble opt-in confirmado, enlace no válido y baja |
| Estados | `estados-vacios.html`, `404.html` | — | Vacíos, sin resultados, menos de 3 opiniones, error con reintentar y 404 real |

**Componentes añadidos al design system** (sección "Añadidos F1.6" de `design-system.html`): migas de pan, lista de datos
(`.dl-data`), rango de precio doble, nota 1–5, botón de Google, variante de diálogo, prosa editorial y bandeja de comparación.

**Pendiente de decidir (para el coordinador, loro-lola y jabali-javi)**
1. **Slug de categoría:** el seed usa `costos` / "Costos"; §6 decía `costes`. En España se dice "costes". Propongo cambiar el seed a `costes`; el mockup usa lo que hay en la BD.
2. **Máximo del comparador:** la página pide 2–3 y el mockup limita a 3, pero `es.json` dice "({count}/4)" y "Ya comparas 4 modelos." Hay que unificar.
3. **Textos que faltan en `es.json`:** "Guardar cambios" (editar opinión), "Elige al menos 2 modelos", "Este enlace ya no sirve" (opt-in caducado), "Quitar" (de la comparación), "Los he usado yo", "Precio sin confirmar" y las etiquetas de tipo de evento.
4. **Datos derivados ficticios:** los índices principiante y familia, las 2 opiniones de usuario y la lista de espera (12/20) son de ejemplo; el seed no los trae.
5. **Home (E):** sigue diciendo "14 rocódromos"; con el seed son 5. Se corrige en la implementación con datos reales.

---

## 9 · Superficies de lectura (3.18), ficha de pie de gato (3.17) y buscadores (3.19) · en revisión (iteración 2)

**Iteración 2 (08.10.26, D20 y D21):** [`iteracion-2.html`](iteracion-2.html) muestra cada pantalla nueva en iframes de tamaño real a 390 + 768, 1024 y 1440. Lo nuevo está en §9.9; las dudas abiertas, en §9.10.
Comparativa de la iteración 1: [`lectura-b-vs-c.html`](lectura-b-vs-c.html) (C y B lado a lado, a 1440, 768 y 390, en iframes de tamaño real).
Mockups en `pages/` (cada uno acepta `?modo=b` para ver la referencia B):
[`lectura-articulo.html`](pages/lectura-articulo.html) ·
[`lectura-comparador.html`](pages/lectura-comparador.html) ·
[`lectura-pie-de-gato.html`](pages/lectura-pie-de-gato.html) (3.17) ·
[`buscador-rocodromos.html`](pages/buscador-rocodromos.html) ·
[`buscador-blog.html`](pages/buscador-blog.html) (3.19) ·
[`home-hero.html`](pages/home-hero.html) (hero de la home, D20).
Base compartida nueva: `_shared/tw-vars.js` (Tailwind con colores en variables CSS), `_shared/lectura.css` (paleta clara, ámbito oscuro de la navegación, buscador) y `_shared/lectura.js` (modo).

### 9.1 · Decisión

Propuse dos opciones:
- **B · papel sobre pizarra.** La navegación y el resto de la interfaz siguen oscuros. Solo el cuerpo del artículo, la tabla del comparador y la ficha van sobre una "hoja" crema clavada en la pizarra (sombra y cinta de carrocero).
- **C · modo claro completo.**

**Xavi eligió C (08.10.26): tema claro para el sitio, con la navegación oscura.** La cabecera, la barra compacta, el menú móvil, el desplegable Guías y el pie son oscuros. B queda solo como referencia en la comparativa y no se implementa.

**Arquitectura de tokens (vale para coneja-lucky tal cual).** Los nombres semánticos no cambian (`background`, `board`, `foreground`, `meta`…). Cambian sus valores, por ámbito:
- `:root` = paleta clara (el sitio).
- `.chrome-dark` = paleta oscura actual (§5), redefinida como variables en ese elemento. Se aplica a `<header>`, a la barra compacta, al sheet del menú y a `<footer>`. Lo que va dentro (el desplegable, `UiButton`, los enlaces de navegación) hereda la paleta oscura sin tocar los componentes.
- En Tailwind v4: `@theme` con los valores claros + una regla `.chrome-dark { --color-background: #0f0f0f; … }` con los oscuros. Solo hay **dos tokens nuevos de verdad**: `accent-fill` y `chalk`. Aparte, la regla de que `accent` es para texto.

### 9.2 · Tokens (tema claro) con contraste AA medido (WCAG 2.x)

| Token | Claro | Oscuro (`.chrome-dark`, sin cambios) | Uso | Ratios (claro) |
| --- | --- | --- | --- | --- |
| `background` | `#F4F1EA` papel cálido | `#0f0f0f` | Fondo del sitio | — |
| `board` | `#FBF9F5` | `#1a1a1a` | Tarjetas, cajas, hero con rejilla | — |
| `elevated` | `#EBE6DC` | `#242424` | Hundido: campos, cabecera de tabla, hover de fila/tarjeta, badge | — |
| `line` / `line-strong` | `#DCD5C8` / `#C2B9A9` | `#2a2a2a` / `#333` | Separadores 0.5 px, **solo decorativos** | 1.3 / 1.7 |
| `control` | `#827A6D` | `#75716A` | Borde 1 px de campos, ghost, chips | 3.8 papel · 3.4 elevated · 4.0 board |
| `foreground` | `#1C1A17` tinta | `#F0EDE8` | Texto principal | 15.4 · 14.0 · 16.5 |
| `prose` | `#34302A` | `#DCD8D1` | Cuerpo largo (artículo, reseña) | 11.6 · 12.5 |
| `meta` | `#5E584E` | `#A19D94` | Secundario, fechas, etiquetas | 6.2 · 5.7 · 6.7 · 5.7 sobre accent-muted |
| `muted` | `#6B6559` | `#888880` | Placeholder | 5.1 · 4.65 elevated |
| `hint` | `#B5AC9C` | `#444440` | Solo decorativo ("·", asa) | 2.0 ✗ a propósito |
| **`accent`** | **`#9A4A16`** naranja tostado | `#E8923A` | **Texto y bordes de acento**: enlaces-acento, precios, kicker, `HandNote`, chip/badge activo | 5.5 papel · 5.0 elevated · 5.9 board · 5.0 accent-muted |
| **`accent-fill`** (NUEVO) | `#E8923A` (marca) | `#E8923A` | **Rellenos**: botón primario, checkbox, nota 1–5, rango, miniatura activa | `on-accent` sobre él: 7.9 |
| `accent-hover` | `#C4721F` | `#C4721F` | Barrido del primario | on-accent 5.3 |
| `accent-muted` | `#F7E4D0` | `#3a2010` | Fondo de chip activo, badge "afiliado"/"visita invitada", resaltado | tinta 14.0 |
| `on-accent` | `#1a0a00` | `#1a0a00` | Texto sobre `accent-fill` | 7.9 |
| **`chalk`** (NUEVO) | `#D2702A` | `#E8923A` | Trazo de tiza SVG y relleno de barras (decorativo, siempre con el número al lado) | 3.1 sobre papel (gráfico) |
| `success` / `success-text` / `success-muted` | `#17855F` / `#1A6E4E` / `#E3F0E8` | sin cambios | Icono / texto / fondo | icono 4.1 · texto 5.5 papel, 5.3 sobre muted |
| `danger` / `danger-text` / `danger-muted` | `#C23B37` / `#B02A25` / `#F8E1DE` | sin cambios | Ídem | 4.7 · 5.8 papel, 5.25 sobre muted |
| Foco (`--ring`) | `0 0 0 2px background, 0 0 0 4px accent` | ídem con oscuro | En claro, anillo `#9A4A16` | 5.5 sobre papel |
| Resaltado (`mark`) | fondo `accent-muted` + línea inferior 2 px `chalk` | `#3a2010` + `#E8923A` | Término buscado | texto heredado, 14.0 |
| Sombra | ninguna en contenido; solo la barra compacta: `0 1px 0 rgb(0 0 0/.35), 0 10px 24px -14px rgb(28 26 23/.55)` | — | Despegar la barra oscura del papel al hacer scroll | — |

**Regla de migración del acento (lo único que hay que tocar en componentes):** `bg-accent` → `bg-accent-fill` en el
primario, el checkbox, la nota 1–5, el rango, el relleno del rango y el `::selection`. Barras e `UiChalkStroke` → `chalk`. `text-accent`
y `border-accent` siguen igual: en claro ya dan AA. `prose` y `meta`, igual.

### 9.3 · Unión de la navegación oscura con el cuerpo claro

- **Cabecera:** fondo `#0f0f0f`, **sin filete inferior** (el contraste oscuro-claro ya hace de borde; un filete gris sobraba). El logo es siempre `logo-white.svg`.
- **Barra compacta (sticky):** `rgb(15 15 15/.9)` + blur 12 px. Al aparecer lleva la sombra corta de la tabla (solo cuando está visible), para que no parezca pegada al papel.
- **Desplegable Guías y menú móvil:** heredan `.chrome-dark`, así que son oscuros aunque floten sobre papel. El scrim del menú baja al 45 % de tinta (en claro, el 70 % negro era un apagón).
- **Hojas de contenido** (filtros móviles del buscador, diálogo Opinar): son contenido, no navegación, así que van **claras**.
- **Pie: oscuro** (recomendación). Hace de "suelo" igual que la cabecera hace de "techo": la página queda enmarcada en pizarra y el papel va en medio. En el artículo, la **newsletter se une al pie** en un único bloque oscuro (`.chrome-dark board-tex`). Al ser el final de la página, no crea franjas alternas.
- **Heros y portadas: claros** (recomendación). Usan `board` con la rejilla de pizarra invertida (líneas de tinta al 3,5 % / 2,2 %), como un papel cuadriculado. Si fueran oscuros, cada página tendría oscuro-oscuro-claro-oscuro y volverían las franjas. **Excepción: la home** (decidido, D20). Su hero es oscuro, va pegado a la cabecera y toma el color de la foto destacada (§9.9.3). El resto de la home es claro.
- **Fotos:** sin cambios de tratamiento. Sobre claro, el polvo de tiza baja del 35 % al 18 % y llevan un borde interior de 0.5 px `rgb(0 0 0/.12)`, para que las fotos claras no se fundan con el papel.
- **Trazo de tiza:** `chalk #D2702A`, más denso que el naranja de marca (que sobre crema se ve lavado). Sigue dibujándose una sola vez.
- **`HandNote` (Caveat):** en `accent #9A4A16`, ≥ 26 px, 5.5:1. La cita grande va en `foreground`. Igual que antes, nunca en párrafos.
- **Móvil:** misma lógica. La cabecera oscura de 64 px y el menú en bottom sheet oscuro; el resto, claro y a sangre.

### 9.4 · ¿Conmutador claro/oscuro y `prefers-color-scheme`? (decidido, D20)

**Solo claro en v1, sin conmutador ni `prefers-color-scheme`** (mi recomendación, aceptada por Xavi).
1. La decisión es editorial: Xavi quiere que lo que se lee y se compara esté en claro. Si el sistema forzara el oscuro, esa decisión se perdería justo en la mitad de los móviles.
2. Con dos temas hay que revisar el doble: fotos, gráficos, estados, contraste, capturas de OG y newsletter en cada pantalla nueva.
3. El sitio se prerenderiza. Un tema por preferencia pide un script inline antes del primer pintado y una cookie, o habrá parpadeo. Con un solo tema no hace falta.
4. Lo oscuro de la marca no se pierde: vive en la navegación, el pie y la newsletter.
5. La puerta queda abierta: como la paleta oscura ya existe como ámbito (`.chrome-dark`), añadir un oscuro opcional más adelante es aplicar ese ámbito a `<html>` y sumar un conmutador. Se puede hacer en una fase posterior si alguien lo pide.

### 9.5 · Ficha de pie de gato (3.17) · `/pies-de-gato/[slug]`

Datos de `shoes` (`docs/data-model.md`) + `author_reviews` + `user_reviews`. Mockup: Tarantulace (los tiene Xavi, con afiliado). Incluye un conmutador de estados solo del mockup: con reseña o sin ella, y 7, 2 o 0 opiniones.

| Bloque | Contenido | Notas |
| --- | --- | --- |
| Cabecera (hero claro con rejilla) | Migas · galería 4:3 + 4 miniaturas (`aria-current`, borde `accent-fill`) · marca (label) · modelo (H1) · resumen · badges (nivel, perfil, cierre, uso) · tira de 3 datos: **Precio** `price_min–max` + `price_checked_at`, **Nota del autor**, **Lectores** (media o "Sin media aún") · "Ver precio en {programa}" (ghost, `rel="sponsored nofollow"`, `aria-describedby` a la nota) · "+ Comparar" (inline, conecta con la bandeja del comparador) · nota de afiliado con badge | Sin botón primario: la compra no manda. El afiliado se marca **junto** al botón, no en el pie |
| Subnavegación | Mi reseña · Datos técnicos · Opiniones · Alternativas | "Mi reseña" se oculta si no hay |
| Reseña del autor (7/12) | Autor + "los uso desde 03.2024 · 2 resolados" · **tira de talla** (§9.9.4) · cita manuscrita · prosa (Lo bueno / Lo mejorable) · `HandNote learned` "Lo que aprendí" · tarjeta de nota por criterios (comodidad, precisión en canto, adherencia, durabilidad) · `HandNote` "Para quién" | Domina la ficha |
| Sin reseña | Tarjeta informativa "No los he usado" + enlace a opiniones + descripción breve | Nunca una nota vacía ni un "0" |
| Datos técnicos (5/12, sticky desde `lg`) | `dl-data`: horma, perfil, asimetría, cierre, goma, grosor (mm), rigidez (barra + `4/5`), uso, nivel · badge "del fabricante" · caja de precio (fecha, tiendas revisadas, botón de afiliado y aviso) · enlace al comparador | En móvil va después de la reseña |
| Opiniones | Botón "Opinar" · **≥ 3**: tarjeta con la media global (`overall_score`), reparto 5→1 (barras `meta`), media por criterio con nº de votos ("se promedia solo con quien lo puntuó") + lista (nota global en badge, criterios opcionales en mono pequeño si los hay) · **1–2**: aviso "mínimo 3" sin media · **0**: estado vacío "Escribir la primera" | La media de lectores nunca usa el acento: es de la comunidad, no del autor |
| Alternativas | 3 tarjetas del mismo nivel/perfil + "Abrir el comparador" | |

### 9.6 · Buscadores (3.19)

**Componente `UiSearchField`**: `input type="search"` con label visible (label-mini "Buscar"), icono de lupa, 48 px, fondo `elevated`, borde `control` y borde acento al enfocar, más el anillo. Lleva botón de borrar (44 × 44, `aria-label="Borrar búsqueda"`, solo con valor) y la pista `/` en un `kbd` (solo con puntero fino y el campo vacío). `role="search"` en el `form`, `enterkeyhint="search"`, `autocomplete="off"`.
Atajos: `/` enfoca (salvo si ya escribes en un campo); `Esc` vacía y, si ya está vacío, quita el foco.

**En las guías (rocódromos, resoladores, pies de gato), en cliente:**
- Filtra **al instante**, sin botón. Normaliza carácter a carácter (NFD, sin diacríticos, minúsculas), así que "gracia" encuentra "Gràcia" y se resalta el original. Varias palabras = todas deben aparecer (AND). Campos: nombre, tipo, barrio/ciudad y metro (resoladores: nombre, barrio, servicios; pies de gato: marca, modelo, goma).
- **Se combina con los filtros y el orden** (AND). El estado va en la URL: `?q=` + filtros, con `replaceState` y **`noindex`** cuando hay `q`.
- **Contador**: visible "3 de 5 rocódromos con «…»". Va en una región `aria-live="polite"` aparte, **con 400 ms de espera** para no anunciar cada tecla.
- **Resaltado** con `<mark class="hl">` en nombre y metadatos.
- **Sin resultados**: "Ningún rocódromo coincide con «…»". Si además hay filtros activos, lo dice ("Además tienes 2 filtros activos"), con botones "Quitar filtros" y "Borrar búsqueda" y sugerencias de barrio o línea de metro, y "¿Falta un rocódromo? Dímelo".
- **Desktop**: fila 1 con el buscador (máx. 420 px) a la izquierda y "Ordenar por" a la derecha; fila 2 con los chips; fila 3 con el contador y "Quitar filtros (n)".
- **Móvil**: buscador a todo el ancho; debajo, botón "Filtros (n)" que abre una **hoja clara** con los chips, "Quitar filtros" y un primario "Ver 3 rocódromos" con el recuento en vivo. Después, el orden. En pies de gato, el buscador va encima del acordeón de filtros que ya existe.

**En el blog (índice y categoría), contra la BD (full-text `es`/`en`, jabali-javi):**
- Buscador en la cabecera del blog (columna derecha desde `lg`, a todo el ancho en móvil), encima de los chips de categoría.
- Empieza con **2 caracteres** (con menos, pista "Escribe al menos 2 letras") y espera **250 ms** al escribir; `Enter` busca al momento. Si llega una respuesta antigua, se descarta.
- **Cargando**: título "Buscando «…»…", 3 filas en skeleton y `aria-busy` en la lista.
- **Resultados**: sustituyen a destacados y últimos. H2 "4 artículos con «…»" (también en `aria-live`). Cada fila lleva categoría (label), fecha y minutos (mono), título con resaltado y **fragmento de ~160 caracteres alrededor de la coincidencia, con resaltado** (equivale a `ts_headline`). Primero los que coinciden en el título.
- **En una categoría**: control segmentado "En Dónde escalar (n) / En todo el blog (m)". Si en la categoría no hay nada pero en el blog sí, se ofrece "Buscar en todo el blog".
- **Sin resultados**: nota manuscrita "Esto aún no lo he escrito", sugerencias en chips y "¿Quieres que escriba sobre ello? Cuéntamelo".
- **Error**: "No he podido buscar ahora mismo", con icono de error, `role="alert"` y "Reintentar" (con estado ocupado); la búsqueda se conserva.
- **Vacío** (sin texto): el blog de siempre.
- `?q=` en la URL y `noindex`.

### 9.7 · Para coneja-lucky (orden sugerido)
1. `main.css`: `@theme` con los valores claros de 9.2. Utilidad o clase `.chrome-dark` con los oscuros. Tokens `accent-fill` y `chalk`. `--ring` redefinido en los dos ámbitos.
2. `.chrome-dark` en el header, la barra compacta, el sheet del menú y el footer (y en la newsletter si va pegada al pie).
3. Migración `bg-accent` → `bg-accent-fill` (primario, checkbox, rating, rango, selección) y `chalk` en `UiIndexBar` y `UiChalkStroke`.
4. Repasar los hex fijos (`#DCD8D1`, `rgba(15,15,15,…)`, `rgba(26,26,26,…)` de la bandeja del comparador, el `text-white` del isotipo, la textura `board-tex` y el `photo-placeholder`) para que usen variables.
5. Ficha de pie de gato (9.5) y `UiSearchField` + buscadores (9.6).
Después, revisión de buho-pixel en 1440, 768 y 390.

### 9.8 · Decisiones de Xavi sobre la iteración 1 (D19–D21)
1. Hero de la home: **oscuro, pegado a la cabecera, con color según las fotos** (D20) → §9.9.3.
2. Newsletter: **bloque oscuro junto al pie + tarjeta clara a mitad de artículos largos** (D20) → §9.9.5.
3. Tema: **solo claro en v1** (D20).
4. Criterios de pies de gato: **sin cambios** por ahora (D20).
5. Ficha: **talla del autor frente a la de calle** en la reseña (D21) → §9.9.4.
6. Buscador del blog: **también en el cuerpo**, con fragmento resaltado (D21). Ya estaba así en el mockup (§9.6).
7. Comparador con buscador y **máximo 3** modelos, resuelto en móvil y tablet (D21) → §9.9.1.
8. Tarjetas de rocódromo con **foto, precio de día, familiar, variedad y dificultad** (D21) → §9.9.2.

### 9.9 · Iteración 2 (08.10.26) · aprobada (D22) con ajustes

> **D22 (08.10.26)**: Xavi aprueba todas las recomendaciones (hero A, tarjetas ordenadas por precio sin nota global ni índice principiante, grados frente a la media de Barcelona, nota de talla y newsletter) y añade el **dinamismo** de vías y bloques. Los ajustes están en §9.9.2 (tarjeta), §9.9.2.1 (ficha) y §9.9.5 (regla de la newsletter).

Vista por anchos: [`iteracion-2.html`](iteracion-2.html). Los mockups tocados son `lectura-comparador.html`, `buscador-rocodromos.html`, `home-hero.html` (nuevo), `lectura-pie-de-gato.html` y `lectura-articulo.html`. Iconos nuevos en `_shared/lectura.js`: `i-plus`, `i-swap`, `i-pause`, `i-play`, `i-ruler`, `i-home`.

#### 9.9.1 · Comparador de pies de gato (`/pies-de-gato`, sección "Lado a lado")

**Añadir modelos: `UiCombobox`** (patrón ARIA *combobox* + *listbox*), encima de la comparación.
- Label visible "Añadir un modelo" y placeholder "Busca por marca o modelo". Usa el mismo campo que `UiSearchField` (48 px, `elevated`, borde `control`), con `role="combobox"`, `aria-expanded`, `aria-controls` y `aria-activedescendant`.
- Al enfocar se abre la lista con los 15 modelos (orden marca + modelo). Al escribir se filtra en cliente: normalizado sin acentos, todas las palabras deben aparecer (AND), y busca en marca, modelo y goma. Las coincidencias van resaltadas con `mark.hl`.
- Cada opción mide ≥ 52 px: marca (13 px `meta`) y modelo (`font-medium`) a la izquierda, rango de precio en mono `accent` a la derecha. Si ya está en la comparación, `aria-disabled="true"`, badge "en comparación" y precio en `meta`.
- Teclado: ↓/↑ mueve la opción activa (fondo `elevated` + filete izquierdo `accent` de 2 px). `Enter` añade. `Esc` cierra la lista y, si ya está cerrada, vacía el campo. `Tab` cierra. Al hacer clic se conserva el foco (`mousedown.preventDefault`).
- Sin coincidencias: "Ningún modelo coincide con «…». Prueba con la marca (Scarpa) o la goma (XS Edge)."
- El recuento va en una región `aria-live="polite"` aparte ("3 modelos").

**Capacidad: máximo 3.**
- Junto al título hay un indicador "●●○ 2 de 3 modelos": 3 puntos de 8 px, rellenos con `accent-fill` los ocupados y con borde `control` los libres. Bajo el buscador va una pista: "Puedes añadir 1 modelo más" o "Comparación llena (3 de 3). Si eliges otro modelo, te pregunto cuál sustituir.".
- **Lleno + elegir otro** (desde el buscador o con "+ Comparar" en una tarjeta) abre un **diálogo de sustitución** (`sheet--dialog`: hoja inferior en móvil, modal desde `md`). Título "La comparación está llena", texto "Caben 3 modelos. ¿Cuál sustituyes por Scarpa Drago?" y 3 botones de 56 px "⇄ Sustituir Tarantulace · La Sportiva · 80–95 €", más "Cancelar". El foco va al primer botón. `Esc` o el scrim cancelan, y el foco vuelve a donde estaba.
- Tras sustituir: toast "Drago sustituye a Tarantulace", anuncio en `aria-live` y un **destello de 900 ms** (`accent-muted` → transparente) en la columna nueva. Con `prefers-reduced-motion` no hay destello.
- **Quitar**: botón "× Quitar" en la cabecera de cada modelo, con `aria-label="Quitar {modelo} de la comparación"`. Desde `lg`, el hueco libre se ve como una columna con el botón discontinuo "+ Añadir modelo · hueco 3 de 3", que enfoca el buscador, y celdas con un rayado muy tenue.
- **Menos de 2**: estado vacío "Tienes Tarantulace. Añade al menos otro modelo", con un chip del modelo (que se puede quitar) y el botón "+ Añadir un modelo".
- Estado en la URL: `?comparar=slug1,slug2,slug3` con `replaceState` (ya lo hace la app).
- La **bandeja inferior** ("3/3 · Tarantulace · Veloce · Defy · Ver comparación") se oculta mientras la comparación está a la vista (`IntersectionObserver`), para no apilar barras.

**Responsive (el problema de iPad y móvil).** Hay un solo componente con dos presentaciones y el corte en `lg` (1024):

| Ancho | Patrón | Detalle |
| --- | --- | --- |
| **≥ 1024** (desktop, iPad horizontal) | **Tabla** con columna de atributos (160 px) + 3 columnas iguales (`table-fixed`) | `thead` **pegajoso** bajo la barra compacta (`top: 56px`), con fondo `elevated`, y marca, modelo y "Quitar" en cada columna. Sin `overflow-x` (si no, el `sticky` no funciona) y sin scroll horizontal: a 1024 cada columna mide unos 245 px. |
| **768–1023** (iPad vertical) | **Vista por atributo**: cada atributo es un bloque con su label-mini y debajo una rejilla de N columnas (`repeat(N, 1fr)`, separación de 20 px) | Sin la columna de etiquetas, cada modelo gana unos 80 px. A 768 cada columna mide unos 200 px. Todo va en columnas, también "Lo que aprendí" y "Dónde comprar". |
| **< 768** (móvil) | La misma vista por atributo, con 3 columnas de unos 92 px a 390 y texto de 14 px. Los atributos **largos** ("Lo que aprendí", "Dónde comprar") se **apilan por modelo** (nombre del modelo encima y el texto a todo el ancho) | Así no hay scroll horizontal y los datos cortos (precio, perfil, cierre, goma, rigidez, nota, talla) siguen lado a lado, que es lo que se compara. En columnas estrechas, guiones automáticos (`hyphens:auto`, `lang="es"`). El desglose de la nota por criterios se oculta: queda la nota "4.0/5". |

- **Cabecera de modelos pegajosa** en < 1024: `position: sticky; top: 56px`, con fondo `elevated`. Al quedar fija (un centinela con `IntersectionObserver`), **se compacta**: oculta la marca y "Quitar" (transición de 200 ms con `grid-template-rows`) y deja solo los nombres, con una sombra corta. Así ocupa unos 44 px y siempre sabes qué columna es cuál.
- Lectores de pantalla: en la vista por atributo, cada valor lleva antes el nombre del modelo en `sr-only` ("Tarantulace: 80–95 €"). Cada atributo es una `section` con `aria-labelledby` a su título. En `lg` es una `table` de verdad, con `caption`, `th[scope]`.
- Descartados: el scroll horizontal sincronizado (en móvil oculta un modelo de cada 3 y obliga a deslizar en cada fila) y la vista "2 de 3 con selector" (no ves los 3 a la vez, que es justo lo que se pide).

**Fila nueva "Mi talla"** (también en el comparador, D21): "39,5" en mono y debajo "calzo 41 de calle", o "—" si no hay reseña. "Lo que aprendí" deja de llevar el título manuscrito dentro de cada celda (repetía la etiqueta de la fila) y pasa a texto `prose` con filete `accent` de 2 px.

#### 9.9.2 · Tarjetas de rocódromo (`/rocodromos`)

En **todos los anchos son tarjetas con foto** (la tabla de desktop desaparece): 1 columna en < 640, 2 desde `sm` (640–1023, incluido 768) y 3 desde `lg`.

Anatomía (`card` + `gym`, con `stretch` al enlace del nombre):
1. **Foto** de portada (`cover_media_id`), 16:9 en móvil y 3:2 desde `sm`, `object-cover`, `loading="lazy"`, con zoom al pasar el ratón (1.03, 600 ms). Si es visita invitada, lleva el **badge "visita invitada"** encima, arriba a la izquierda (`badge-accent`, contraste propio de 5.0:1 sobre cualquier foto).
2. **Nombre** (18 px, `font-medium`). Debajo, **2 líneas fijas**: "Tipo · barrio" y "🚆 metro" (icono `i-train`, `truncate`). Así las cuatro cifras quedan a la misma altura en todas las tarjetas de una fila.
3. **Tres datos "de valor" en una fila de 3 columnas** (en todos los anchos; separada por un filete `line`). Etiqueta de 13 px `meta` en una línea, cifra en mono 20 px y, debajo, el medidor:
   - **Entrada**: `price_day_eur`, "16,50 €" (coma decimal, espacio fino U+202F antes de €). La etiqueta visible es "Entrada" (con `sr-only` " de día") para que quepa en una línea a 768; la leyenda dice que es la entrada de día.
   - **Familiar**: `gym_indices.family_index` (1–5, un decimal), "4,6". **Medidor de 5 tramos** debajo (12 × 6 px, `chalk` encendido y `bar-track` apagado, con medio tramo para ,5). Decorativo: la cifra lleva `sr-only` " de 5".
   - **Variedad**: nota del autor en el criterio `variety` (entero 1–5), con el mismo medidor. **Sin reseña: "—" y debajo "sin reseña"** en `meta`, nunca un 0.
4. **Bloque "Cómo se escala"** (D22): las dos **escalas descriptivas** juntas y separadas de los datos de valor. Es un `dl` en una caja de papel (`background`, filete `line` 0.5 px, radio 8 px, padding 10/12 px) con **2 filas compactas** de 20 px: etiqueta (12 px `meta`, columna de 44 px) · regla de 64 px · palabra (13 px `foreground`, `truncate`).
   - **Grados** (`grading_difficulty`): Generosos · Algo generosos · En la media · Algo duros · Duros.
   - **Estilo** (`setting_dynamism`, nuevo): Muy técnico · Técnico · Mixto · Dinámico · Muy dinámico (propuesta; loro-lola la revisa, ver §9.9.2.2).
   - La regla: línea `line-strong` de 2 px, 5 marcas `control` de 2 × 8 px y un punto de tinta (`foreground`, 10 px, anillo de 2 px del color de la caja) en la posición 1–5 (`left: (v−1)·25 %`). **Sin acento ni verde/rojo, sin cifra**: no es mejor ni peor. `sr-only`: "Algo duros: 4 de 5, de generosos a duros" / "Dinámico: 4 de 5, de muy técnico a muy dinámico". Sin dato: "Sin dato" en `meta` y sin regla.
   - Por qué 2 filas y no una línea: a 768 y 390 la tarjeta mide ~280–340 px y "Grados ·—●— Algo generosos" + "Estilo ·—●— Muy dinámico" no caben lado a lado sin truncar. Dos filas de 20 px se leen como una ficha técnica y cuestan 52 px de alto.
   - No se ordena ni se filtra por estas escalas (no son notas). Si más adelante se quiere filtrar, serían chips de rango ("Grados generosos", "Estilo técnico"), nunca "mejor/peor".
5. Pie: "✓ verificado 20.09.26" (mono 12 px). Si tiene más de 6 meses: icono de reloj y "· puede haber cambiado".

- La **leyenda va una sola vez** encima de la lista (`details` "ⓘ Qué significa cada dato", cerrado por defecto), no en cada tarjeta. Dos grupos separados por un filete: (1) *Entrada*, *Familiar* (índice calculado, con enlace a la fórmula) y *Variedad* (mi nota); (2) **"Grados y Estilo no son notas: sirven para elegir."** Grados: frente a la media de Barcelona, de generosos a duros. Estilo: de técnico (pies, equilibrio, movimientos estáticos) a dinámico (saltos y coordinación). Cierre: "Ninguno es mejor. Si empiezas y quieres pasarlo bien, unos grados generosos te dejan encadenar más; el estilo depende de lo que te divierta. Es mi criterio tras visitarlos." (copy pendiente de loro-lola).
- **Ordenar por: Precio (por defecto, ascendente) · Familiar · Variedad**. Los que no tienen el dato van al final.
- Se quitan de la tarjeta la nota global del autor y el índice principiante (siguen en la ficha). El buscador, los filtros, el contador y los estados vacíos no cambian (§9.6).
- Contraste: `meta` sobre `board` 6.7:1 y sobre `background` 6.2:1 · marcas de la escala `control` sobre `background` 3.8:1 (UI ≥ 3) · punto `foreground` 15.4:1 · el medidor es decorativo y la cifra va al lado.
- Revisado a 1440 (3 columnas, tarjeta ~340 px), 768 (2 columnas, ~310 px) y 390 (1 columna, ~342 px): sin scroll horizontal, "Muy dinámico" y "Algo generosos" caben sin truncar en los tres.

#### 9.9.2.1 · Ficha de rocódromo: dónde van las dos escalas (D22)

Mockup: [`rocodromo-ficha.html#como-se-escala`](pages/rocodromo-ficha.html).
- **Sección propia "Cómo se escala aquí"** en la columna principal, **justo después de "Mi reseña" (tras la nota por criterios) y antes de "Precios y horarios"**. Está fuera de la reseña porque son datos del rocódromo (`gyms`): aparece aunque aún no haya reseña (si faltan las dos, no se pinta; si falta una, "Sin dato" en esa). Va arriba porque responde a "¿es para mí?" antes de mirar precios.
- `card` (`max-w-read`, padding 20/24 px). Cabecera: `h2.state-label` "Cómo se escala aquí" + a la derecha "No es una nota: sirve para elegir" (13 px `meta`).
- Dos escalas en 2 columnas desde `sm` (apiladas a 390). Cada una: etiqueta (14 px `meta`) a la izquierda y la palabra a la derecha (17 px `font-medium`); debajo la **regla a todo el ancho** (marcas de 2 × 10 px, punto de 14 px con anillo de 3 px del color de la tarjeta) y los **extremos rotulados** en 12 px `meta`: Generosos ↔ Duros · Técnico ↔ Dinámico.
- Pie con filete `line`: texto fijo (no depende del rocódromo) "Ninguna posición es mejor. Grados: frente a la media de Barcelona. Estilo: técnico es pies y equilibrio; dinámico, saltos y coordinación. Si empiezas y quieres pasarlo bien, busca grados generosos." + enlace "Cómo lo valoro".
- No se añade a la navegación interna de la ficha (es corta y está entre dos secciones que sí lo están). No se repite en el lateral "Datos clave" (un solo sitio).
- Mismos tokens que la tarjeta, válidos en tema claro y oscuro (`control` sobre `board` oscuro 3.6:1).

#### 9.9.2.2 · Etiquetas del dinamismo (propuesta para loro-lola)

| Valor | es (tarjeta y ficha) | en | Qué significa (para la leyenda y el panel) |
| --- | --- | --- | --- |
| 1 | Muy técnico | Very technical | Casi todo es de pies, equilibrio y lectura; movimientos estáticos |
| 2 | Técnico | Technical | Predomina lo técnico, algún movimiento amplio |
| 3 | Mixto | Mixed | Equilibrio entre técnica y movimientos dinámicos |
| 4 | Dinámico | Dynamic | Muchos lanzamientos, saltos y coordinación |
| 5 | Muy dinámico | Very dynamic | Abundan los saltos y los movimientos de coordinación tipo competición |

Etiqueta corta del dato: **"Estilo"** (en: "Style"). En masculino singular porque concuerda con "estilo". Alternativa si loro-lola ve choque con "Variedad": "Apertura" (más técnica, menos clara para principiantes). En el panel `/administrador` se edita con un control segmentado de 5 opciones con estas palabras, igual que los grados.

#### 9.9.3 · Hero de la home: oscuro con color de la foto (`/`)

Mockup [`home-hero.html`](pages/home-hero.html). En la barra del mockup puedes cambiar de variante, probar 4 fotos y ver los ratios medidos en vivo. Debajo va la home actual en tema claro (¿Por dónde empiezas?, rocódromos) y la newsletter oscura unida al pie.

**Dos direcciones:**

| | A · Ambiente (**recomendada**) | B · Rotación |
| --- | --- | --- |
| Qué es | Un destacado (el primer artículo `is_featured`) con su foto. El fondo del hero toma el color dominante de esa foto. Cambia cuando cambias el destacado. | Hasta 3 destacados que rotan cada 8 s con fundido. El fondo cambia de color con cada foto (700 ms). |
| Pros | Una pregunta y un CTA (la regla de §5.1). LCP estable (una imagen con `fetchpriority="high"`). Sin controles extra. Prerenderizable sin JS: el color viene de la BD. | Más movimiento y más "dinámico". Enseña 3 artículos. |
| Contras | La dinámica se nota entre visitas, no dentro de la misma. | Los carruseles se leen poco más allá del primero. Exige pausa visible (WCAG 2.2.2), pausa al pasar el ratón o con el foco, anuncio en `aria-live` y sin autoplay con `reduced-motion`. Más JS y peor LCP. |

**Recomiendo A.** Si Xavi quiere movimiento, B ya está resuelta con todos sus controles en el mockup (`?hero=b`).

**Composición:**
- Desktop (≥ 1024): 12 columnas. El texto ocupa 7 (kicker `accent`, H1 60 px con el trazo de tiza, entradilla, primario + fecha, filete y nota manuscrita del autor) y la foto 5 (4:5, radio 16 px, borde interior blanco al 8 % y sombra larga). El crédito va bajo la foto (mono 11 px, "Foto: Autor · Unsplash", con enlace).
- Tablet (640–1023): la foto arriba en 16:9 con radio, y el texto debajo.
- Móvil (< 640): la foto **a sangre** arriba (4:3), que se funde con el fondo en su 38 % inferior. El texto empieza debajo, nunca encima de la foto.
- Unión con la cabecera: el hero empieza en `#0f0f0f` (el color exacto de la cabecera) y pasa al color ambiental en 160 px, así que no hay costura. La rejilla de pizarra aparece con una máscara en esos mismos 160 px. Abajo, corte limpio al papel claro, igual que la cabecera.

**Color (cómo se calcula y por qué el texto siempre pasa AA):**
1. **Al subir la foto** (panel, en cliente con `canvas`, o en una Edge Function) se reduce a 48 × 48 y se pasa cada píxel a OKLab. Se descartan los casi negros (L < 0.18) y los casi blancos (L > 0.95). Se hace un histograma de **18 tramos de tono ponderado por croma^1.5**, y el tramo ganador da el tono `h` y la croma `C`. Si la foto es casi gris (croma media < 0.02), se usa un neutro cálido de marca (`h` 60°, `C` 0.012). El resultado se guarda en **`media.dominant_color`** (hex). El navegador no calcula nada.
2. Con ese color se derivan 3 tonos en OKLCH, con luminosidad fija y croma limitada:
   - `--amb-deep` = L 0.20, C ≤ 0.05: el fondo.
   - `--amb-mid` = L 0.25, C ≤ 0.065: la parte baja, **el punto más claro que queda bajo el texto**.
   - `--amb-glow` = L 0.40, C ≤ 0.11: el halo **solo detrás de la foto** (`radial-gradient(closest-side)` en el `::before` de la figura). Nunca queda texto encima.
3. **Garantía AA**: se mide el contraste de `meta #A19D94` (el texto más débil del hero) contra `--amb-mid`. Si baja de 4.5:1, se baja L en pasos de 0.01 hasta que pase. Con L 0.25 da, en las 4 fotos de prueba: **texto ≈ 13.6:1 · meta ≈ 5.9:1 · kicker `#E8923A` ≈ 6.5:1**. El primario (`accent-fill` con `on-accent`) no depende del fondo (7.9:1).
4. Las 3 variables se registran con `@property` (`<color>`), así el cambio de color se anima (700 ms, `ease-out`) en B o si cambia el destacado. Con `prefers-reduced-motion`, el cambio es instantáneo y B no rota sola.
5. Sin color guardado (fotos antiguas) se usan los valores por defecto (marrón tostado `#17120e` / `#211912` / `#5a3a22`, con los mismos ratios).

**Fotos dummy** (licencia Unsplash: uso libre, sin atribución obligatoria; la ponemos igualmente):

| Uso | Foto | Autor | URL |
| --- | --- | --- | --- |
| Hero · rocódromo (por defecto) | Escaladora en bloque de colores | Yns Plt | https://unsplash.com/photos/NY1D4Zni7fc |
| Hero · roca roja | Escalador en pared roja desplomada | Sean Benesh | https://unsplash.com/photos/VnmbcgAfL3Q |
| Hero · bosque | Bloque de granito en el bosque | Jeremy Vejgman | https://unsplash.com/photos/tMKfZRV_zj0 |
| Hero · mar | Techo de roca sobre el mar | Hu Chen | https://unsplash.com/photos/FZ0qzjVF_-c |
| Tarjeta · Presa Badalona | Bloque amarillo con presas de colores | Tofan Teodor | https://unsplash.com/photos/0dnZDy6QPl4 |
| Tarjeta · Altura Cornellà | Sala de bloque amplia | Nathan Cima | https://unsplash.com/photos/3Z95_0rAy88 |
| Tarjeta · Magnesi Poblenou | Desplome con presas rojas y verdes | Tofan Teodor | https://unsplash.com/photos/gi2dUvCUVB8 |
| Tarjeta · La Paret de Gràcia | Escalador visto desde abajo | Beta Boulders | https://unsplash.com/photos/wp12LpP5Dw8 |
| Tarjeta · Via Sants | Pared amarilla con presas pequeñas | David Pisnoy | https://unsplash.com/photos/Nqq240PifuI |

Las imágenes se sirven desde `images.unsplash.com` (con `?w=…&q=…&auto=format&fit=crop`) solo en los mockups. En producción, las fotos son de Xavi o se suben al bucket `media`, con `credit`.

#### 9.9.4 · Talla del autor vs. talla de calle (ficha de pie de gato)

- **Tira de 3 datos** (`dl`) bajo la línea del autor y antes de la cita: **Mi talla 39,5 · De calle 41 · Diferencia −1,5**. Va en mono 22 px, y la diferencia en `accent`, porque es lo que el lector se lleva. Debajo, una nota opcional de ajuste en `meta` 14 px ("Justos pero sin dolor en sesiones de dos horas. Tallas EU de La Sportiva."). Es una caja `board` con filete `line-strong` y radio 12 px, en 3 columnas también a 390.
- **Solo si hay reseña** (va dentro del bloque de reseña: sin reseña no aparece) y si las dos tallas existen. La diferencia se calcula, no se guarda.
- La prosa ya no repite los números ("talla y media por debajo de la de calle").
- Datos (ya aplicados por jabali-javi, D21): `shoes.author_size_eu` y `shoes.author_street_size_eu` `numeric(3,1)`, vacías si el autor no tiene el modelo; `size_note_es/en` pendiente de decisión de Xavi. También salen en el comparador (fila "Mi talla").

#### 9.9.5 · Newsletter: regla final (D20 + D22)

Mockup: [`lectura-articulo.html`](pages/lectura-articulo.html) (`#nl-mid`, `#nl-end` y `#newsletter`). Criterio: el estándar de los medios editoriales (CTA al final del post + una inserción a mitad en piezas largas + formulario del pie) y las pautas de Google sobre intersticiales intrusivos en móvil y Core Web Vitals.

**Tres superficies, ninguna intrusiva:**

| Superficie | Dónde | Cuándo | Aspecto |
| --- | --- | --- | --- |
| **Final de artículo** (`NewsletterEnd`, `#nl-end`) | Dentro de la hoja, **tras la firma del autor** y antes de "Sigue leyendo" | **En todos los artículos** | Tarjeta clara (`board`, filete `line-strong`, radio 12 px, línea interior superior de 2 px `accent-fill`), título 20/24 px: "¿Te ha servido? Una carta al mes con lo que cambia" |
| **A mitad** (`NewsletterInline`, `#nl-mid`) | Entre secciones, **antes del primer `h2` que empieza pasado el 40 % de las palabras** del cuerpo | Solo si el cuerpo tiene **≥ 1.000 palabras** (≈ 5 min a 200–220 palabras/min) | Misma tarjeta, título 20 px, texto contextual ("Cuando cambian los precios, te lo cuento") |
| **Pie** (`#newsletter`) | Último bloque antes del `footer`, en todas las páginas | Siempre | Bloque oscuro `chrome-dark board-tex` (sin cambios) |

**Umbral: 1.000 palabras, no 7 min.** Con 7 min (~1.400 palabras) se quedaban fuera las guías de 5–6 min, que son la mayoría y donde el final queda a 3–4 pantallas en móvil. Por debajo de ~1.000 palabras el bloque del final ya está a la vista enseguida y la tarjeta a mitad solo estorba. Se cuenta en palabras del cuerpo (sin tablas ni pies de foto), no en minutos, porque los minutos se redondean.

**Posición a mitad (algoritmo, en servidor):**
1. Contar las palabras de cada bloque del cuerpo.
2. Tomar el primer `h2` cuyo inicio cae **entre el 40 % y el 60 %** de las palabras e insertar la tarjeta justo antes.
3. Si no hay ningún `h2` en esa franja, el `h2` más cercano al 50 %, siempre que deje **≥ 350 palabras antes** (nunca en la primera pantalla) y **≥ 25 % del texto después** (que no quede pegada al bloque del final). Si ninguno cumple, **no se inserta**.
4. Nunca dentro de una tabla, lista, cita, figura ni entre un `h2` y su primer párrafo. **Una sola vez** por artículo.

**Reglas de SEO, UX y rendimiento:**
- **Sin pop-ups, modales, intersticiales, slide-ins, barras pegajosas ni exit-intent.** Nada tapa el contenido (Google penaliza los intersticiales intrusivos en móvil). El botón "Newsletter" de la cabecera es un enlace a `/newsletter`, no abre nada.
- **Formulario en el HTML del servidor** (SSR/prerender), con `action="/api/newsletter" method="post"`: funciona sin JS (mejora progresiva) y no se inyecta después de cargar. La tarjeta a mitad se inserta al renderizar el cuerpo en el servidor, no en cliente.
- **CLS 0**: las tres superficies ocupan su sitio desde el primer render. El estado de éxito **sustituye al formulario dentro de la misma caja sin cambiar su alto** (rejilla de una celda; el formulario pasa a `visibility:hidden`). Los errores aparecen tras una acción del usuario (no cuentan como CLS).
- **No ensucian el índice del artículo**: los títulos de las tarjetas son `<p>`, no `<h2>`, para no entrar en la tabla de contenidos ni en el esquema de encabezados. Las tarjetas son `<aside aria-labelledby>` con **`data-nosnippet`** para que su texto no salga en el fragmento de Google.
- **Consentimiento**: las tres llevan la misma casilla explícita, desmarcada, y registran fecha y origen (`source`: `article_mid`, `article_end`, `footer` + slug del artículo). Iniciar sesión con Google no es consentimiento.
- **Sincronización**: si se suscribe en una, las otras dos pasan a su estado de éxito y no lo vuelven a pedir en esa página. Sin cookies ni seguimiento para esto.
- Copy pendiente de loro-lola (es/en).

#### 9.9.6 · Datos nuevos (para jabali-javi; leona-lia revisa)
- `guide.gyms.grading_difficulty smallint null check (between 1 and 5)` (**ya aplicado**, D21): dificultad del grado, editable en el panel con las 5 etiquetas.
- `guide.gyms.setting_dynamism smallint null check (between 1 and 5)` (D22): 1 muy técnico – 5 muy dinámico, editable en el panel con las 5 etiquetas de §9.9.2.2.
- `guide.newsletter_subscribers.source` (o equivalente): admitir `article_mid`, `article_end` y `footer` + el slug de origen.
- `guide.media.dominant_color text null check (~ '^#[0-9a-f]{6}$')`: se rellena al subir o reemplazar la foto.
- Tallas: **ya aplicadas** como `guide.shoes.author_size_eu` / `author_street_size_eu` (D21); opcional `size_note_es/en` pendiente.
- Que el listado de rocódromos exponga en una consulta: `price_day_eur`, `family_index`, la nota `variety` del autor (o `null`), `grading_difficulty`, `setting_dynamism`, la portada (`storage_path`, `alt`, `width/height`) y `verified_at`.

#### 9.9.7 · Para coneja-lucky (después de que Xavi apruebe)
1. `UiCombobox` (reutilizable) + el diálogo de sustitución + la vista por atributo con cabecera pegajosa compactable en `ShoesComparator`. La tabla solo desde `lg`.
2. `GymsCard` con foto + `UiMeter5` + `UiScale5` (regla descriptiva genérica, con props `value`, `labels`, `size: 'sm' | 'lg'` y extremos opcionales) usada para Grados y Estilo. Fuera la tabla de desktop en `/rocodromos`. Leyenda en `details`. En la ficha, sección `GymsStyleScales` (§9.9.2.1).
3. `HomeHero` (variante A): variables `--amb-*` desde `media.dominant_color`, con las conversiones OKLCH en un util que se ejecute en servidor, `@property` en `main.css` y crédito de la foto.
4. `ShoeSizeStrip` en la reseña y fila "Mi talla" en el comparador.
5. `NewsletterInline` (a mitad, insertado en servidor con el algoritmo de §9.9.5) y `NewsletterEnd` (final de todos los artículos), con éxito de alto fijo y sincronización con el bloque del pie.
Revisión de buho-pixel a 1440, 1024, 768 y 390.

### 9.10 · Dudas para Xavi
Resueltas en D22 (hero A, orden por precio, grados frente a la media de Barcelona, nota de talla, newsletter). Quedan:
1. **Etiqueta "Estilo"** y las 5 palabras del dinamismo (§9.9.2.2): pendiente de loro-lola.
2. **Umbral de la tarjeta a mitad**: propongo 1.000 palabras en lugar de 7 min (§9.9.5).

## 10 · Fachada de vídeo "clic para cargar" (D26) · propuesta

Spec en [`video-facade.md`](video-facade.md) y mockup en [`pages/video-facade.html`](pages/video-facade.html). El marcador es `photo-placeholder` 16:9 sin miniatura de YouTube y todo el marco es el botón. Lleva un aviso en `figcaption` con enlace a `/cookies`, el fallback sin JS es un enlace a youtube.com y la carga se decide vídeo a vídeo, sin memoria.

## 11 · Fotos en opiniones de lectores (F6.11b) · propuesta

Mockups: [`pages/opinar-fotos.html`](pages/opinar-fotos.html) (formulario, con un selector de estados: sin fotos, subiendo, arrastrando, 3 de 3, errores, editar, enviada) y [`pages/opiniones-fotos.html`](pages/opiniones-fotos.html) (ficha con fotos aprobadas, "Tu opinión" y visor). Tema claro. El diálogo es el mismo `UiSheet`. No hay direcciones alternativas porque el patrón está muy acotado; se añade un bloque al formulario actual y no cambia nada más.

### 11.1 · Reglas
- **El texto se publica al momento (D30) y las fotos solo cuando Xavi las aprueba.** Lo dice un aviso fijo en el formulario, la pantalla de enviada y "Tu opinión".
- Máximo 3 fotos. Entrada: JPG, PNG, WebP o HEIC de hasta 20 MB. Se procesan en el navegador antes de subirlas: se aplica la orientación EXIF (`createImageBitmap(file, { imageOrientation: 'from-image' })`), se reduce a 2048 px por el lado largo y se recodifica en canvas a WebP (o JPEG si no hay WebP) con calidad 0,82, con un objetivo de 1,5 MB o menos. **Recodificar en canvas elimina el EXIF y el GPS.** Aun así, el servidor debe comprobarlo (eso es de jabali-javi y leona-lia).
- La foto se sube nada más elegirla, con progreso real. Si alguien envía con subidas en curso, el botón espera ("Terminando de subir 1 foto…"). Si una foto ha fallado, el envío se para con dos salidas: **Reintentar** o **Enviar sin esa foto**. Nunca se pierde el texto.
- Las fotos rechazadas no ocupan hueco. En el modo editar salen en una línea de texto, no como miniatura.

### 11.2 · Componente `ReviewsPhotos` (dentro de `ReviewsForm`, debajo del textarea)
| Parte | Spec |
| --- | --- |
| Encabezado | `fieldset` + `legend` "Fotos (opcional)" (`text-body-sm`), con el contador `N / 3` en mono `text-caption text-meta` a la derecha (`aria-hidden`, el estado se anuncia por la región viva). Ayuda debajo: límites (`text-caption text-meta`), enlazada con `aria-describedby` |
| Input | `<input type="file" accept="image/*" multiple>` en `sr-only` con `tabindex=-1`. Lo abre un `<button>`. **Sin `capture`**: así iOS y Android ofrecen cámara y galería |
| 0 fotos | Botón ancho con borde de 1 px discontinuo `control`, fondo `board` y radio `md`. Alto 56 px en móvil (icono y texto en fila) y 96 px desde `md` (en columna). Texto "Añadir fotos" y, solo con `(hover:hover) and (pointer:fine)`, "o arrástralas aquí" |
| 1–2 fotos | Rejilla `grid-cols-3 gap-2` de casillas cuadradas. La última casilla libre es "Añadir foto" (mismo estilo). Con 3 fotos desaparece |
| Miniatura | `aspect-square`, `rounded-md`, `object-cover` y borde interior `inset 0 0 0 .5px rgb(0 0 0/.12)`. Botón quitar en la esquina superior derecha: área de 44 px con un círculo de 28 px `rgb(28 26 23/.78)` y la X blanca. `aria-label="Quitar la foto 2 (IMG_2043.jpg)"` |
| Preparando | Imagen al 45 % con `blur(2px)`, spinner de 20 px y "Preparando" |
| Subiendo | Degradado inferior y "64 %" en mono 12 px blanco, con una barra de 4 px `accent-fill` sobre un carril blanco al 35 %. `role="progressbar"` con `aria-valuenow` |
| Error | Borde 1 px `danger-text`, fondo `danger-muted`, imagen al 25 %, icono de alerta y botón de texto **Reintentar** (alto 44 px). El motivo va en la lista de mensajes |
| Editar | Insignia abajo a la izquierda (22 px de alto, 12 px, peso 500): **En revisión** (`board`/`foreground` con reloj) o **Publicada** (`success-muted`/`success-text` con check) |
| Arrastrar | `.is-over`: borde de 1,5 px `accent`, fondo `accent-muted` y texto `accent`. Si ya hay fotos, una capa dice "Suelta para añadir · te queda N". Todo el diálogo hace `preventDefault` en `dragover`/`drop`, para que el navegador no abra el archivo |
| Mensajes | `ul` con `aria-live="polite"` debajo de la rejilla, 14 px, icono más texto, y el nombre del archivo en peso 500. Errores en `danger-text` y avisos en `meta`. Se limpian en la siguiente acción |
| Aviso | Caja `elevated` `rounded-md p-3`, 13 px `meta`, con la primera frase en `foreground` 500 (revisión, ubicación quitada, solo fotos propias y sin caras reconocibles). Enlazada al `fieldset` con `aria-describedby` |

Textos de error (pendientes de loro-lola, es/en): no es una foto · pesa N MB (máximo 20) · no puedo abrir HEIC en este navegador · no se ha subido (conexión) · solo caben 3 (he dejado fuera X) · ya tienes 3.

**Foco y anuncios:** al quitar una foto, el foco pasa a la siguiente X o al botón Añadir, y se anuncia "Foto quitada. Tienes 1 de 3". Al reintentar, el foco va a la X de esa foto. Al añadir, se anuncia "2 fotos añadidas. Tienes 2 de 3". Con el envío bloqueado, el foco va a la alerta.

**Motion:** 120–200 ms en borde, fondo y escala (`active: scale(.98)`/`.92` en la X). Con `prefers-reduced-motion`, el spinner queda estático y no hay transiciones.

### 11.3 · Enviada y "Tu opinión" (`ReviewsMine`)
- Enviada con fotos: debajo del texto actual, una caja `elevated` con 2 miniaturas superpuestas de 44 px y el texto "Tus 2 fotos, en revisión. Salen en la ficha cuando las apruebe. Hasta entonces solo las ves tú."
- "Tu opinión": miniaturas iguales que las públicas. Las que están en revisión no se pueden pulsar, van con la imagen al 55 % y una franja inferior "En revisión" (`board`, 11 px). Debajo, "Las fotos en revisión solo las ves tú…". Las publicadas abren el visor.

### 11.4 · Ficha pública (`ItemsOpinions`)
- En cada opinión, después del texto y antes de la línea de criterios: `ul.rv-thumbs` (`flex gap-2`) con miniaturas de **72 px** (88 px desde `md`), `rounded-md` y borde interior de 0,5 px. Cada miniatura es un `<button>` con `aria-label="Ver foto 2 de 3 de Marta G."`, hover `scale(1.04)` en 200 ms y anillo de foco. Las imágenes van con `loading="lazy"` y `@nuxt/image` a 176 px (2x). Una opinión sin texto pero con fotos es válida.
- No cambia el peso de las opiniones frente a la reseña del autor: las miniaturas son pequeñas y no hay galería de lectores arriba (ver dudas).
- **Visor:** `dialog` a pantalla completa con fondo `#0f0f0f` sólido (la foto manda, como la navegación oscura). Cabecera de 64 px con "Fotos de Marta G.", fecha mono más ficha en `#A19D94`, contador "2 / 3" y cerrar (44 px). La imagen va con `object-contain` y `max-height: calc(100dvh - 140px)` (168 px en móvil). Pie de foto: "Subida por Marta G., no por ChalkGuide" (transparencia). Anterior y siguiente: círculos de 44 px a los lados desde `md` y en una barra inferior de 72 px en móvil. Con 1 foto se ocultan el contador y la navegación. Teclas ← → y Esc, deslizar con más de 48 px, foco atrapado que vuelve a la miniatura, `alt` = "Foto 2 de 3 de Marta G. en La Paret de Gràcia". Entrada con opacidad y `scale(.98→1)` en 200 ms, sin animación con reduced motion.
- El HTML en caché (ISR) solo lleva fotos aprobadas. Las pendientes del propio usuario van en `<ClientOnly>`, como `ReviewsMine`.

## 12 · Home v2: del hero hacia abajo · propuesta (pendiente de Xavi)

Mockups: [`pages/home-v2.html`](pages/home-v2.html) (con «Ver notas de composición» y dos anexos), [`pages/pies-de-gato-poster.html`](pages/pies-de-gato-poster.html) y [`pages/newsletter.html`](pages/newsletter.html). Datos reales de la home y de `/pies-de-gato`; el hero es una captura. Verificado en Chrome a 1440, 1024, 768 y 390: sin scroll horizontal.

**No cambian:** hero, carrusel, intro, cuerda, cabecera, menú móvil y paleta. No hay direcciones alternativas porque Xavi ya fijó el rumbo.

### 12.1 · Composición y orden

| # | Sección | Fondo | Composición |
| --- | --- | --- | --- |
| 1 | ¿Por dónde empiezas? | `background` | Título y control a la izquierda; índice de tres filas a la derecha, sin tarjetas |
| 2 | Rocódromos | `elevated` | Título a todo el ancho; tabla en placa `board`. El orden vive en las columnas (`aria-sort`); en móvil, segmentado y filas-tarjeta |
| 3 | Chalk app | `background` | Pizarra de ejemplo a la izquierda; texto y botón secundario a la derecha |
| 4 | Pies de gato | `chrome-dark` + polvo | Título centrado como el H1 del hero; nota del autor grande; placas como cabecera de la tabla |
| 5 | Blog | `background` | Artículo principal a la izquierda; título y dos filas a la derecha |
| 6 | Newsletter | `field-orange` + polvo | Título a todo el ancho a 72 px; promesa a la izquierda; formulario en placa de papel a la derecha |
| 7 | Pie | `chrome-dark` | Promesa de transparencia y tres listas |

**Cambio de orden: Chalk app sube tras Rocódromos.** Habla de ellos, y deja de competir con la newsletter. Así el blog, donde más se oye la voz del autor, lleva directamente a la carta. Como el hero no lleva CTA (D38), el camino a la newsletter hasta llegar al final es el dock de D43 (§12.6). El componente deja de depender del nombre de un rocódromo, así que funciona aunque la tabla no cargue. `data-nav-section` no cambia: rocódromos, pies de gato y blog siguen en el mismo orden relativo.

**Sin datos:** cada sección conserva su `v-if` actual. Sin nota del autor desaparece la cita. Con 2 artículos: principal y una fila; con 1: solo el principal. Sin portada: `photo-placeholder` con el título encima (anexo 2).

### 12.2 · Tokens nuevos para `@theme` y `:root`

```css
@theme {
  --text-section: clamp(2rem, 1.55rem + 2.4vw, 3.75rem);      /* 34 px en 390, 59 px en 1440 */
  --text-section--line-height: 1.04;
  --text-section--letter-spacing: -0.02em;
  --text-section-lg: clamp(2.375rem, 1.6rem + 3.6vw, 4.5rem); /* 40 px en 390, 72 px en 1440: solo la carta */
  --text-section-lg--line-height: 1.04;
  --text-section-lg--letter-spacing: -0.02em;
  --radius-slab: 6px;                                          /* placas destacadas, como el hero */
  --color-on-field-meta: #3d2008;                              /* secundario sobre naranja */
}
:root {
  --shadow-slab: 0 1px 0 #d6cfc1, 0 2px 0 #c9c1b1, 0 3px 0 #b8afa0, 0 22px 34px -22px rgb(28 26 23 / .5);
  --shadow-slab-dark: 0 1px 0 #c8c0b1, 0 2px 0 #8e8678, 0 3px 0 #5c564b, 0 28px 44px -22px #000;
  --shadow-slab-ink: 0 1px 0 #2a2a2a, 0 2px 0 #3a3733, 0 3px 0 #4d4942, 0 18px 26px -20px rgb(28 26 23 / .55);
}
```

- **Utilidades:** `title-section` y `title-section-lg` (`font-display`, 700, `font-stretch: 125%`, mayúsculas, `text-wrap: balance`); `slab`, `slab-dark` y `slab-ink`; `dust` (el ruido de `.hero-ground`, sin máscara).
- **Ámbito `.field-orange`,** igual que `.chrome-dark`: `--color-foreground` y `--color-accent` a `#1a0a00`, `--color-meta` a `#3d2008`, y `--ring` con hueco naranja. Dentro de la placa, `.on-paper` devuelve la paleta clara para que errores, casilla y enlace sigan pasando AA.
- **Botón `ink`:** `UiButton variant="ink"` (`#1c1a17` y `#fbf9f5`, 52 px). Un primario naranja sobre placa dentro de un campo naranja parece un agujero.
- **`--text-display`:** ningún componente lo usa. Se retira y deja de existir el tope de 60 px.
- **`--font-display`:** el comentario de `main.css` pasa a citar D40. El `@font-face` sale de `hero.css` a `main.css`, porque ya no es solo del hero. Son 90 KB: conviene precargarlo y medir el CLS del cambio de fuente en los títulos.

### 12.3 · D40 ampliada (texto para `docs/PLAN.md`)

> | D40 | Tipografía de display | Archivo Expanded en negrita (700, `font-stretch: 125%`, mayúsculas) solo para títulos de presencia: H1 del hero, fecha del evento, enlaces del menú móvil, baldosa de la tarjeta del menú de escritorio, títulos de sección de la home, H1 de los listados y de `/newsletter`, y nombre del póster de pies de gato sin foto. Nunca en cuerpo de texto, títulos de tarjeta o de artículo, datos ni botones. Excepción a la regla «sin negrita» del design system | ✅ |

El menú móvil y `NavPreviewCard` ya usan Archivo sin que D40 lo recoja: esta redacción lo regulariza. Los dos usos nuevos son los títulos y el póster.

### 12.4 · Reglas transversales

- **Color:** un campo naranja a sangre, el de la newsletter, porque es el objetivo del producto y cierra la home en naranja y negro. `#fbf9f5` deja de ser fondo de sección y queda para placas; el segundo fondo es `elevated`, un paso claramente visible frente a papel (1,10:1 frente a 1,07:1) y frente a la placa (1,18:1). `board-tex` se mantiene en las cabeceras internas, que no se recomponen.
- **Mono:** solo precios, notas, índices, numeración y fechas numéricas. Salen de mono las etiquetas de columna, las etiquetas `UiBadge` (un cambio de clase, afecta a todo el sitio), la línea «Precios verificados», los títulos del pie y el copyright. `label-mini` sigue en el hero y en las migas de pan.
- **Etiquetas sobre títulos:** se quitan «Rocódromos», «Pies de gato», «Chalk app» y «Newsletter mensual». La categoría del artículo se queda, en Inter.
- **Materia:** radio de 6 px y grosor por sombra en tabla, placas de pie de gato, pizarra, artículo principal, miniaturas y formulario. Sin borde de 0,5 px en esas piezas. Botones e inputs siguen en 8 px.
- **Nota del autor:** `ItemsScore` gana una variante grande (32 px, 24 en móvil). La mejor nota lleva el círculo de `UiChalkStroke`, y se queda en esa fila aunque se reordene.
- **Motion:** sin cambios. 150–200 ms en estados, 300 ms de reordenación y `prefers-reduced-motion` global.

### 12.5 · Chalk app: el ejemplo se ve como ejemplo

- El nombre real del rocódromo y la fecha de hoy desaparecen, y `PREVIEW_OTHERS` deja de presentarse como dato.
- La palabra «Ejemplo» va en una etiqueta clara dentro de la pizarra, y debajo se repite en texto: «Pizarra de ejemplo: el día y la cifra no son reales».
- El título se parte: «¿Vas solo?» es el H2 y el resto pasa a la entradilla. El botón pasa de primario a `ghost`.

### 12.6 · `ScrollDock` (D43) frente a esta propuesta

| Cambio previsto | Encaje |
| --- | --- |
| Ocultarlo con `#newsletter` en pantalla | **Necesario.** Naranja sobre naranja se pierde. Debe seguir oculto en el pie: la condición es «la parte superior de `#newsletter` ya ha entrado», no «se está intersectando» |
| Rutas `/newsletter*` | **Falta.** Allí no hay bloque, así que el dock enlaza a la página en la que ya estás. Debe ocultarse |
| Reducirlo a isotipo | **Choca en parte.** D43 aprobó isotipo + Newsletter, y es el único camino visible a la carta en la home porque el hero no lleva CTA. Propuesta: desde `lg` se conserva la palabra; por debajo, solo isotipo |
| Posición en móvil | **Ajuste propuesto.** Arriba a la izquierda y sin viaje al centro, la columna libre de la barra. Puede pasar por encima de un título durante el scroll, pero no cubre el contenido central |

### 12.7 · Newsletter: `/newsletter` y estados

- **Una sola lógica:** extraer de `FooterNewsletter` un `NewsletterSignup` con `useNewsletterForm(source)`, y usarlo en el bloque y en la página. El texto de consentimiento sigue saliendo de `site_settings`.
- **`newsletterBlock: false`:** la página pone su propio campo naranja, así que nunca hay dos.
- **`source`:** la RPC y el `CHECK` no aceptan un origen nuevo, y usar `footer` falsearía el registro. Resuelto: `newsletter_page` ya existe en la RPC y el `CHECK`, y la página lo usa.
- **Contenido:** promesa, qué llega y cómo funciona, todo a partir de textos existentes. Sin cartas pasadas, cifras ni testimonios. Cuando exista una carta real, irá en esta página.
- **Estados** (anexo de `newsletter.html`): reposo, email no válido, falta la casilla, enviando, error del servidor, sin texto de consentimiento y éxito. La validación es al enviar, con foco en el primer error. Errores con icono, texto y `aria-describedby`. El éxito conserva el alto de la placa y usa `.success-check`; en la página añade un siguiente paso («Mientras tanto, leer el blog»).
- **Copy para loro-lola (es/en):** los pasos de «Cómo funciona», «Te escribo una vez al mes» como firma, la partición de «¿Vas solo?», el pie de la pizarra y la promesa como lema del pie, que sustituye a los `[Dummy]`.

### 12.8 · Revisión de `newsletter-confirmada.html` y `newsletter-baja.html`

**Veredicto: sirven como estructura y no hace falta rehacerlos.** Lo que falla es sobre todo la implementación, que usa `PagePlaceholder` en las dos rutas. Al implementarlos, aplicar estos cambios:

| Pantalla | Cambio |
| --- | --- |
| Las dos | Los mockups usan la paleta oscura de `_shared/tw.js`, anterior a D20. Implementar en tema claro, con los tokens actuales |
| Las dos | H1 con `title-section`. «SUSCRIPCIÓN» cabe en 390 (unos 296 de 358 px) |
| Las dos | Los enlaces de volver a apuntarse van a `/newsletter`, no a `#newsletter`: estas rutas no tienen bloque |
| Confirmada | Usar `.success-check` de `main.css`. Quitar la etiqueta «Newsletter mensual» y pasar la tarjeta lateral a `slab`. Sus tres puntos, con la misma redacción que «Qué te llega» |
| Confirmada | Mantener el primario «Ver los rocódromos» y el secundario «Leer el blog»: son el siguiente paso que falta hoy |
| Confirmada | El enlace caducado no es un recuadro discontinuo: con `?status=expired|invalid` sustituye a toda la pantalla, con su H1, icono de alerta y «Apuntarme de nuevo» |
| Baja | El H1 depende del estado. Hoy dice «Baja confirmada» también con enlace no válido o error, y se contradice. Faltan en el mockup enviando, no válido y error con reintento, que ya existen en `unsubscribed.vue` |
| Baja | No celebrar ni insistir: se mantiene «Hasta pronto» y solo botones secundarios, sin check animado |

`FooterNewsletter` repite con clases sueltas la animación del check: debe usar también `.success-check`.

### 12.9 · Contraste medido (WCAG 2.x)

Auditoría en navegador del color calculado de 568 nodos de texto sobre fondo sólido en los tres mockups: ninguno por debajo de AA. El texto sobre foto queda fuera de la medida automática; se mantiene el degradado actual. `#fbf9f5` sobre naranja da 2,32:1, por eso sobre el campo solo se usa tinta.

| Par | Ratio |
| --- | --- |
| `#1a0a00` sobre naranja | 7,91:1 |
| `#3d2008` sobre naranja | 6,11:1 |
| `#fbf9f5` sobre botón `ink` | 16,51:1 |
| `#5e584e` sobre `elevated` | 5,66:1 |
| `#9a4a16` sobre `elevated` | 5,02:1 |
| `#a19d94` sobre `#0f0f0f` | 7,09:1 |
| `#e8923a` sobre `#3a2010` (etiquetas en oscuro) | 6,17:1 |
| `#1c1a17` sobre tray (póster) | 14,60:1 |
| `#5e584e` sobre tray (marca) | 5,92:1 |
| Borde `control` sobre `elevated` / papel / `board` (UI) | 3,41 / 3,76 / 4,03:1 |

### 12.10 · Para coneja-lucky (después de que Xavi apruebe)

1. Tokens, ámbito y utilidades de §12.2; D40 en `PLAN.md` (lo actualiza SúperXavi).
2. Póster en `ShoesPhotoTile` ([spec](pages/pies-de-gato-poster.html#spec)), que además arregla `/pies-de-gato`.
3. Secciones de la home, en el orden de §12.1. Títulos de listados con `title-section`, quitando su `max-w`.
4. `NewsletterSignup` y `/newsletter`, y después confirmada y baja (§12.8). Antes, `newsletter_page` con jabali-javi y leona-lia.
5. Fuera de esta propuesta y aún abierto, de la crítica: los enlaces de `ProfilePaths` no coinciden con sus títulos.

---

## 13 · Editorial v2: artículo, blog, agenda y Sobre mí (D47–D49) · propuesta (pendiente de Xavi)

Mockups en `pages/`: [`editorial-v2.html`](pages/editorial-v2.html) (índice), [`articulo-v2.html`](pages/articulo-v2.html), [`blog-v2.html`](pages/blog-v2.html), [`blog-categoria-v2.html`](pages/blog-categoria-v2.html), [`agenda-v2.html`](pages/agenda-v2.html) y [`sobre-mi-v2.html`](pages/sobre-mi-v2.html). Estilos compartidos en `pages/_editorial-v2/` (`ev2.css` marca con «NUEVO» lo que pasa a `main.css`). Panel: [`../admin/editor-bloques-editoriales.html`](../admin/editor-bloques-editoriales.html). Cada mockup tiene «Ver notas» y anexos de estados. Verificado en Chromium headless a 1440, 768 y 390: sin scroll horizontal en ninguno.

**No cambian:** hero, cabecera, menú móvil, dock, bloque naranja, pie, paleta e isotipo. Una sola tipografía de texto (Inter); Archivo solo en H1 de listados, meses y fechas de evento (D40, D49).

### 13.1 · Qué sustituye a qué

| Nuevo | Sustituye | Se conserva |
| --- | --- | --- |
| `articulo-v2.html` | `lectura-articulo.html`, `blog-articulo.html` | `video-facade.html` (D26) como spec de la fachada |
| `blog-v2.html` | `blog.html` | `buscador-blog.html` para la lista de resultados |
| `blog-categoria-v2.html` | `blog-categoria.html` | |
| `agenda-v2.html` | `agenda.html` | La pizarra (`MonthBoard`) sigue solo en la home |
| `sobre-mi-v2.html` | `sobre-mi.html` | |

### 13.2 · Reglas de composición

1. **Dos familias de página.** Las piezas con voz (artículo y Sobre mí) abren en un **campo de tinta** que continúa la cabecera del sitio, con título en Inter 500. Los listados (blog, categoría, agenda) abren en **papel**, con H1 en Archivo. La foto principal de las piezas con voz cruza la costura entre tinta y papel.
2. **Dos ejes desde 1100 px:** carril de 240 px + 48 de calle + columna de lectura de 640. La firma de la cabecera, el índice y los pies de las imágenes anchas viven en el carril o en el eje de la columna; nada flota fuera de esos dos ejes. Entre 768 y 1099, todo se centra en el eje de 640. En 390, márgenes de 16.
3. **Fórmulas de oficio aplicadas:** columna de 60–75 caracteres; párrafos con un hueco de unos 1,25 em; títulos con más aire encima que debajo (proximidad); imágenes que respiran 40 px; una sola acción primaria por bloque; filas con la información en el orden en que se busca (cuándo → qué → cuánto → enlace).
4. **Mono** solo en datos: precios, horas, notas, cifras, minutos de lectura y fechas numéricas. La fecha del artículo se escribe en palabras («3 de noviembre de 2026»). **Sin etiquetas sobre títulos** que repitan lo que ya dice la miga o la página: en el artículo y dentro de una categoría no hay etiqueta de categoría.
5. **Miga móvil:** solo el padre con flecha («← Costes»). El título no entra nunca en la miga, tampoco en escritorio (sigue en el JSON-LD).

### 13.3 · Escala de lectura (medida en navegador)

| | 1440 | 768 | 390 | Auditoría (antes) |
| --- | --- | --- | --- | --- |
| Cuerpo | 19 / 31,4 (1,65) | 18,8 / 31 | 18 / 28,9 (1,6) | 18 / 30,6 |
| Columna | 640 px | 640 px | 358 px | 680 |
| Caracteres por línea | 61 | 62 | 37 | 74 / 36-37 |
| H2 | 34, aire 72 / 20 | 29, 72 / 20 | 26, 56 / 16 | 28, 56 / 20 |
| H3 | 22, 40 / 12 | 21, 40 / 12 | 20, 32 / 10 | 20, 32 / 20 |
| Imagen | 40 / 40, pie a 12 | igual | igual | 20 |
| Cita | 28 / 1,25 | 26 / 1,25 | 22 / 1,25 | 20 / 26 |
| Título | 64 / 1,04 | 47 | 36 | 48 |

La escala de partida se valida. En 390 quedan 37 caracteres por línea: es el borde bajo de lo cómodo, pero bajar a 17 px pesa más en lectores de más edad. Se mantiene 18. H2 frente a H3 en móvil: 26 frente a 20 (antes 22 frente a 20).

### 13.4 · Tokens nuevos (solo estos)

```css
@theme {
  --container-prose: 640px;                                    /* columna de lectura (sustituye a read: 680 en artículos y páginas) */
  --text-read: clamp(1.125rem, 1.08rem + .2vw, 1.1875rem);     /* 18 → 19 */
  --text-read-h2: clamp(1.625rem, 1.4rem + .9vw, 2.125rem);    /* 26 → 34 */
  --text-read-h3: clamp(1.25rem, 1.17rem + .3vw, 1.375rem);    /* 20 → 22 */
  --text-quote: clamp(1.375rem, 1.1rem + 1.1vw, 1.75rem);      /* 22 → 28 */
  --text-article-title: clamp(2.25rem, 1.6rem + 2.8vw, 4rem);  /* 36 → 64 */
}
```

Sin colores nuevos. Utilidad nueva `hit` (padding vertical de 11 px en enlaces en línea, con `background-origin: content-box`): llega a 44 px sin mover la línea. `main { overflow-x: clip }` para las imágenes a sangre (no rompe `sticky`, a diferencia de `hidden`). `display-date` = Archivo 700, 125 %, mayúsculas y `tabular-nums` para meses y días.

### 13.5 · Artículo

- **Cabecera:** `chrome-dark` desde la barra hasta media portada. Miga, H1 (máx. 20ch, `text-wrap: balance`), entradilla (19 → 24 px, `prose`), insignias de transparencia con «Qué significa», y firma compacta: foto de 48, nombre, fecha en palabras y minutos. Desde 1100 la firma va en el carril y la entradilla en la columna.
- **Alternativa en naranja** (botón «Campo» del mockup): `field-orange` + `dust`, tinta sobre naranja (7,91:1). Contras: el bloque naranja del final pierde exclusividad y el dock naranja desaparece sobre el campo. Por eso recomiendo tinta.
- **Portada según `media.width / height`:** ratio ≥ 1,3 → ancho de página, `max-height: min(720px, 82svh)`, `object-fit: cover` (recorte mínimo, nunca 21:9). Ratio < 1,3 → cabecera partida: texto en 7 columnas y la foto en 5, con su ratio y como mucho 640 de alto. Sin portada → solo campo. En móvil la portada va a sangre, sin radio, hasta 72 svh. LCP: `fetchpriority="high"` y `srcset` 390 → 1200.
- **Índice:** solo con ≥ 800 palabras y ≥ 3 H2. Desde 1100, carril `sticky` (top 88): H2 en filas de 44, la actual en `foreground` 500 con una marca de tiza de 2 px; debajo, «Quedan N min» (mono) como progreso discreto y la única línea de email permitida por D48, «Recibir la carta mensual →». Por debajo de 1100: `<details>` cerrado tras la portada («En este artículo · 7 apartados»), filas de 44 numeradas en mono, y una barra de progreso de 2 px fija arriba (`aria-hidden`). Anclas `#` en cada H2 al pasar o con foco; `scroll-margin-top: 72px`.
- **Bloques del cuerpo:** listas con raya de tiza (ul) y números mono (ol); cita sin barra lateral, con «» de tiza colgando en el margen desde 1100; tabla en placa `board` + `slab`, cifras mono a la derecha, filas de 48, fila destacable (`.best`, cifras en acento), pie de tabla debajo y contenedor con `overflow-x: auto`, `role="region"` y `tabindex="0"` por si una tabla de 5 columnas no cabe; nota del autor en `accent-muted` con «Nota de Xavi» en Caveat (decorativa, `aria-hidden`; el `aside` lleva `aria-label`); vídeo con la fachada de D26; ficha embebida en placa con foto, datos y nota grande.
- **Imagen:** columna (640, radio 6), ancha (1152, pasa por encima del carril con `z-index`, sin JS) y a sangre (100 vw, sin radio, solo apaisadas). Pie: texto + `<small>` de crédito, siempre en el eje de la columna. En móvil ancha y a sangre van de borde a borde.
- **Final, en este orden:** firma completa (foto de 96, nombre, rol, bio, «Sobre mí» y «Cómo trabajo»); «Fichas de este artículo» (las `data-item-card` del cuerpo, con foto, precio y nota); «Sigue leyendo» (3 con foto 4:3, categoría y minutos); bloque naranja común; pie. Fuera las tarjetas `mid` y `end` (D48). Sin fichas o sin relacionados, la sección no se pinta.
- **Sin `updated_at` visible:** no es editorial (trampa de la auditoría).

### 13.6 · Listados (`ListingHeader` común para /blog, categoría y agenda)

- Miga, H1 `title-section`, entradilla (52–56ch) y, desde `lg`, el buscador en la misma fila (4 columnas, con «/»). Debajo, categorías en una fila: en móvil se desplazan en horizontal, con el botón de buscar (44) delante, que abre el campo en su lugar. La primera foto baja de y=525 a 387 en 1440, y de 498 a 330 en 390 (medido desde la barra).
- **Destacado:** `OverlayCard` en mosaico de alturas fijas. 3 o más: 8 + 4 columnas, 560 y 2 × 272. Dos: 8 + 4 a 560. Uno: 12 columnas a 480. En móvil solo el principal es tarjeta sobre foto (4:5); los demás pasan a filas. Sin huecos muertos porque ninguna tarjeta depende del largo del texto de otra.
- **Velo medible:** el degradado va en el bloque de texto, no en la foto: de 0 a 64 % de negro en los 72–96 px superiores y del 64 al 84 % bajo el texto. El peor caso (foto blanca) da 6,69:1 para el texto blanco, sea cual sea su largo.
- **«Últimos»:** H2 en Inter (ya no `label-mini`). Fila: miniatura 200 × 134 (104 en móvil) en `slab`, categoría, título (24 / 19), entradilla de una o dos líneas en escritorio, y fecha y minutos en mono a la derecha (debajo en móvil). Sin portada: degradado de pizarra con «Sin portada».
- **Búsqueda activa:** la misma fila sustituye a destacado y «Últimos»; la cabecera no se mueve.

### 13.7 · Agenda

- Meses apilados con H2 en `display-date` (32 / 44) y el recuento a la derecha. Los dos meses de la ventana en una página; la navegación por meses, al final.
- **El siguiente:** primera actividad no cancelada del mes, en una placa: foto heredada (o póster) de 7 columnas con el día de la semana y «7 NOV» en Archivo de 120 px rodeado por el círculo de tiza, y a la derecha «el siguiente» en Caveat, título de 32, lugar, hora (mono) y precio, y «Más información» de 52. No se repite en la lista.
- **Filas tipo cartel:** fecha (baldosa de 168 × 120 con Archivo de 56 sobre la foto de la ficha del rocódromo con velo del 56 %, o póster en `tray` si no hay foto) | título 24 y «Tipo en Lugar» | hora · precio en mono | «Más información ↗» de 44. Varios días: «5–6» y «Sáb y dom». Todo el día: «Todo el día». Sin precio o sin enlace: la celda queda vacía, sin texto de relleno. Cancelado: insignia, título tachado, foto en gris.
- **Móvil:** baldosa de 96 a la izquierda del título y, debajo, una franja con hora · precio y el botón. El destacado apila foto (4:3) y datos.
- **Mes en `/agenda/aaaa-mm`:** un único mensaje por estado: futuro vacío «Aún no hay nada en enero» + margen de dos meses; en curso sin más «No queda nada más este mes» + enlace al siguiente; pasado vacío «Sin actividades publicadas en octubre»; pasado con actividades: archivo (mismas filas, sin «el siguiente», fotos en gris y una línea arriba). Nunca «Ya ha pasado» junto a «Aún no hay».
- No se diseña nivel, destacado manual ni imagen propia: no están en la BD (D33, D49).

### 13.8 · Sobre mí y firma

- Campo de tinta con la frase en primera persona como H1 (Inter 60 / 34) y la foto 4:5 grande cruzando la costura. «En números» en 4 casillas mono: 2 escritas por Xavi y 2 calculadas (rocódromos con ficha, pies de gato comparados). Sin cifra, la casilla no se pinta; con menos de dos, la sección desaparece. Nunca un «0» de relleno.
- Cuerpo (Páginas, D34) en la columna de 640: historia y «Cómo trabajo», cuya lista (`h2 + ol`) se pinta como filas numeradas solo con CSS. Enlace a Transparencia.
- **Prueba sin testimonios:** «Lo último que he comprobado», las 3 fichas con verificación más reciente, con fecha y nota. Sale de la BD.
- **«Escríbeme»** en placa `elevated` con botón `ink` y el email visible, solo si hay `contact_email`. Sin foto: el H1 ocupa 10 columnas. Sin email: no hay placa.
- **`AuthorSignature`:** `compact` (cabecera del artículo), `full` (final del artículo) y sin foto (sin círculo ni inicial). Sustituye a `ArticleAuthorCard` y a la «X».

### 13.9 · Editor y panel (ver `admin/editor-bloques-editoriales.html`)

| Bloque | HTML guardado | En el panel |
| --- | --- | --- |
| Tabla | `table > thead/tbody > tr > th[scope]/td` | Menú «/», barra flotante (+ fila, + columna, primera fila = encabezado, quitar). Hasta 5 columnas y 30 filas; sin combinar ni colorear. Las columnas con cifras se detectan al pintar |
| Imagen con pie y ancho | `figure[data-width="column\|wide\|bleed"] > img + figcaption (> small)` | Segmentado Columna / Ancha / A sangre; pie y crédito debajo de la foto. El alt sale de Medios. «A sangre» se desactiva con foto vertical o de menos de 1.600 px |
| Nota del autor | `aside[data-note="author"] > p/ul` | Placa naranja suave; la etiqueta sale del nombre de Ajustes |

Los demás bloques (párrafo, H2, H3, listas, cita, vídeo, ficha) ya existen. La cita gana `footer` opcional para la atribución.

### 13.10 · Contraste medido (WCAG 2.x)

Auditoría automática del color calculado de todos los nodos de texto sobre fondo sólido en los cinco mockups, a 1440 y 390: ninguno por debajo de AA (mínimo 5,04:1). Única alerta: «Sin portada» sobre el degradado de pizarra, un falso positivo (el detector no lee degradados); a mano da más de 12:1.

| Par | Ratio |
| --- | --- |
| Título `#f0ede8` sobre tinta `#0f0f0f` | 16,42 |
| Entradilla `#dcd8d1` sobre tinta | 13,50 |
| Fecha y miga `#a19d94` sobre tinta | 7,09 |
| Cuerpo `#34302a` sobre papel | 11,62 |
| `meta` sobre papel / `board` / `tray` / `elevated` | 6,24 / 6,70 / 5,92 / 5,66 |
| Acento `#9a4a16` sobre papel / `accent-muted` | 5,53 / 5,04 |
| Texto de la nota sobre `accent-muted` | 14,02 |
| Variante naranja: título / secundario | 7,91 / 6,11 |
| Blanco sobre el velo de las tarjetas (peor caso) | 6,69 |
| Blanco sobre la baldosa de fecha (peor caso, velo 56 %) | 4,95 |
| Tiza `#d2702a` sobre papel (comillas de 28 px y marcas, no texto de lectura) | 3,06 |

### 13.11 · Accesibilidad, responsive y motion

- Táctiles ≥ 44 px: filas del índice, chips, botones, enlaces de firma y lugares (con `hit`). Excepción: enlaces dentro de un párrafo (WCAG 2.5.8, en línea).
- Teclado: `details` nativo, foco visible con `--ring` en tinta, naranja y papel, «/» para buscar, tablas desplazables con foco.
- Imágenes decorativas con `alt=""` (miniaturas cuyo enlace ya tiene título); portada y figuras con alt de Medios.
- Sin scroll horizontal en 1440, 768 y 390 (medido). Las tablas desplazan dentro de su placa, y los chips en su fila.
- Motion: reveal de 300 ms y trazo de tiza de 600 ms solo con `prefers-reduced-motion: no-preference`; hover de 150–200 ms; el progreso no anima. Regla global de `main.css` sin cambios.

### 13.12 · Para el equipo (después de que Xavi apruebe)

**coneja-lucky**
1. Tokens de §13.4, utilidad `hit`, `overflow-x: clip` en `main`. Componente `ListingHeader` para blog, categoría y agenda (`app/components/page/`).
2. Artículo: `ArticleHeader` en campo con `CoverFigure` según ratio; `ArticleToc` (carril y plegable, umbral de 800 palabras y 3 H2, anclas en el servidor); `UiProse` con la escala nueva y los tres bloques; `AuthorSignature`; `ArticleItems` y `ArticleRelated` con foto. Quitar `NewsletterArticleCard` y `splitForNewsletter` (D48).
3. Blog: mosaico por número de artículos, `ArticleRow` con miniatura y minutos, LCP `eager` + `srcset`.
4. Agenda: `EventsNext`, `EventsRow` y `EventsDateTile` (foto de la ficha o póster); estados de mes de §13.7; `MonthBoard` queda solo para la home.
5. Sobre mí: composición de §13.8 sobre `useEditorialPage('about')` + ajustes del autor.
6. Panel: bloques de §13.9 en el editor de artículos (y en Páginas para Sobre mí) y la sección «Autor» de Ajustes (6.17).
Ojo: nombres de componentes según la regla de prefijo por carpeta.

**jabali-javi** · en `guide.site_settings` (sin tablas nuevas): `author_name text`, `author_role_es/_en text`, `author_lede_es/_en text` (≤ 120), `author_bio_es/_en text` (≤ 160), `author_photo_media_id uuid` (FK `media`, `on delete set null`, alt obligatorio como las fotos del hero, y registro en `content_media_refs`), `author_stats jsonb` (array de hasta 2 `{value, label_es, label_en}`, con `check`). `contact_email` ya existe. Además: lectura de `width/height` de la portada y de la portada del rocódromo en los eventos (vía `gym_slug`), y recuento de fichas para «En números» y «Lo último que he comprobado» (por `verified_at`).

**leona-lia** · revisar la ampliación del sanitizador: `table, thead, tbody, tr, th, td` (solo `scope`), `figure` (`data-width` con lista cerrada), `figcaption`, `small`, `aside` (`data-note="author"`) y `footer` dentro de `blockquote`; sin `style`, `class` ni atributos libres. Las columnas nuevas de `site_settings` y su `GRANT` de lectura pública (la bio y el email son públicos a propósito).

**loro-lola** (es y en) · «En este artículo», «Quedan N min», «Has llegado al final», «Recibir la carta mensual», «Qué significa», «Fichas de este artículo», «Sigue leyendo», «Nota de {nombre}», textos de estado de mes de §13.7, «el siguiente», «Lo último que he comprobado», «Escríbeme» y su frase, rol del autor, etiquetas de «En números» y avisos del editor. La frase de Sobre mí la valida Xavi.

### 13.13 · Lo que decide Xavi

1. **Color del campo** del artículo y Sobre mí: tinta (recomendado) o naranja.
2. **Dock en móvil** sobre el artículo: tapa el inicio de línea al hacer scroll. Propuesta: ocultarlo al bajar y mostrarlo al subir, solo dentro del cuerpo del artículo. Ajusta D45.
3. **«En números»:** qué dos cifras escribe él (propuesta: años escalando y grado máximo).
4. **Fotos de eventos:** baldosa con la foto del rocódromo en cada fila (propuesto) o solo en «el siguiente» y póster en el resto.

---

## 14 · Consentimiento de afines (D66): formulario, confirmada y preferencias · propuesta (pendiente de Xavi)

Mockups: [`pages/newsletter-afines.html`](pages/newsletter-afines.html) (formulario y anexo de estados), [`pages/newsletter-confirmada-afines.html`](pages/newsletter-confirmada-afines.html) y [`pages/newsletter-preferencias.html`](pages/newsletter-preferencias.html) (selector de estado arriba; también con hash). Comparten `_shared/consent.css`, `consent-tw.js` y `consent.js` (diálogo «Más información»). Verificados en Chrome headless a 1440, 768 y 390: sin scroll horizontal y sin texto por debajo de AA en ninguno.

Fuentes: textos de `docs/copy/consentimiento-comunicaciones-afines.md` (§1 casilla v1, §2 texto ampliado, §4 dónde aparece); condiciones de `docs/security/D66-related-consent-review.md` (O1, O7, §5.3); datos de `get_consent_preferences`, `set_related_consent`, `subscribe_newsletter(p_related_consent)` y `unsubscribe_newsletter`. **No hay tokens nuevos:** todo sale de §7, §9 y §12. Sin dirección alternativa: es una ampliación del componente aprobado.

### 14.1 · Reglas comunes

- **Dos finalidades, dos controles.** Newsletter y afines nunca comparten casilla, botón ni estado. Retirar una no toca la otra, y la UI lo dice en cada sitio.
- **Igual de claras.** La casilla de afines tiene el mismo tamaño (22 px), color, cuerpo (15/1.45) y peso que la de la newsletter. Va desmarcada, sin «recomendado», sin incentivo y sin texto más pequeño.
- **El texto de la casilla sale de la BD** (`consent_texts`, finalidad `related_products`, versión vigente), como el de la newsletter, nunca de i18n. Si falta, la casilla no se pinta y el alta funciona igual.
- **«Más información»** es un `<button>` (no enlace) fuera del `<label>`: pulsarlo nunca marca la casilla. Abre `ConsentRelatedInfo`, un `<dialog>` modal (640 px, centrado; hoja inferior a pantalla completa de ancho por debajo de 640) con el texto §2, «Cerrar» arriba y abajo, Esc y clic fuera. El foco vuelve al botón al cerrar. El texto §2 sí va en i18n (es/en), porque no es el texto que se acepta.
- **«(Opcional)»** va después del texto de la casilla, en `meta`, fuera del texto versionado. Evita que la gente crea que hay que marcar las dos. Es la única marca de diferencia, y no resta claridad.
- **Dar el permiso solo con un clic explícito** (POST a la RPC). Nunca al cargar, nunca por GET, nunca por defecto. Los escáneres de enlaces del correo abren las URL (O1).
- **Motion:** sin cambios; check de éxito de §12.7, `spin` en los botones con `aria-busy` y `prefers-reduced-motion` global.

### 14.2 · Formulario (`NewsletterSignup`: bloque naranja de todas las páginas y `/newsletter`)

- **Orden (DOM = tabulación):** email → casilla newsletter → casilla afines → «Más información» → «Suscribirme». Desde `lg`, la rejilla actual pone el botón en la fila 1 junto al email; las dos casillas ocupan las filas 2 y 3 a todo el ancho de la placa.
- **Rejilla de la casilla (`consent-row`):** `grid-template-columns: 22px 1fr`, `column-gap: 12px`; «Más información» en la columna 2 (alineado con el texto), con 44 px de alto táctil. Separación entre casillas: 12 px de `gap` + 4 px (`mt-1`).
- **Validación:** solo la casilla de la newsletter es obligatoria. Afines nunca da error. Si se marca afines y falta la newsletter, el error sale solo en la de la newsletter y el foco va a ella.
- **Envío:** `subscribe_newsletter(…, p_related_consent: boolean)` con el valor de la casilla.
- **Éxito:** igual que hoy. Si afines iba marcada, se añade un párrafo: «Al confirmarlo se activan la newsletter y los avisos de Chalk app. Si ya estabas suscrito, no cambia nada: los avisos se activan desde «Preferencias», al pie de cualquier email». Cubre O7 sin revelar si el email ya existía.
- **Estados** (anexo del mockup): reposo · afines marcada y falta la newsletter · solo newsletter · enviando · error del servidor (conserva las dos casillas) · sin texto de afines · éxito sin afines · éxito con afines.
- **¿Cabe a 390?** Sí. La casilla v1 ocupa 5 líneas + «(Opcional)» y «Más información» (unos 150 px). La placa pasa de unos 330 a unos 480 px de alto, y el bloque naranja sigue entrando sin recortes ni scroll horizontal. No hace falta la versión corta del texto (§1 alternativa), y no la recomiendo: es más vaga.

### 14.3 · Confirmada (`/newsletter/confirmed`)

- La confirmación de la newsletter va arriba e intacta (check, H1, texto, CTAs y «Qué te llega» de §12.8). La oferta es una placa `slab` debajo del texto y antes de las CTAs, en la columna izquierda (7/12).
- **Placa «¿Quieres también avisos de Chalk app?»** (h2, 22/20 px): primera línea «Tu suscripción a la newsletter ya está confirmada, elijas lo que elijas». Debajo, separado por una línea, el **texto exacto de la casilla v1** entre comillas (17 px) y «Más información».
- **«Sí, avísame» y «No, gracias»:** los dos `btn-ghost`, mismo ancho (rejilla de 2 columnas, máx. 440 px; apilados a ancho completo por debajo de `sm`), mismo peso, sin icono y sin orden de color. El texto queda ligado con `aria-describedby`.
  - **Sí** → `set_related_consent(token, true, 'preferences')`; botón `aria-busy` «Guardando…» y los dos desactivados mientras tanto. Éxito: la placa se sustituye por «Hecho: también te avisaré de Chalk app» + cómo retirarlo; `role="status"` y foco en ella.
  - **No** → sin llamada (no hay nada que registrar; afines sigue en `none`). La placa pasa a «Entendido: solo la newsletter» + cómo activarlo después.
  - **Error** → `role="alert"` bajo los botones: «No se ha guardado. Tu newsletter sigue confirmada…». Los botones vuelven a estar activos.
- **Cuándo sale:** solo con `can_grant_related = true`. Si afines ya es `granted` (lo marcó en el formulario), en vez de la placa sale una línea con la etiqueta «Activos» y cómo retirarlo. Sin token, con token inválido o con `can_grant_related = false`, no sale nada y la página es la de §12.8. Enlace caducado o no válido: pantalla de §12.8.
- **Requiere token:** la redirección del doble opt-in (F4.6) debe llegar con el token para leer `get_consent_preferences`. Mismo tratamiento que en preferencias (§14.4).

### 14.4 · Preferencias (`/newsletter/preferencias`, en: `/en/newsletter/preferences`; nueva)

- **Acceso:** enlace «Preferencias» del pie de cada email, con `?t=<unsubscribe_token>`. Sin login. `robots: noindex, nofollow` y `Referrer-Policy: no-referrer` (cabecera de Netlify en la ruta + `<meta name="referrer">`). `ssr: false` en `routeRules` para que el token no pase por el render del servidor.
- **El token no se ve:** el cliente lo lee, lo borra de la barra con `history.replaceState` y lo guarda solo en memoria y en `sessionStorage` (para recargar). Nunca se pinta, ni va en enlaces, en analítica o en `console`.
- **Composición:** H1 `title-section` «Tus preferencias», entradilla (19 px, `meta`), línea «Gestionas la dirección a la que llegó este enlace. No hace falta iniciar sesión» (13 px; el RPC no devuelve el email y no se muestra). Columna de 820 px máx. Dos placas `slab bg-board` apiladas (`pref`: rejilla `1fr auto`, 28 px de padding; en < 768, una columna, 20 px y botón a ancho completo).
- **Cada placa:** h2 (22/20 px) + etiqueta de estado (texto + icono, nunca solo color) + descripción + acción a la derecha.

| Fila | Estado (`get_consent_preferences`) | Etiqueta | Acción |
| --- | --- | --- | --- |
| Newsletter | `active` | La recibes (`state-on`) | «Darme de baja» → `unsubscribe_newsletter` |
| Newsletter | `pending` | Sin confirmar (`state-wait`) | «Cancelar el alta» → `unsubscribe_newsletter` |
| Newsletter | `inactive` | No la recibes (`state-off`) | «Volver a apuntarme» → `/newsletter` (alta nueva con doble opt-in) |
| Afines | `granted` | Activos | «Retirar» → `set_related_consent(t, false, 'preferences')` |
| Afines | `pending` | Sin confirmar | «Retirar» (mismo RPC) |
| Afines | `none` + `can_grant_related` | No los recibes | Texto v1 entre comillas + «Sí, avísame» → `set_related_consent(t, true, 'preferences')` |
| Afines | `none` + sin `can_grant_related` | No los recibes | «Sí, avísame» desactivado + motivo con candado: «Antes tienes que confirmar tu email…» |

- **Retirar no pide confirmación:** retirar debe ser tan fácil como dar (art. 7.3). Tras cada acción, mensaje `role="status"` en la misma placa, con foco, que repite que la otra finalidad no cambia. El resultado `unconfirmed` del RPC se muestra como el estado «email sin confirmar».
- **Estados de página:** cargando (esqueleto con la forma de las dos placas, `aria-busy`) · error (alerta + Reintentar: «el enlace puede estar bien») · **token inválido o caducado** (pantalla completa como la de §12.8, con «Abre el último email que te envié y pulsa "Preferencias"» y salidas a newsletter e inicio).
- **Pie de página:** «Lo que cambies aquí queda registrado con la fecha. No guardo IP ni navegador» + política de privacidad.

### 14.5 · Contraste nuevo (WCAG 2.x)

| Par | Ratio |
| --- | --- |
| `#1a5c41` sobre `#dcebe2` (etiqueta `state-on`) | 6,3:1 |
| `#8a4212` sobre `#f7e4d0` (`state-wait`) | 6,1:1 |
| `#5e584e` sobre `#ebe6dc` (`state-off`) | 5,7:1 |
| `#9a4a16` sobre `#f4f1ea` («Más información» en la placa) | 5,6:1 |
| `#6b6559` sobre `#fbf9f5` (botón desactivado) | 5,6:1 |

El resto de pares ya están en §9.2 y §12.9. Auditoría automática del color calculado en los tres mockups, a 1440, 768 y 390: 0 fallos.

### 14.6 · Para el equipo (después de que Xavi apruebe)

1. **coneja-lucky:** `UiCheckbox` admite un slot `after` fuera del `<label>` para «Más información»; `ConsentRelatedInfo` (diálogo); `NewsletterSignup` con la segunda casilla y `p_related_consent`; `useSiteSettings` expone el texto de afines y su `lang`. Página `newsletter/preferences.vue` (rutas `es`/`en` de §14.4, `newsletterBlock: false`) y el bloque de oferta en `confirmed.vue`. Ocultar el dock en `/newsletter*` (ya decidido en §12.6).
2. **osset-op:** cabecera `Referrer-Policy: no-referrer` y `X-Robots-Tag: noindex` en `/newsletter/preferencias*`, `/en/newsletter/preferences*` y `/newsletter/confirmed*`.
3. **loro-lola:** revisar los textos nuevos de UI (es/en) de los tres mockups: títulos de placa, botones, mensajes de resultado y de error, «(Opcional)» y estados.
4. **F4.6:** el pie de cada email lleva «Darme de baja» (un clic, como hoy) y «Preferencias». La redirección del doble opt-in incluye el token. El email de confirmación nombra las dos finalidades si afines está `pending` (O2).

### 14.7 · Preguntas para Xavi

1. **Confirmada: botones en vez de casilla.** Propongo «Sí, avísame» / «No, gracias» con el texto v1 encima, en lugar de casilla + «Guardar». Así el «No» tiene de verdad la misma prominencia y el clic en «Sí» es el acto afirmativo. **Recomiendo los botones**, con visto bueno de leona-lia. La alternativa: casilla desmarcada + «Guardar» y «No, gracias» iguales.
2. **«(Opcional)» junto a la casilla de afines.** **Recomiendo sí:** aclara que no hace falta para suscribirse y va fuera del texto versionado.
3. **Retirar sin diálogo de confirmación** en preferencias. **Recomiendo sí** (un clic, como el enlace de baja). Darse de baja de la newsletter sí es irreversible desde esa página (volver exige otra alta), pero así funciona hoy el enlace de baja.

---

## 15 · F8: `/noticias`, ficha de noticia, bloque en la home y plantilla de la carta semanal (D71, D73, D75; tarea 8.2) · propuesta (pendiente de Xavi)

Mockups en `pages/`: [`noticias.html`](pages/noticias.html), [`noticia.html`](pages/noticia.html) (conmutadores «Con nota» y «Con imagen»), [`home-noticias.html`](pages/home-noticias.html) (opciones A y B) y [`email-newsletter.html`](pages/email-newsletter.html). Estilos de editorial v2 (`_editorial-v2/`). `ev2.js` gana dos opciones solo para estos mockups: `data-news` en la cabecera (añade «Noticias» tras Blog) y `data-weekly` en el bloque naranja (copy semanal provisional). Revisado en Chrome headless a 1440 y en iframe de 390: sin scroll horizontal.

**No cambian:** hero, carrusel (D41), cabecera salvo el ítem de menú (decisión 2), dock, bloque naranja (solo su texto, que pasa a semanal), pie, paleta, isotipo y tipografías. **Sin tokens nuevos.** Lo nuevo son componentes hechos con lo que ya existe.

### 15.1 · Rutas, idioma e indexación

| Página | ES | EN | Índice | Notas |
| --- | --- | --- | --- | --- |
| Noticias | `/noticias` | `/en/news` | sí (EN con ≥ 3) | `?pagina=N` con canonical propio; `?alcance=` y `?q=` son estado de la UI (canonical sin query) |
| Categoría | `/noticias/categoria/[slug]` | `/en/news/category/[slug]` | como en el blog | Slugs traducidos, igual que en el blog |
| Ficha | `/noticias/[slug]` | `/en/news/[slug]` | **solo con «Nota de Xavi»** (D73); sin nota, `noindex,follow` y fuera del sitemap | Existe en EN solo con título y resumen EN (D3) |

Schema, canonical, hreflang y sitemap los cierra lince-max (8.4). El diseño no depende de cómo los resuelva.

### 15.2 · Índice `/noticias` (`noticias.html`)

- **Cabecera:**
  - `ListingHeader` igual que en /blog (§13.6): miga, H1 `title-section` «Noticias» (D40), entradilla de 56ch y buscador con «/» desde `lg`.
  - Debajo, **categorías** como chips-enlace (`chips-scroll`, con su recuento).
  - Y una fila **Alcance**: botones de texto con `aria-pressed` (Todo · Cataluña · España · Internacional) y un subrayado de tiza de 2 px en el activo. Altura de 44.
  - Categoría es una ruta; alcance es un filtro. Por eso tienen dos formas distintas.
- **Destacada:**
  - Qué sale: la última con nota de los últimos 7 días, solo en la página 1 y sin filtros. Sin ninguna, no se pinta.
  - Forma: placa `board` + `slab`. A la izquierda (7 columnas), la meta (categoría · alcance · fecha en mono), el título 26 → 36, el resumen y la marca de fuente. A la derecha (5), la **nota de Xavi** en `accent-muted` con la etiqueta en Caveat (`aria-hidden`; el `aside` lleva `aria-label`).
  - En móvil, la nota va debajo.
  - No se repite en la lista.
  - Es el único sitio del índice donde manda la voz del autor.
- **Lista:**
  - Agrupada por **semana** (lunes a domingo), con H2 en Inter («Esta semana · 16–22 nov», con el rango en mono).
  - **Fila de texto** (`NewsRow`):
    - Fecha mono en una columna de 132 (desde 768). En 390, delante de la meta.
    - Categoría · alcance.
    - Título 23 / 19 con `uline`.
    - Resumen de 2 líneas (desde 768; oculto en 390).
    - «Resumen de ChalkGuide · Fuente: **X**».
    - Insignia `badge-acc` «Con nota de Xavi».
  - Toda la fila es un único enlace a la ficha: una sola parada de tabulación. El enlace a la fuente vive en la ficha.
  - **Sin miniaturas:** casi ninguna noticia tendrá imagen con licencia (D71), y una columna de huecos o de pizarras repetidas pesa más que el texto. La imagen, cuando exista, sale solo en la ficha.
- **Paginación:** 20 por página. «Más recientes / Anteriores» en botones de 44 con borde, y números mono (actual en tinta); en 390, «1 / 5». La flecha deshabilitada usa `muted` (5,13:1), no opacidad.
- **Búsqueda (FTS):** sustituye a la destacada y a las semanas por «N resultados para “x”» con la misma fila. La cabecera no se mueve.
- **Vacío:** «No hay noticias sobre “x”» + Quitar filtros + Ir al blog (anexo del mockup). Una categoría vacía no muestra «0»: muestra el vacío con enlace a «Todo».
- **Descartado:** el mosaico de fotos del blog. Sin fotos propias, sería un mosaico de pizarras.

### 15.3 · Ficha `/noticias/[slug]` (`noticia.html`)

- **Familia:**
  - **Papel**, no tinta (§13.2): no es una pieza con voz.
  - Columna de lectura de 640 centrada en todos los anchos, con márgenes de 16 en móvil.
  - Miga completa en escritorio. En móvil, solo el padre: «← Roca y acceso».
- **Cabecera:**
  - Alcance · fecha en palabras.
  - H1 en Inter 500, `clamp(30px → 48px)`, 1,08, `text-wrap: balance`, sin Archivo (D40).
  - Debajo, la **marca**: `badge-plain` «Resumen de ChalkGuide» + «Fuente: [Medio]», con el enlace al bloque de la fuente.
- **Imagen** (opcional; solo con licencia):
  - Va en la columna, en 3:2, con radio 6. En móvil va a sangre.
  - `figcaption` con pie y `<small>` con «Foto: autor · licencia».
  - Sin imagen, no hay hueco.
- **Resumen:** `prose` a la escala de lectura (§13.3).
- **Nota de Xavi** (solo si existe; es lo que activa la indexación):
  - Placa `accent-muted` con la etiqueta en Caveat.
  - Texto a 18 / 17.
  - Firma pequeña (foto de 32 de Ajustes, nombre y fecha).
  - Va **después del resumen y antes de la fuente**: primero el hecho, luego la opinión y luego dónde verificarlo.
- **Fuente original** (siempre):
  - Placa `board` + `slab`.
  - Contenido: «Fuente original», nombre del medio a 22, titular original entre comillas con su `lang` (si existe `source_title`) y «Publicada el · en catalán».
  - Botón **btn-ink** de 52, «Leer en [Medio]» con flecha diagonal y sr-only «(web externa)». Se abre en la misma pestaña (el usuario decide).
  - En 768 o más, el botón va a la derecha; en móvil, a ancho completo.
  - Debajo, la línea de transparencia: «Este texto es un resumen propio de ChalkGuide. Los datos son de la fuente; si algo no cuadra, manda la fuente» + «Cómo hacemos las noticias» (enlace a Transparencia; texto de loro-lola).
- **Después:** «Más noticias» (3 filas `NewsRow` compactas y «Todas las noticias»), el bloque naranja y el pie.
- **Sin etiquetas públicas en v1:** son internas (búsqueda y carta). Una página por etiqueta sería contenido fino.

### 15.4 · Bloque en la home (`home-noticias.html`)

- **B · Sección propia entre Blog y Newsletter (recomendada):**
  - Fondo `elevated`.
  - Composición de «¿Por dónde empiezas?»: H2 `title-section` «Noticias» con la entradilla y «Todas las noticias» a la izquierda (4 columnas); a la derecha (7), 4 filas de texto (fecha mono · título 21 · «Fuente: X» · «Con nota de Xavi» en `accent`).
  - En móvil, el botón va a ancho completo debajo.
  - **Por qué B:**
    - No mueve nada de D44: se añade una sección.
    - Hace de puente hacia la carta: lo que acabas de ver es lo que te llega cada semana.
    - Deja el blog, que es la voz propia, sin mezclar.
  - **Reglas:**
    - Muestra las 4 últimas; primero las que llevan nota, si son de la semana.
    - Con menos de 2 noticias, la sección no se pinta.
    - Entra en `data-nav-section` solo si «Noticias» entra en el menú.
- **A · Dentro de Blog:** «Esta semana» con 2 filas bajo el primer artículo, más un segundo botón. No añade sección, pero quita sitio al segundo artículo y mezcla dos voces.
- **C · Tarjeta en el carrusel del hero (descartada):** rompe D41 y pone lo de terceros por delante de lo propio.

### 15.5 · Plantilla de la carta (`email-newsletter.html`)

- **Técnica:**
  - Tablas con `role="presentation"`, ancho de 600 (fluido al 100 % por debajo de 620) y estilos en línea.
  - El `<style>` solo lleva mejoras (móvil, enlaces de iOS).
  - Sin web fonts que dependan de la carga: pila Inter → -apple-system → Segoe UI → Helvetica → Arial. Fechas en JetBrains Mono → Menlo → Consolas.
  - Logo en **PNG 2x alojado** (el SVG del mockup no se ve en Gmail) con alt «ChalkGuide».
  - `color-scheme: light only`.
  - Botón «a prueba de clientes» (celda con fondo `#1c1a17` y enlace con relleno).
  - Preheader oculto con relleno de espacios.
  - `lang` por campaña.
  - Peso objetivo < 100 KB: Gmail recorta a partir de 102 KB.
- **Estructura:**
  1. «Ver en el navegador».
  2. Cabecera en tinta con logo y «Semana 47 / 16–22 nov» en mono.
  3. Filete naranja de 4 px.
  4. H1 = asunto.
  5. Intro con la voz de Xavi, firmada.
  6. **Del blog:** imagen 520, categoría · minutos, título, texto corto y botón tinta.
  7. **Noticias de la semana:** «Resúmenes de ChalkGuide. Cada uno enlaza a su fuente». Cada noticia lleva categoría · alcance, título (enlaza a la ficha), texto corto, «Nota de Xavi» en `accent-muted` (si hay) y **«Fuente: [Medio]» enlazada a la fuente original**.
  8. **Agenda · próximos 14 días:** baldosa de fecha 64 en `tray`, con día, número y mes en mono. Título, «Tipo en Lugar · hora · precio».
  9. Cierre («Reenvíala… responde a este email: lo leo yo»).
  10. **Pie:**
      - Transparencia: «Ninguna mención es pagada…».
      - Por qué la recibes.
      - **Darte de baja** (en negrita, primero) · Preferencias · Privacidad.
      - Identidad legal (marcador hasta F7).
- **Variables** (`{{ }}`) de la Edge Function (8.13): URLs de cada ítem, `unsubscribe_url` (el token de baja propio, no el de Brevo, para que la baja quede en `guide.subscribers`), `preferences_url` y `mirror_url`.
- **Cabeceras** `List-Unsubscribe` + `List-Unsubscribe-Post: List-Unsubscribe=One-Click` apuntando al mismo endpoint (requisito de Gmail y Yahoo). Esto es de osset-op y jabali-javi.
- **Accesibilidad:**
  - Texto de 15–17 px, y nunca por debajo de 13 (pie).
  - Enlaces con texto propio, nunca «aquí».
  - `alt` en la imagen del artículo.
  - Orden de lectura lineal.
  - Contraste medido abajo.

### 15.6 · Contraste nuevo (WCAG 2.x)

| Par | Ratio |
| --- | --- |
| `accent` `#9a4a16` sobre `elevated` (enlace «Con nota de Xavi» del bloque B) | 5,02 |
| `meta` sobre `elevated` | 5,66 |
| `muted` `#6b6559` sobre papel (paginación deshabilitada) | 5,13 |
| `badge-acc` (`#9a4a16` sobre `#f7e4d0`) | 5,04 |
| Email: `#5e584e` / `#9a4a16` / `#34302a` sobre blanco | 7,04 / 6,24 / 13,11 |
| Email: `#a19d94` sobre tinta `#0f0f0f` (semana) | 7,09 |
| Email: `#fbf9f5` sobre botón `#1c1a17` | 16,51 |
| Email: `#5e584e` sobre baldosa `#efebe3` | 5,92 |

El resto de pares ya están medidos en §13.10.

### 15.7 · Para el equipo (después de que Xavi apruebe)

- **coneja-lucky:**
  - `NewsRow`, `NewsFeatured`, `NewsSourceCard` y `NewsScopeFilter` en `app/components/news/` (regla del prefijo por carpeta).
  - `ListingHeader` reutilizado.
  - `HomeNews`, si gana B.
  - El ítem «Noticias» del menú, en escritorio y móvil, si se aprueba.
  - Con 7 ítems, el menú de escritorio necesita `gap` de 20 entre 1024 y 1279 (32 desde 1280) y `white-space: nowrap`: con 32 px, «Pies de gato» y «Sobre mí» parten línea a 1024. Hay que medirlo también en EN, a 1024.
  - ISR de 10 min y purga al publicar (con osset-op).
- **loro-lola** (es y en):
  - Entradillas de índice y home.
  - «Resumen de ChalkGuide», «Fuente original», «Leer en {medio}», «Con nota de Xavi», la línea de transparencia y «Cómo hacemos las noticias» (sección en Transparencia).
  - Vacíos.
  - Nombres de categorías.
  - El bloque naranja en semanal («Una carta a la semana» es provisional).
  - La carta: cierre, pie y «This week only in Spanish».
- **lince-max:** §15.1 con D73.
- **jabali-javi / osset-op:** los campos de §19.6 del README del panel, `source_title`, y las cabeceras de baja en un clic.

### 15.8 · Decisiones para Xavi

Son las mismas cinco de `admin/README.md` §19.7. Las del sitio son la 1 (bloque en la home: **B recomendada**) y la 2 («Noticias» en el menú tras Blog: **recomendado**).

---

## 16 · Consentimiento de cookies (D69, D85, D86): banner, preferencias y pie · aprobado (D86)

Mockup: [`pages/cookies-consentimiento.html`](pages/cookies-consentimiento.html). Arriba hay un selector de dirección (A/B) y de escena: primera visita, bajar a newsletter y pie, panel la primera vez, reabrir desde el pie con una elección guardada y bloque de `/cookies`. También se puede abrir con `?v=b` y `?scene=panel|bottom|chosen|cookies`. Verificado en Chrome headless a 1440, 768 y 390: sin scroll horizontal, 0 textos por debajo de AA y 0 controles por debajo de 44 px en el banner y en el panel.

Fuentes: `docs/marketing/analitica-remarketing-spec.md` §2 (categorías), §3 (carga y LCP) y §8 (puntos de diseño); D69, D85 (`vanilla-cookieconsent` v3 autoalojado), D22 (sin interstitials), D26 (vídeos fuera del banner), D45 y D51 (dock), D48 (bloque naranja) y la línea de §12 y §14. **No hay tokens nuevos**: todo sale de §7, §9, §12 y §14.

### 16.1 · Direcciones

| | A · Barra de papel (**recomendada**) | B · Placa de pizarra |
| --- | --- | --- |
| Qué es | Barra a todo el ancho, abajo, en `board` (`#fbf9f5`) con filete superior `line-strong` y sombra hacia arriba. Texto a la izquierda y tres botones a la derecha desde `lg` | Placa `#1a1a1a` de 440 px flotando abajo a la izquierda desde `lg`, con `slab-dark`. Por debajo de `lg`, la misma hoja inferior que A, en oscuro |
| Intención | Una pieza del sistema de papel: la misma placa que el formulario de la newsletter y el diálogo de D66. Se ve sobre el hero oscuro, sobre el cuerpo claro, sobre el campo naranja y sobre el pie | Continuar la cabecera y el pie oscuros: se lee como cromo del sitio, no como contenido |
| Pros | La más baja en escritorio (98 px, 11 % de 900). No tapa ninguna columna de lectura, solo la franja inferior. Contraste seguro en todos los fondos | Menos área en escritorio (91.000 px² frente a 141.000) |
| Contras | Ocupa todo el ancho en escritorio, aunque sea bajo | Sobre el hero y el pie (ambos `#0f0f0f`–`#141414`) se funde: 1,06:1 de placa a fondo, solo la separa el borde. En 1440 tapa la tarjeta izquierda del carrusel y, en artículos, el inicio de las líneas de la columna de lectura. Es más alta (207 px) |

Recomiendo **A**. En 390 y 768 las dos son la misma hoja inferior, así que la decisión solo afecta a escritorio.

### 16.2 · Primera capa: banner

- **Contenido:** título (15 px, 500) + texto (14/1.45, `meta`, máximo 78ch) con el enlace «Política de cookies» al final. Tres botones: **Aceptar · Rechazar · Configurar**.
- **Mismo peso (AEPD):** los tres son `btn-ghost`, con el mismo ancho (rejilla de 3 columnas iguales), alto (44 px), cuerpo y posición en la misma fila. No hay primario, ni color de acento, ni orden de color. Aceptar y Rechazar van juntos. Configurar va tercero porque es una vía distinta, no un tercer sí/no.
- **Rejilla:**
  - < 640: `padding: 16px`; texto arriba; botones a todo el ancho, 3 columnas de unos 114 px y `gap: 8px`.
  - 640–1023: `padding: 20px 24px`; botones en un bloque de 456 px, alineados a la izquierda bajo el texto.
  - ≥ 1024: una fila, `grid-template-columns: 1fr auto`, `column-gap: 40px`, `padding: 16px 24px` dentro de `max-w-page`. Botones en 432 px.
  - `padding-bottom: env(safe-area-inset-bottom)` en iOS.
- **Altura medida:** 98 px en 1440, 162 en 768 y 174 en 390 (21 % de 844). Tope: **≤ 25 % del alto de pantalla y ≤ 180 px en 390**. Eso fija los límites de texto de §16.8.
- **Sin X.** La spec de marketing la pedía como «rechazar», pero ya hay «Rechazar» visible, y una X se entiende como «luego». Ver la pregunta 2 de §16.9.
- **No es consentimiento:** desplazarse, pulsar fuera, pulsar Esc o navegar a otra página no cierran el banner ni cuentan. Sigue en todas las páginas hasta que la persona elige.
- **Al elegir:** se guarda la elección y el banner sale con un fundido (150 ms). Si el foco estaba dentro, pasa a `<main tabindex="-1">` con `preventScroll`. Un `role="status"` oculto dice «Preferencias de cookies guardadas». Sin toast visible: menos ruido.
- **Dónde no sale:** en `/administrador/**`. Sin JS no hay banner ni se carga nada.

### 16.3 · Segunda capa: panel de preferencias

- **`<dialog>` modal** con fondo `rgb(15 15 15 / .55)`: lo abre la persona (Configurar, pie o `/cookies`), así que no es un interstitial. Mide 640 px, centrado, con radio `slab`. Por debajo de 640 es una hoja inferior a todo el ancho, con radio 12/12/0/0, `max-height: 92dvh` y cuerpo con scroll. Es la misma pieza que `ConsentRelatedInfo` (§14.1).
- **Cabecera:** título «Preferencias de cookies» (22/20 px) y, debajo, una línea de estado (13 px, `meta`): «Todavía no has elegido…» o «Tu elección actual, guardada el {fecha}». X de 44 px «Cerrar sin guardar».
- **Cuerpo:** entradilla con el enlace a la política y tres categorías separadas por un filete `line`.
  - **Necesarias:** etiqueta «Siempre activas» con candado (`#1a5c41`, 7,53:1) y sin interruptor.
  - **Analítica:** interruptor en **No**.
  - **Publicidad y remarketing:** interruptor en **No**. Es un solo control para los tres permisos de anuncios (`ad_storage`, `ad_user_data`, `ad_personalization`), como fija la spec en §2.
  - Cada categoría lleva título (17 px, 500), descripción (15/1.5, `meta`, 56ch) y un desplegable «Qué guardan y de quién» (`<details>`, 44 px). Dentro, una fila por cookie con nombre en mono, proveedor y finalidad, y duración. Son 3 columnas (150 / 1fr / 120) desde 640 y se apilan por debajo.
- **Nota al final:** «Los vídeos de YouTube no dependen de esto…» (D26). No hay categoría de vídeos, como decide la spec en §2.
- **Pie del panel:** **Rechazar todo · Aceptar todo · Guardar selección**, los tres `btn-ghost` iguales. Van en 3 columnas desde 640 y apilados a todo el ancho por debajo.
- **Nunca premarcado:** sin elección, los interruptores salen en No. Al reabrir, muestran lo guardado.
- **Cerrar** (X, Esc o clic fuera) no guarda nada. Si aún no había elección, el banner sigue ahí. El foco vuelve al botón que abrió el panel.

**Interruptor (`role="switch"`, `aria-checked`, `aria-labelledby` al h3, `aria-describedby` a la descripción):**

| Parte | Off | On |
| --- | --- | --- |
| Pista 44 × 26, radio 13 | `elevated` + borde `control` (4,03:1 sobre papel) | `accent-fill` + borde `accent` `#9a4a16` (5,93:1; el naranja solo da 2,32:1) |
| Botón 18 px | `meta` `#5e584e` a la izquierda | `#1a0a00` a la derecha (7,91:1 sobre naranja) |
| Texto delante | «No» en `meta` | «Sí» en `foreground` |

El área táctil es de 44 px de alto y el texto Sí/No forma parte del botón. La transición es de 150 ms. El foco usa el anillo de papel (`0 0 0 2px #fbf9f5, 0 0 0 4px #9a4a16`).

### 16.4 · Pie y `/cookies`: cambiar la elección después

- **Pie (`SiteFooter`):** «Preferencias de cookies» en la fila inferior, entre el © y «English». Es un control, no una página, y así no se mezcla con «Cookies» de «Cuentas claras». Va en 13 px, `meta`, 44 px de alto y hover a `foreground`. Es un `<a href="/cookies#preferencias">` (en: `/en/cookies#preferences`) con `aria-haspopup="dialog"`. Con JS abre el panel con `preventDefault`; sin JS lleva al bloque de `/cookies`. En 390 los dos enlaces van juntos en una segunda línea.
- **`/cookies`, bloque «Tu elección»** (`id="preferencias"`): va después de la entradilla y antes de la tabla legal. Es una placa `slab bg-board pref`, la misma fila de §14.4.
  - Con elección: fecha y dos filas (Analítica y Publicidad) con `state-on` «Activada» o `state-off` «Desactivada» (texto + icono), y el botón «Cambiar preferencias».
  - Sin elección: «Todavía no has elegido…» y el botón «Elegir ahora».
  - Sin JS: un texto que explica que no se carga nada y que hace falta JS para elegir.
- **Retirar es tan fácil como dar:** desde el pie, dos clics (abrir y «Rechazar todo»), los mismos que para aceptar.

### 16.5 · Coexistencia con dock, newsletter y menú

- **Dock (D45, D51):** está arriba (centrado desde `lg`, arriba a la izquierda por debajo). No se cruza con el banner, que está abajo. No hay que tocar `ScrollDock`.
- **Bloque naranja y pie:** mientras el banner está abierto, `body` gana `padding-bottom: var(--cc-h)` y `html` gana `scroll-padding-bottom: var(--cc-h)`. Un `ResizeObserver` mide el banner y pone esa variable. Así el formulario de la newsletter y el pie siempre se pueden subir por encima del banner, y un campo con foco no queda debajo. El hueco está al final del documento, fuera de la vista inicial: **no mueve nada visible (CLS 0)**. Al cerrar, la variable vuelve a 0.
- **Capas:** el banner usa `z-index: 45`, por encima del dock (40) y por debajo del menú móvil y de los diálogos (≥ 50). Con el menú abierto, el banner queda tapado y vuelve al cerrarlo.
- **Rutas `/newsletter*` y `/cookies`, `/privacidad`:** el banner sale igual. No las tapa: se leen con el banner abierto.

### 16.6 · LCP y carga

- El banner **no se renderiza en servidor** (no cambia el HTML de ISR). Se monta en el cliente con `requestIdleCallback`, con un respaldo de `setTimeout` de 2 s, y siempre después del LCP de la home.
- Va `position: fixed`, sin reservar sitio en el flujo.
- **Tamaño frente al LCP:** el candidato de texto del banner es el párrafo: 358 × 61 px en 390 (unos 22.000 px²) y unos 630 × 40 en 1440. La tarjeta del hero mide unos 285 × 380 en 390 y 300 × 410 en 1440. En 390 el banner empieza en y = 670, por debajo de la tarjeta (que acaba hacia 660): tapa la cuerda, no la tarjeta. **Regla para el texto:** que no supere el tamaño de §16.8, porque un párrafo más largo podría pasar a ser el LCP en páginas sin imagen.
- **Entrada:** 180 ms de opacidad y 12 px hacia arriba. **Salida:** 150 ms. Con `prefers-reduced-motion` aparece y desaparece sin transición.
- El CSS del banner va en el chunk de cliente del plugin, no en `main.css`, para no sumar CSS bloqueante (auditoría de LCP, hallazgo 2).

### 16.7 · Para coneja-lucky: encaje con `vanilla-cookieconsent` v3

Los nombres de opciones y variables hay que verificarlos contra la versión instalada. Lo que manda es el resultado visual y de accesibilidad de §16.2–16.5.

- **`guiOptions`:**
  - `consentModal: { layout: 'bar inline', position: 'bottom', equalWeightButtons: true, flipButtons: false }`
  - `preferencesModal: { layout: 'box', equalWeightButtons: true, flipButtons: false }`
  - `disablePageInteraction: false`
- **Categorías:** `necessary { enabled: true, readOnly: true }`, `analytics {}` y `ads {}`, sin `enabled` en las dos últimas. El mapa a Consent Mode v2 y a Meta es el de la spec, §2 y §3.
- **Sin X** en la primera capa: no definir `closeIconLabel` en `consentModal`, lo que dependa de la pregunta 2. En el panel sí va, como «Cerrar sin guardar».
- **Estilos propios:** se sobrescribe el CSS de la librería bajo `#cc-main`, con sus variables (`--cc-bg`, `--cc-primary-color`, `--cc-secondary-color`, `--cc-btn-*`, `--cc-toggle-*`, `--cc-separator-border-color`, `--cc-overlay-bg`, `--cc-modal-border-radius`, `--cc-btn-border-radius`, `--cc-font-family`) llevadas a los tokens de §7 y §12. Si la librería pinta «Configurar» como secundario, se iguala con CSS: los tres botones de la primera capa y los tres del panel son idénticos.
- **Orden en el DOM:** con la opción `root`, el banner va a un `<div id="cc-root">` puesto al principio de `<body>` en `app.vue`, después del salto al contenido. Así es lo primero que se alcanza con el tabulador. No roba el foco al aparecer. Un `aria-live="polite"` lo anuncia una vez.
- **Primera capa:** `role="dialog"`, `aria-modal="false"`, `aria-labelledby` (título) y `aria-describedby` (texto). **Panel:** modal con trampa de foco, Esc y retorno del foco.
- **Si la librería no admite** el texto Sí/No del interruptor o el desplegable separado, se acepta su patrón de sección desplegable. Condiciones: el interruptor sigue siendo un control aparte de 44 px, y el estado se distingue sin color (posición del botón y borde).
- **Reabrir:** `useConsent().open()`, el `showPreferences()` de la librería, desde el pie (`SiteFooter`) y desde el bloque de `/cookies` (componente nuevo, p. ej. `CookiesChoice` en `app/components/cookies/`, según la regla del prefijo por carpeta). La fecha y el estado salen de `getCookie()` o `getUserPreferences()`.
- **Exclusiones:** ni librería ni CSS en `/administrador/**`.
- **Estados que hay que probar:**
  1. Primera visita.
  2. Desplazarse sin elegir: el banner sigue.
  3. Aceptar.
  4. Rechazar.
  5. Configurar, cerrar sin guardar: el banner sigue.
  6. Guardar solo Analítica.
  7. Reabrir desde el pie: muestra lo guardado.
  8. Retirar: `/cookies` refleja «Desactivada».
  9. Recarga tras elegir: sin banner ni parpadeo.
  10. Sin JS.
  11. EN.
  12. 390 con la newsletter enfocada.
  13. Teclado completo.
  14. `prefers-reduced-motion`.

### 16.8 · Claves de texto para loro-lola (es y en; sin redactar aquí)

El texto del mockup es provisional. Los límites salen de las medidas de §16.2:

- **Banner:** título ≤ 32 caracteres; texto ≤ 140 caracteres con el enlace incluido (unas 3 líneas en 390); cada botón ≤ 10 caracteres.
- **Panel:** cada botón ≤ 18 caracteres.

| Grupo | Claves |
| --- | --- |
| Banner | `cookies.banner.title`, `cookies.banner.description`, `cookies.banner.policyLink`, `cookies.banner.accept`, `cookies.banner.reject`, `cookies.banner.settings`, `cookies.banner.announce` (solo lector de pantalla) |
| Panel | `cookies.prefs.title`, `cookies.prefs.statusNone`, `cookies.prefs.statusSaved` (`{date}`), `cookies.prefs.intro`, `cookies.prefs.policyLink`, `cookies.prefs.close`, `cookies.prefs.rejectAll`, `cookies.prefs.acceptAll`, `cookies.prefs.save`, `cookies.prefs.on`, `cookies.prefs.off`, `cookies.prefs.alwaysOn`, `cookies.prefs.details`, `cookies.prefs.videosNote`, `cookies.prefs.saved` (solo lector de pantalla) |
| Categorías | `cookies.category.necessary.title` / `.description`, `cookies.category.analytics.title` / `.description`, `cookies.category.ads.title` / `.description` |
| Tabla de cookies | `cookies.table.cookie`, `cookies.table.provider`, `cookies.table.purpose`, `cookies.table.duration`, y una finalidad por cookie: `cookies.purpose.consent`, `cookies.purpose.session`, `cookies.purpose.ga`, `cookies.purpose.gcl`, `cookies.purpose.fbp`. Las duraciones no son copy: salen del escaneo (lince-max y leona-lia) |
| Pie | `footer.cookiePreferences` |
| `/cookies` | `cookies.choice.title`, `cookies.choice.savedOn` (`{date}`), `cookies.choice.none`, `cookies.choice.noJs`, `cookies.choice.change`, `cookies.choice.chooseNow`, `cookies.choice.on`, `cookies.choice.off` |

### 16.9 · Preguntas para Xavi

1. **Dirección:** **recomiendo A (barra de papel).** B se funde con el hero y el pie oscuros, y en escritorio tapa contenido de lectura.
2. **¿X en el banner?** La spec la pide como «rechazar». **Recomiendo no ponerla:** «Rechazar» ya está visible y con el mismo peso, y una X se lee como «más tarde», lo que deja la elección ambigua. Si la queréis, X = Rechazar, con `aria-label` «Rechazar y cerrar». Necesita el visto bueno de leona-lia.
3. **Orden de los botones:** propongo Aceptar · Rechazar · Configurar, los tres idénticos. La alternativa es empezar por Rechazar. No cambia la prominencia, solo el orden de lectura.
4. **Nombrar a Google y Meta en el propio banner** (no solo en el panel). **Recomiendo sí:** encaja con la transparencia del sitio y cuesta unos 20 caracteres.
