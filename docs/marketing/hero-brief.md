# Brief de marketing · Hero de la home (slider)

> **Nota 2026-10-30 (lince-max): este brief está parcialmente superado.** Vale lo que dicen `docs/PLAN.md` D38, D39 y D41:
> - **D38** anula el subtítulo, los CTA (primario y secundario), la credencial, el eyebrow y todo el §5 de textos de la slide 1: el hero no lleva botones, frase ni credencial; el H1 es «Escalar en Barcelona» (no las alternativas A/B/C). Quedan vigentes en su fondo: un solo H1 en SSR, `title`/`description` alineados con el H1 y el contenido rastreable.
> - **D41** sustituye el slider de 3 slides (presentación, artículo, pies de gato) por un carrusel manual de 8 tarjetas (fotos, pies de gato, evento, rocódromos, artículo), sin autoplay. Ya no existe «slide 1 de presentación»: el H1 va fuera del carrusel. Las tarjetas son enlaces `<a href>`.
> - **D39** quita el crédito de foto visible en las tarjetas. Los eventos de medición `hero_cta_click` / `hero_slide_*` ya no aplican (no hay CTA ni slides); la medición pasa a clics de tarjeta por tipo y clic en la cuerda, pendiente de aprobar herramienta.
>
> El resto (público, SEO de imágenes/LCP, privacidad, afiliados) sigue como referencia.

Autor: lince-max · 2026-10-29 · Para: buho-pixel (UX/visual), coneja-lucky (implementación), loro-lola (pulido de textos).
Alcance: mensaje, SEO y medición. No define interfaz.

## 1. Objetivo y público

**Problema actual:** el hero es el artículo destacado (hoy, costes). Un visitante nuevo no sabe qué es ChalkGuide, y el primer H1 depende de un artículo cambiante. Eso diluye la marca y el SEO de la home.

**Objetivo del hero (en este orden):**
1. En 5 segundos, que se entienda qué es ChalkGuide y que es de fiar (medio independiente, voz de autor, Barcelona).
2. Llevar al visitante al siguiente paso útil (explorar) y capturar el interés recurrente (newsletter).
3. Mostrar que hay contenido vivo (artículo destacado).

**A quién habla (prioridad):**
1. **Principiante** (1-2 meses escalando, lleno de dudas: dónde, qué pies de gato, bono o cuota). Es el mayor volumen de búsqueda y el más necesitado de guía. Es quien más se suscribe a algo que "le explica".
2. **Escalador habitual** (2-3 veces/semana, años). Quiere comparar rápido; no le hagas perder tiempo.
3. **Expat** (en-GB): mismo mensaje, con "Barcelona" explícito y sin dar por sabido el contexto local.
4. Futuro: 40+ (no se menciona aún; es hipótesis del plan).

**Encaje con «Por dónde empiezas» (justo debajo):** el hero responde a *qué es esto y por qué fiarme*; «Por dónde empiezas» responde a *qué leo yo según mi perfil*. Por eso el hero **no segmenta por perfil** ni lista caminos. Habla a todos, en general; el segmento llega al hacer scroll. El hero no repite los enlaces de los caminos; su CTA primario va a una sección distinta (rocódromos) y no a los artículos de perfil.

## 2. Slide 1 · Presentación (única con H1)

### H1 (alternativas)
- **A (recomendada):** «Escalar en Barcelona, con alguien que ya lo ha probado»
  Porque: voz de autor y propuesta de valor en una frase; coherente con «empecé sin nadie a quien preguntar». Lleva "escalar" y "Barcelona". Evita superlativos (regla de `.ai/copy.md`).
- B: «La guía independiente de escalada en Barcelona»
  Más literal y mejor para SEO puro, pero más fría, y "guía" es genérico.
- C: «Rocódromos, pies de gato y consejos de escalada en Barcelona, sin patrocinios»
  Cubre keywords pero es largo y "sin patrocinios" es una promesa que hay que poder sostener (hay afiliados marcados). Descartada.

### Subtítulo (alternativas)
- **A (recomendada):** «Fichas de rocódromos, comparador de pies de gato, resoladores y artículos escritos en primera persona. Independiente: lo pagado se marca.»
- B: «Un medio editorial para escaladores de Barcelona: dónde escalar, qué material comprar y cómo mejorar, contado con datos y sin postureo.»
- C: «Lo que me habría gustado encontrar cuando empecé: rocódromos, material y consejos de escalada en Barcelona.»

Nota: C es la más emotiva y alineada con la cita de autor existente (`home.author.quote`); es buena alternativa si Xavi prefiere voz personal en el H1 y la A de subtítulo se queda corta. Longitud: subtítulo ≤ ~160 caracteres para que no se corte en móvil.

### CTA
**Recomendación: primario = explorar; secundario = newsletter.**

- **Primario: «Ver los rocódromos»** → listado de rocódromos (ruta de la ficha/tabla; coneja-lucky confirma la ruta real). Justificación: la mayoría llega por búsqueda local ("rocódromos Barcelona"); no te conoce, así que pedirle el email en el primer contacto convierte mal y quema confianza. El listado es el activo más fuerte y demuestra valor en un clic.
- **Secundario (enlace de texto, menos peso): «Recibe la newsletter mensual»** → ancla al bloque de newsletter del layout (final de página). Captura a quien ya viene convencido (recurrentes, redes) sin competir con el primario.
- Por qué no newsletter como primario: el objetivo es emails, pero se consiguen mejor tras una muestra de valor (tabla, comparador, artículo); ya hay bloque de newsletter en el layout y conviene reforzarlo en el flujo, no en el primer pantallazo.
- **Test sugerido (cuando haya tráfico):** variante con campo de email en línea en la slide 1 (doble opt-in, casilla desmarcada, RGPD, `source=hero`). Se decide con datos, no a priori. Requiere propuesta de buho-pixel y revisión de leona-lia.

### Prueba / credencial (sin inventar cifras)
Una sola línea corta bajo los CTA, de las que son verdad hoy:
- **Independencia:** «Independiente · lo pagado se marca» (es regla del proyecto, verificable).
- **Autor:** «Por Xavi · 6 años escalando en BCN» (dato ya en `home.author.line`; confirmar que deja de ser dummy).
- **Número de rocódromos:** solo si es dinámico (conteo real de la tabla de `guide` con ficha publicada), p. ej. «{n} rocódromos visitados». Nunca un número fijo en el texto. Si el conteo es bajo (<5), mejor no mostrarlo.
- No usar «verificado» salvo que exista un criterio público de qué significa (visita real, fecha de última revisión). Si existe, «Visitado por Xavi» es más concreto y más creíble.
Recomendación: independencia + autor (2 elementos, no más).

## 3. Slide 2 · Artículo destacado

- **Qué muestra:** categoría (p. ej. «Costes»), título del artículo, 1 línea de extracto opcional, imagen del artículo y su crédito de foto (como hoy).
- **CTA:** «Leer el artículo» (en vez del actual «Leer la guía», que promete algo que no es). Destino: el artículo.
- **Papel:** prueba de que hay contenido real y útil; ya no es la primera impresión. Funciona como "gancho de actualidad": cambia al cambiar el destacado (Xavi lo elige).
- **Recomendación editorial:** el destacado debe rotar con intención. Para captar al principiante, preferir un artículo de pilar «empezar a escalar» o «dónde escalar» antes que «costes» (más útil al cierre de la decisión, no al primer contacto). Es decisión de Xavi.
- **SEO:** en esta slide el título va en `<h2>` (o nivel inferior), no `<h1>`. El enlace debe ser rastreable (`<a href>` real, no solo JS).

## 4. Recomendaciones sobre el slider

**Orden y número de slides**
1. Presentación (siempre la primera, también para bots).
2. Artículo destacado.
3. (Opcional, recomendada) **Comparador de pies de gato**: es el diferencial más único del producto frente a competidores y tiene intención de compra (afiliado marcado). Slide con CTA «Comparar pies de gato».
- Máximo **3 slides**. Más reduce la visibilidad de cada una y la tasa de clic cae en las posteriores. Una cuarta (agenda) cuando exista contenido real de agenda.
- Si falta contenido (sin artículo destacado, sin modelos), la slide se omite; el slider con 1 sola slide se muestra como hero estático, sin controles.

**SEO**
- **Un solo H1 en la home: el de la slide 1.** Las demás slides usan `h2` (o solo `p` estilizado). Nada de `h1` por slide.
- El H1 y el subtítulo van en el HTML renderizado en servidor (SSR/híbrido), visibles sin JS. Las demás slides también deben estar en el DOM (no cargadas por JS tras interacción), pero ocultas a lectores de pantalla cuando no están activas (`aria-hidden`/`inert`).
- `title` y `description` de la home (`seo.defaultTitle/defaultDescription`) deben alinearse con el H1 elegido (mismo concepto: independiente, Barcelona, escalada), sin copiarse literal. Coordinar con loro-lola.
- **Imagen de fondo de la slide 1: es LCP.** Debe cargar con prioridad (`fetchpriority="high"`, sin lazy), tamaños/formatos responsivos (`@nuxt/image`, AVIF/WebP) y dimensiones reservadas para evitar CLS. Las imágenes de las slides 2 y 3 son lazy. Si es un `background-image` CSS, no se descubre pronto: preferible `<img>`/`NuxtImg` con `alt` apropiado (decorativa: `alt=""`). Peso objetivo de la foto móvil: < 150-200 KB.
- Foto editable desde el panel: exigir `alt` opcional editable y crédito de foto. Si lleva texto de H1 encima, la imagen es decorativa (`alt=""`); el significado está en el texto.
- El degradado negro es necesario para el contraste: comprobar que el texto cumple WCAG AA (4.5:1) sobre cualquier foto que Xavi suba. Sugerir a buho-pixel dar margen de seguridad o un aviso en el panel.
- Schema: la home puede llevar `WebSite` (con nombre ChalkGuide) y `Organization`/`Person` (Xavi como autor) en JSON-LD; no `AggregateRating` aquí. Lo implemento yo cuando se cierre la slide.

**Autoplay: NO (recomendado)**
- Conversión: el contenido que se mueve solo se lee a medias y se pierde el CTA justo cuando el usuario iba a pulsar; el mensaje de presentación (slide 1) debe quedarse. Los estudios habituales de carruseles muestran que casi todos los clics se concentran en la primera slide.
- Accesibilidad: autoplay exige botón de pausa y respetar `prefers-reduced-motion` (WCAG 2.2.2). Sin autoplay se evita todo ese riesgo.
- Rendimiento: menos JS y menos trabajo en el hilo principal.
- Si Xavi quiere movimiento, que sea **solo tras interacción** (flechas, puntos, swipe), nunca rotación automática. Alternativa: 1 rotación opcional con pausa y sin que la slide 1 desaparezca.

**Medición (eventos de conversión, respetuosos con privacidad)**
Analítica sin cookies ni tracking personal (la herramienta concreta la propongo y Xavi aprueba antes; no añadir ningún script de terceros sin su visto bueno). Eventos agregados, sin identificadores personales:
- `hero_cta_click` con `slide` (presentacion/articulo/pies-de-gato) y `cta` (primary/secondary).
- `hero_slide_view` / `hero_slide_change` (solo si hay interacción) para saber si alguien llega a la slide 2/3.
- `newsletter_signup` con `source` (hero, home-bloque, layout, articulo) para atribuir suscripciones; el origen del consentimiento ya se registra por RGPD, aprovechar ese campo.
- `newsletter_signup_start` (interacción con el formulario) para ver abandono.
- Scroll a «Por dónde empiezas» (`profile_path_click` con `profile`) para comprobar que hero y caminos no se canibalizan.
KPI principal: **suscripciones por 100 visitas a la home**, por fuente. Secundarios: CTR del CTA primario, CTR de la slide 2, % de usuarios que interactúan con el slider (esperable bajo).

**Foto: ¿variante por idioma?**
No. Es una foto de ambiente de escalada, sin texto incrustado. Una sola foto para es y en. Lo que cambia por idioma son H1, subtítulo, CTA y `alt`. Regla: **ningún texto dentro de la imagen** (ni accesible ni traducible, y mata el SEO). Sí conviene `alt`/crédito traducible en el panel. Revisar la elección de foto: que sea un escenario real de Barcelona (rocódromo o roca cercana), no genérica de stock; refuerza la credencial.

## 5. Textos propuestos (es / en-GB), para pulir por loro-lola

Marca siempre «ChalkGuide». Costes, no costos. Inglés británico.

**Slide 1 · Presentación**

| Elemento | es | en-GB |
| --- | --- | --- |
| Eyebrow (opcional) | ChalkGuide · Escalada en Barcelona | ChalkGuide · Climbing in Barcelona |
| H1 (rec.) | Escalar en Barcelona, con alguien que ya lo ha probado | Climbing in Barcelona, from someone who has already tried it |
| H1 alt. B | La guía independiente de escalada en Barcelona | The independent guide to climbing in Barcelona |
| H1 alt. C | Rocódromos, pies de gato y consejos de escalada en Barcelona, sin patrocinios | Barcelona climbing gyms, shoes and advice, no sponsorship |
| Subtítulo (rec.) | Fichas de rocódromos, comparador de pies de gato, resoladores y artículos en primera persona. Independiente: lo pagado se marca. | Gym profiles, a climbing shoe comparison, resolers and first-person articles. Independent: anything paid is labelled. |
| Subtítulo alt. B | Un medio editorial para escaladores de Barcelona: dónde escalar, qué material comprar y cómo mejorar, contado con datos y sin postureo. | An editorial site for Barcelona climbers: where to climb, what kit to buy and how to improve, told with real data and no posturing. |
| Subtítulo alt. C | Lo que me habría gustado encontrar cuando empecé: rocódromos, material y consejos de escalada en Barcelona. | What I wish I had found when I started: gyms, kit and climbing advice for Barcelona. |
| CTA primario | Ver los rocódromos | See the climbing gyms |
| CTA secundario | Recibe la newsletter mensual | Get the monthly newsletter |
| Credencial | Independiente · Lo pagado se marca · Por Xavi, 6 años escalando en BCN | Independent · Anything paid is labelled · By Xavi, 6 years climbing in BCN |
| Credencial dinámica (opc.) | {n} rocódromos visitados | {n} gyms visited |

Nota en-GB: el término local "rocódromo" se traduce como *climbing gym* (o *climbing centre*, más británico en rótulos). Dejar "gym" en cuerpos y títulos por brevedad; loro-lola decide. "Pies de gato" = *climbing shoes*.

**Slide 2 · Artículo destacado**

| Elemento | es | en-GB |
| --- | --- | --- |
| Etiqueta | Destacado · {categoría} | Featured · {category} |
| Título | (el del artículo) | (el del artículo; solo si existe versión en inglés) |
| CTA | Leer el artículo | Read the article |
| Crédito foto | Foto: {credit} (ya existe) | Photo: {credit} |

**Slide 3 (opcional) · Comparador de pies de gato**

| Elemento | es | en-GB |
| --- | --- | --- |
| Título (h2) | Compara pies de gato lado a lado | Compare climbing shoes side by side |
| Texto | Hasta 3 modelos, con datos técnicos y mi opinión sobre los que he usado. | Up to 3 models, with technical specs and my take on the ones I have used. |
| CTA | Comparar pies de gato | Compare climbing shoes |
| Aviso (si hay afiliado) | Algunos enlaces son de afiliado y están marcados. | Some links are affiliate links and are labelled. |

**Accesibilidad / controles (microcopy para buho-pixel y loro-lola)**
- Región: «Destacados» / "Highlights"; «Diapositiva {n} de {total}» / "Slide {n} of {total}"; «Anterior» / "Previous"; «Siguiente» / "Next".

## Pendientes y supuestos
- Confirmar rutas reales de destino (listado de rocódromos, comparador, ancla de newsletter) con coneja-lucky.
- «6 años escalando en BCN» y la cita de autor aparecen como dummy en i18n: Xavi confirma antes de publicar.
- Herramienta de analítica sin cookies: propuesta aparte; ningún script de terceros hasta aprobación de Xavi.
- Foto del hero: editable desde el panel (jabali-javi para almacenamiento/campo; leona-lia si se toca bucket o policies). Requisitos de contenido: `alt`, crédito, peso, contraste.
- Si se añade formulario de email en el hero: casilla desmarcada y registro de fecha y origen (RGPD), doble opt-in.
