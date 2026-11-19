# Spec SEO de /noticias (F8 · tarea 8.4)

Autor: lince-max. Fecha: 2026-11-13. **Actualización 2026-11-19 (D91): la sección 19 sustituye a la «Nota de Xavi» como criterio de indexación y de valor; donde las secciones 1, 3, 4, 6, 8, 12 y 17 hablen de «nota de Xavi» o «≥ 60 palabras», manda la sección 19 (aporte).** Solo especificación: no hay código. La implementa lince-max en 8.11 sobre lo que entregue coneja-lucky en 8.10.

Base: D3 (sin versión en inglés no se publica en `/en`), D14 (un sitemap con alternates), D67 (`chalkguide.es`), D69 (eventos propios en `guide.events`), D71 (siempre con fuente, resumen propio, imagen solo con licencia), D73 (ficha `noindex` salvo «Nota de Xavi»), D74 (nada se publica solo). Se reutiliza lo que ya hace el blog: `usePageSeo`, `useListingSeo`, `useSiteSeo` (canonical y hreflang salen de la ruta), `useJsonLd`, `articleLd` en `app/utils/schema.ts`, reglas compartidas en `app/utils/seo.ts` y fuente de sitemap en `server/api/__sitemap__/urls.ts`.

## 1. Resumen de la recomendación

1. El valor SEO de /noticias es el **índice** y las fichas **con Nota de Xavi**. Una ficha que solo resume una fuente ajena no aporta nada distinto de la fuente: va `noindex, follow` y fuera del sitemap (D73). Su función es dar contexto en la newsletter, en el índice y en la home, no posicionar.
2. La palanca de crecimiento es la nota de Xavi: cada ficha con nota es contenido original con autor, y es la que justifica indexar. Sin nota no se indexa, sin excepciones.
3. Canonical siempre propio. Nunca apuntar a la fuente.
4. `Article` con `isBasedOn` y `citation`, no `NewsArticle` ni Google News (justificación en 5 y 9).
5. La captación de newsletter va en el índice y en cada ficha, con origen `noticias` registrado.

## 2. Rutas y slugs (es/en)

Siguen el patrón de `i18n/localized-routes.ts`: slug traducido, es sin prefijo, en bajo `/en`. Se proponen cuatro rutas nuevas (nombres Nuxt `news`, `news-slug`, `news-category-slug`):

| Nombre | es | en | Render |
| --- | --- | --- | --- |
| `news` | `/noticias` | `/en/news` | `LIVE` (ISR 10 min) |
| `news-category-slug` | `/noticias/categoria/[slug]` | `/en/news/category/[slug]` | `LIVE` |
| `news-slug` | `/noticias/[slug]` | `/en/news/[slug]` | `LIVE` (no `DETAIL`: una nota de Xavi o una corrección debe verse en minutos) |

- Respuesta a «¿`/en/news`?»: sí. Mismo criterio que `/agenda` y `/events`.
- Slug: lo genera el sistema desde el titular propio (no el de la fuente), minúsculas y sin acentos, único por idioma, máximo 80 caracteres. El slug `en` solo existe si la noticia tiene versión en inglés. Si el slug se cambia, redirigir 301 el antiguo.
- Búsqueda y paginación son **query**, no rutas: `?q=` (ya está en `LISTING_QUERY_KEYS`) y `?pagina=N` (en inglés se acepta el mismo parámetro `pagina` para no duplicar lógica; añadirlo a `LISTING_QUERY_KEYS`). No crear `/noticias/pagina/2`.
- Una noticia sin versión en inglés devuelve 404 en `/en/news/{slug}` (D3), nunca contenido en español bajo `/en`.
- Una noticia rechazada, despublicada o borrada: 404. Si tenía nota de Xavi y estuvo indexada: 410 (señal más rápida de retirada). Purgar la caché ISR al despublicar (ya previsto en 8.10).
- Añadir las tres entradas a `localizedRoutes` y a `i18nPages()`; `localizedRouteRules()` les da el render.

## 3. Title y description

Reglas existentes: título hasta 60 caracteres con sufijo ` · ChalkGuide` solo si cabe (`titleWithBrand`), descripción hasta 158 (`clampDescription`), únicos por idioma. Los textos finales los afina loro-lola; esto es la plantilla.

| Página | Title es | Title en | Description |
| --- | --- | --- | --- |
| Índice | `Noticias de escalada en Cataluña y España` | `Climbing news from Catalonia and Spain` | Qué contiene (resúmenes propios con fuente, Cataluña, España, internacional) y la voz de Xavi. Ej. es: «Lo que pasa en la escalada de Cataluña y España, resumido y con la fuente enlazada. Selección de Xavi, una vez por semana en tu correo.» |
| Categoría | `{Categoría}: noticias de escalada` | `{Category}: climbing news` | Texto introductorio propio de la categoría (obligatorio para indexar, ver 4). |
| Ficha | Titular propio de la noticia (no copiado de la fuente) | Ídem traducido | Primera frase de la «Nota de Xavi» si existe; si no, inicio del resumen propio. |

- El titular propio debe diferir del de la fuente: lo exige el prompt (8.3) y se comprueba en revisión. Un titular idéntico al de la fuente es una señal de duplicado.
- Los textos SEO viven en `seo.*` de los locales (como `seo.gymTitle`); el contenido de cada ficha sale de la base. Si `seo_title`/`seo_description` están vacíos se usa titular y resumen.

## 4. Robots por caso

La indexación depende de datos, por eso va solo en `<meta robots>` (como categorías finas y meses pasados), sin `X-Robots-Tag` en `routeRules`. Sin valor explícito, decide el módulo de robots (indexable solo en producción con dominio real).

| Caso | Robots | Canonical | En sitemap |
| --- | --- | --- | --- |
| Índice `/noticias` página 1, sin query | indexable | propio | sí |
| Índice con `?pagina=N` (N ≥ 2) | `noindex, follow` | índice limpio (lo hace `useSiteSeo`: quita query) | no |
| Índice con `?q=` (búsqueda) | `noindex, follow` | índice limpio | no |
| Índice con otro filtro por query | `noindex, follow` | índice limpio | no |
| Categoría con ≥ 3 noticias publicadas y texto introductorio propio | indexable | propio | sí |
| Categoría con menos o sin texto | `noindex, follow` | propio | no |
| Ficha **sin** Nota de Xavi | `noindex, follow` | propio | no |
| Ficha **con** Nota de Xavi (y publicada) | indexable | propio | sí |
| Ficha en borrador o rechazada | no sirve (404); no llega a existir en público | n/a | no |
| `/en/news...` | mismos casos, más el umbral de 5 | propio | solo con versión en inglés |

- `follow` siempre: las fichas `noindex` siguen pasando enlaces a rocódromos, artículos y eventos.
- No bloquear nada en `robots.txt` (Google debe poder leer el `noindex`), igual que hoy en `nuxt.config.ts`.
- Paginación: Google ya no usa `rel=prev/next`. Las páginas 2+ son `noindex, follow` porque son un archivo de resúmenes sin valor propio; las fichas con nota se descubren por el sitemap, no por la paginación.
- Umbral `/en`: añadir `news: 3` a `MIN_ENGLISH_LISTING` y `'news'` a `ListingKind`. Bajo el umbral, `/en/news` es `noindex, follow` y sin alternates (lo resuelve `useListingSeo('news', …)`). Cuenta solo noticias con versión en inglés publicada.
- Umbral del índice `/noticias`: indexable desde ≥ 6 noticias publicadas; antes `noindex, follow` (evita indexar una página casi vacía al lanzar).
- Función compartida nueva en `app/utils/seo.ts`: `isNewsIndexable({ hasNote, published })` y `isNewsCategoryIndexable(count, description)` (con `MIN_CATEGORY_ARTICLES`, mismo umbral que el blog). La usan la app y el servidor, así sitemap y meta nunca discrepan.

## 5. Canonical

Canonical **propio** en cada URL (autorreferencia en indexables y en las `noindex`). `useSiteSeo()` ya lo emite sin query.

Por qué no apuntar a la fuente:
- Es un resumen propio, no una copia. El canonical es para páginas duplicadas; declararlo equivale a decir «esta página no es mía» y cede todo el valor a un tercero.
- Con nota de Xavi, la página tiene contenido original: debe posicionarse ella.
- Apuntar a una URL de otro dominio es válido técnicamente pero Google lo trata como pista, no orden, y regala autoridad sin contrapartida.
- La `noindex` de las fichas sin nota ya resuelve la duplicidad; mezclar `noindex` con canonical a otro sitio envía señales contradictorias (Google desaconseja combinarlos).

## 6. Schema.org (JSON-LD)

### Ficha con nota (indexable): `Article` con `isBasedOn`

Reusar `articleLd` y ampliarlo (o crear `newsItemLd` en `app/utils/schema.ts`) con:

- `@type: Article`, `headline` (titular propio), `description`, `image` (solo si hay imagen con licencia), `datePublished` (fecha de aprobación de Xavi, no la de la fuente), `dateModified` (cambio real de contenido), `inLanguage`, `articleSection` (categoría), `mainEntityOfPage`, `author` = `Person` Xavi (la nota es suya), `publisher` = `Organization` del sitio.
- `isBasedOn`: `{ "@type": "NewsArticle", "url": <source_url>, "name": <titular de la fuente>, "publisher": { "@type": "Organization", "name": <fuente> }, "datePublished": <fecha fuente si se conoce> }`.
- `citation`: la misma `url` de la fuente como `CreativeWork` (o solo la URL). Se pone `isBasedOn` como principal; `citation` repite la fuente para reforzarla.
- `BreadcrumbList` (Inicio › Noticias › Categoría › titular) con `useBreadcrumbJsonLd`.
- Ficha `noindex`: no emitir JSON-LD de `Article` (no aporta y evita datos estructurados en páginas que se excluyen). Sí se mantiene el `BreadcrumbList` por coherencia con navegación; opcional.

Por qué `Article` y no `NewsArticle`:
- `NewsArticle` declara periodismo propio de una redacción (hecho noticioso original). Es un resumen de otro medio con una nota de opinión: describirlo como reportaje original sería inexacto. `isBasedOn` es la propiedad que dice la verdad: «derivado de esta fuente».
- Google trata `Article`, `NewsArticle` y `BlogPosting` igual para los resultados enriquecidos; no se pierde nada. Consistente con los artículos del blog.
- Revisable: si en el futuro Xavi hace cobertura original (entrevistas, eventos), esas piezas pueden ir como `NewsArticle`.

### Índice y categoría: `CollectionPage` + `ItemList`

- `CollectionPage` con `name`, `description`, `inLanguage`, `isPartOf` (WebSite) y `mainEntity: ItemList`.
- `ItemList` con `itemListElement[]`: `ListItem` con `position` y `url` (URL de la ficha). Solo las de la página actual, máximo 12. Incluir las fichas `noindex` es válido (el listado enlaza a ellas), pero para no apuntar a páginas excluidas se recomienda listar **solo las indexables con nota** si hay ≥ 3; si no, omitir `ItemList`. Decisión: emitir `ItemList` únicamente con fichas indexables.
- Páginas 2+, búsqueda y filtros (`noindex`): sin JSON-LD de listado.
- `BreadcrumbList` en categoría.

### No usar
`NewsArticle` con `Organization` como autor, `Review`, `AggregateRating`, `speakable`, `ClaimReview`. Sin `Organization.sameAs` nuevo (ya está en el layout).

## 7. Enlace de salida a la fuente

- Presente en cada ficha (obligatorio, D71) y visible sin abrir nada: botón o enlace «Leer en {nombre de la fuente}» con texto descriptivo. Es parte de la propuesta de valor: transparencia de cita.
- Atributos: `target="_blank" rel="noopener"`. **Sin** `nofollow` por defecto, porque es una cita editorial aprobada por Xavi (D74), no un enlace de pago ni de usuario. Citar fuentes fiables es una señal de calidad y de confianza.
- `rel="nofollow noopener"` cuando la fuente no esté verificada por Xavi (campo `trusted` en `news_sources`, ver 11) o cuando la rutina añada una fuente nueva sin revisar.
- `rel="sponsored nofollow noopener"` si el enlace es de afiliado o contenido patrocinado (regla de `.ai/marketing-seo.md`); no se espera en noticias, pero la regla manda.
- `noreferrer` no: el sitio de la fuente debe ver que le enviamos tráfico, es la contrapartida de la cita. El `Referrer-Policy` del sitio (`strict-origin-when-cross-origin`) ya limita lo que viaja.
- **Sin UTM** en el enlace de salida: ensucia las analíticas de un tercero, no aporta a ChalkGuide (medimos el clic nosotros) y puede romper la URL canónica de la fuente. Se enlaza la URL original, limpia de parámetros de seguimiento.
- Solo `https://` y validar en servidor (jabali-javi/leona-lia): rechazar `javascript:` y `data:` en `source_url`.

## 8. Sitemap

Un solo sitemap (D14). Ampliar `server/api/__sitemap__/urls.ts`:

- Incluir: `/noticias` (si ≥ 6 noticias), categorías indexables, fichas **con nota** y publicadas. Con `alternatives` es/en/x-default solo cuando ambas versiones existen (reusar `entries()`); si solo existe es, solo es.
- Excluir: fichas sin nota, borradores, rechazadas, páginas con query (`?pagina`, `?q`), categorías bajo el umbral, `/en/news` bajo el umbral.
- `lastmod`: ficha = `max(updated_at de la nota, updated_at del resumen)`; **no** tocar el `lastmod` por cambios de metadatos de ingesta (reprocesado, `dedupe_key`). Índice = fecha de publicación de la noticia más reciente publicada. Categoría = ídem de su categoría.
- Fecha en ISO 8601. No inventar `priority` ni `changefreq` (Google los ignora).
- Mantener la regla de `.ai/marketing-seo.md`: el sitemap sale vacío si el entorno no es indexable.

## 9. hreflang

- Lo emite `useSiteSeo()` desde `usePageLocales()` (`current.value.available`). La página de noticia debe declarar sus idiomas reales: `['es']` o `['es','en']` según `title_en`/`summary_en` completos. Sin `en`: no hay alternates en la ficha `es` y `/en/news/{slug}` da 404 (D3).
- Índice y categoría: lo resuelve `useListingSeo('news', …)` con el umbral de 3 (ver 4).
- `x-default` apunta a la versión `es`.
- Las traducciones al inglés las revisa loro-lola; una traducción automática sin revisar no se publica en `/en`. Dado que la newsletter solo sale en español (D75), el inglés puede quedarse corto al principio: es esperable y el umbral lo contempla.

## 10. Open Graph y Twitter

`usePageSeo` ya cubre og/twitter (`summary_large_image`) con imagen por defecto 1200×630.

- Índice y categorías: `og:type=website`, imagen por defecto del idioma (`/og-default.png`, `/og-default-en.png`).
- Ficha con nota: `og:type=article`, `article:published_time`, `article:modified_time`; imagen propia solo si hay licencia (D71); si no, imagen por defecto. **No** reutilizar la imagen de la fuente (derechos y hotlink).
- Ficha sin nota: mismas etiquetas (se comparte en redes aunque no se indexe), `og:type=article`.
- `og:locale` y `og:url` los da `useSiteSeo`. Sin `twitter:site` si no hay cuenta aprobada.
- Mejora opcional (esfuerzo medio): plantilla de imagen OG por categoría con titular, generada en build o a mano por buho-pixel. No hace falta para lanzar.

## 11. Google News: no solicitar

No aplicar a Google Noticias / Publisher Center. Motivos:
1. Requiere periodismo original y transparencia de redacción (autoría, contacto, política editorial). ChalkGuide resume fuentes ajenas; la parte original (nota de Xavi) es pequeña. Riesgo de rechazo o de ser tratado como agregador.
2. Volumen: la frecuencia de ChalkGuide es de unas decenas de notas al mes, no continua.
3. Beneficio nulo para el objetivo: el negocio son altas de newsletter locales, no tráfico de actualidad masivo. «Noticias de escalada» tiene poca demanda de búsqueda en Google News; el tráfico valioso es el de búsquedas locales evergreen.
4. Riesgo reputacional: agregador de baja diferencia puede afectar a la evaluación de calidad del dominio (política de contenido de baja calidad / contenido reescrito).
5. No hace falta `NewsArticle` ni feeds especiales. Revisar en 12 meses solo si Xavi produce cobertura original regular.

## 12. Riesgo thin y duplicado, y mitigación

Riesgos reales: (a) resumen de la rutina muy parecido a la fuente (duplicado casi literal); (b) cientos de fichas finas diluyen el dominio nuevo (chalkguide.es); (c) la política de Google sobre «scaled content abuse» y contenido de bajo valor generado a escala con IA sin supervisión; (d) derechos de autor.

Mitigaciones, por orden de impacto:
1. **Indexar solo lo que tiene valor propio**: la política D73 (solo con nota de Xavi) es la mitigación principal. Hay que mantenerla en un único sitio: `isNewsIndexable()`.
2. **Nada se publica sin que Xavi lo apruebe** (D74): el filtro humano responde a la política de contenido a escala.
3. **Resumen propio, no extracto**: el prompt (8.3) exige reescritura y prohíbe frases largas copiadas. Verificación en el piloto (8.8): ninguna frase de más de 8 palabras idéntica a la fuente. Cita corta entre comillas solo si es breve y atribuida.
4. **Longitud mínima de nota**: para que una ficha pase a indexable, la «Nota de Xavi» debe tener al menos ~60 palabras (valor propuesto; ajustable). Una nota de una línea no justifica indexar. Validarlo en el panel o en `isNewsIndexable`.
5. **Titular propio** y descripción propia (ver 3).
6. **Índice con texto introductorio propio** (80 a 120 palabras, de Xavi) y enlace a `/transparencia` explicando cómo se selecciona y se cita.
7. **Tope de crecimiento del índice**: paginación `noindex`, y no listar más de 12 por página.
8. **Archivo**: las noticias antiguas sin nota no se indexan nunca; con nota se mantienen (valor evergreen).
9. **Imágenes**: solo con licencia (D71), `alt` propio.
10. **Corrección de errores**: si una fuente se retracta, la ficha se despublica (404 o 410).

## 13. Enlazado interno

Objetivo: pasar autoridad de las noticias (efímeras) a las páginas que posicionan y convierten (rocódromos, artículos, comparador, agenda).

- En ficha: bloque «Relacionado» con hasta 3 enlaces **elegidos por Xavi** o sugeridos por la rutina y aprobados: rocódromo (`/rocodromos/{slug}`), artículo del blog, evento de la agenda, pies de gato. Nunca autolinking por palabra clave en el cuerpo. Texto de anclaje natural (el nombre del rocódromo o el título del artículo), no keywords repetidas.
- Dato a modelar (para jabali-javi, 8.5): relación `news` → `items` / `articles` / `events` (tabla puente o arrays de `uuid`); el servidor valida que existan y estén publicados.
- Desde fichas de rocódromo y evento: bloque opcional «Últimas noticias de este rocódromo / de este evento» (si hay ≥ 1 noticia publicada). Enlaza a fichas de noticia aunque sean `noindex` (sigue pasando valor con `follow`).
- Desde artículos del blog: «Noticias relacionadas» opcional por categoría.
- Home: el bloque de noticias (8.10) enlaza a `/noticias` y a las 3 últimas. Enlace «Ver todas» como `<a>` real, no botón con JS.
- Migas de pan en ficha y categoría (con `BreadcrumbList`).
- Cada ficha enlaza a `/noticias` y a su categoría; el índice enlaza a todas las categorías (navegación plana, profundidad 2).
- Anclajes y enlaces rastreables: `<a href>`, no navegación por `@click` (con SSR/ISR todo llega en HTML).

## 14. Eventos de analítica

Capa propia de D69 (`guide.events`), sin cookies ni datos personales, siempre activa; pasan por `useTrack`. Se añaden a la lista cerrada de `guide.track_event` (jabali-javi) y a `content_type` el valor `news`.

| Evento | Cuándo | Parámetros | Capas |
| --- | --- | --- | --- |
| `page_view` (existente) | Carga o navegación | `content_type = news` para ficha, `content_slug` | P, G, M |
| `news_source_click` | Clic en «Leer en {fuente}» | `content_slug` de la noticia, `content_type = news`, `target` = host de la fuente (sin ruta ni query), `locale` | P, G |
| `news_filter` | Se elige categoría o filtro | `pillar` = slug de categoría (valor cerrado); nunca texto libre | P |
| `search_news` | Se envía una búsqueda | Sin el texto buscado (igual que `search_blog`) | P |
| `news_note_view` | La nota de Xavi entra en pantalla (una vez) | `content_slug` | P (diagnóstico de si la nota se lee) |
| `ficha_click` (existente) | Clic de noticia a rocódromo, artículo o evento | `content_slug` origen, `content_type` destino | P, G |
| `newsletter_view` / `newsletter_submit` (existentes) | Bloque visible / alta | `content_slug = noticias` o el de la ficha, `pillar` = categoría | P (+ G y M el submit, según D69) |

Cambios de esquema que se piden a jabali-javi (revisión de leona-lia):
- Añadir `news` a `content_type` y los nombres nuevos al `check`.
- Columna `target text null` (host de la fuente, máx. 100 caracteres, sin ruta ni query) para `news_source_click`. Alternativa sin columna nueva: no medir por fuente y solo contar clics por noticia. Recomendado: añadir `target`, aporta una métrica útil (qué fuentes reciben más interés) sin datos personales.
- Los eventos de salida nunca llevan la URL completa de la fuente ni parámetros.
- El clic de salida se envía con `navigator.sendBeacon` o `fetch keepalive` antes de salir, sin retrasar la navegación.
- Eventos hacia GA4 y Meta solo con consentimiento (D69); `news_source_click` no se envía a Meta.

KPIs a seguir con estos eventos: clic a fuente por noticia (calidad de la selección), tasa de lectura de nota, altas de newsletter por 1.000 visitas de /noticias y por origen `noticias`, páginas vistas de fichas indexadas frente a no indexadas (Search Console para impresiones y clics de las indexables).

## 15. Captación de newsletter en /noticias

El objetivo del negocio es el alta. /noticias es el sitio con la promesa más natural: la newsletter semanal (D75) es literalmente el resumen de estas noticias más los eventos de los 14 días siguientes.

- Índice: bloque de newsletter (el componente existente, con casilla RGPD desmarcada) **después de la 3.ª noticia** y otro al final de la lista. Máximo dos por página. Sin modal, sin popup ni barra fija: afecta a LCP, CLS y a la sensación editorial.
- Ficha: bloque al final del cuerpo (tras la nota de Xavi y antes de «Relacionado»), con mensaje contextual: «Esto y más, cada semana en tu correo».
- Promesa clara: frecuencia (semanal), contenido (noticias + eventos + último artículo) e idioma (español; D75 no hay versión en inglés). En `/en`, avisar de que la newsletter está en español (la copia de loro-lola, 8.12).
- Origen: guardar `origen_articulo = noticias` (o `noticias/{slug}` normalizado) en `guide.subscribers` al alta (regla 8 de RGPD: registro de fecha y origen). Reutilizar el mecanismo ya existente en el bloque.
- Medición: `newsletter_view` y `newsletter_submit` con `content_slug` (ver 14).
- Páginas `noindex` también muestran el bloque: aunque no atraigan SEO, reciben tráfico desde redes y desde la propia newsletter, y convierten.
- No condicionar el acceso a la ficha al alta (sin paywall ni muro de registro).

## 16. Prioridad (impacto / esfuerzo)

| # | Acción | Impacto | Esfuerzo |
| --- | --- | --- | --- |
| 1 | `isNewsIndexable` + `noindex` en fichas sin nota + sitemap solo indexables | Alto (evita thin) | Bajo |
| 2 | Canonical propio + hreflang con D3 | Alto | Bajo (reuso) |
| 3 | Bloque de newsletter con origen `noticias` | Alto (negocio) | Bajo (reuso) |
| 4 | `Article` + `isBasedOn` en ficha con nota; `CollectionPage`/`ItemList` en índice | Medio | Medio |
| 5 | Enlazado interno por relaciones aprobadas | Medio | Medio (modelo + UI) |
| 6 | Eventos de analítica y columna `target` | Medio | Medio (jabali) |
| 7 | OG por categoría | Bajo | Medio |
| 8 | Google News | No aplicar | n/a |

## 17. Checklist verificable para 8.11

Tras implementar, con `npm run build`, `npm run lint`, `npm run typecheck` en verde y un entorno con `NUXT_SITE_INDEXABLE=true`:

Rutas y render
- [ ] `/noticias`, `/noticias/categoria/{slug}`, `/noticias/{slug}`, `/en/news`, `/en/news/category/{slug}` y `/en/news/{slug}` resuelven; no existen `/en/noticias` ni `/noticias/pagina/N`.
- [ ] Noticia sin versión en inglés: `/en/news/{slug}` devuelve 404 (D3).
- [ ] Noticia despublicada o rechazada: 404 (410 si tenía nota).

Robots y canonical
- [ ] Ficha sin nota: `<meta name="robots" content="noindex, follow">` y ausente del sitemap.
- [ ] Ficha con nota publicada: sin meta `robots` de exclusión y presente en el sitemap.
- [ ] `/noticias?pagina=2`, `?q=…` y cualquier otra query: `noindex, follow`, canonical = `/noticias` limpio, ausentes del sitemap.
- [ ] Categoría con < 3 noticias o sin texto: `noindex, follow`.
- [ ] `/en/news` bajo el umbral de 3: `noindex, follow` y sin `hreflang`.
- [ ] Canonical de toda página = su propia URL absoluta en `chalkguide.es` (nunca la URL de la fuente).
- [ ] `isNewsIndexable` se usa en la app y en el servidor (mismo archivo, sin lógica duplicada).

Metadatos
- [ ] `title` ≤ 60 caracteres y `description` ≤ 158, únicos por idioma y por página; el titular no coincide con el de la fuente.
- [ ] og:title, og:description, og:image, og:url, og:type, og:locale y twitter:card presentes; `og:type=article` en ficha; sin imagen de la fuente.

hreflang y sitemap
- [ ] Alternates es/en/x-default solo cuando existen ambas versiones; `x-default` = es.
- [ ] Un único sitemap con alternates (D14); solo indexables; `lastmod` ISO 8601 que no cambia con la ingesta; vacío si el entorno no es indexable.

Schema.org
- [ ] Ficha con nota: `Article` válido (Rich Results Test y validador de Schema.org) con `author` Xavi, `isBasedOn` y `citation` a la fuente, `datePublished` = fecha de aprobación.
- [ ] Ficha sin nota: sin `Article`.
- [ ] Índice y categoría indexables: `CollectionPage` + `ItemList` solo con fichas indexables; páginas 2+ y búsqueda sin JSON-LD.
- [ ] `BreadcrumbList` en ficha y categoría. Ningún `AggregateRating`.

Enlace a la fuente
- [ ] Cada ficha muestra «Leer en {fuente}» con `rel="noopener"` y `target="_blank"` (con `nofollow` si la fuente no es de confianza; `sponsored nofollow` si es afiliado). Sin parámetros UTM. Solo `https://`.

Enlazado interno
- [ ] Ficha con ≥ 1 enlace a rocódromo, artículo o evento cuando hay relación; el HTML servido (view-source) contiene los `<a href>`.
- [ ] Migas de pan visibles y en JSON-LD; el índice enlaza a todas las categorías.

Analítica
- [ ] `news_source_click`, `news_filter`, `search_news` y `news_note_view` llegan a `guide.events` sin IP, user agent ni texto libre; `target` solo guarda el host.
- [ ] Sin consentimiento no se emite nada a GA4/Meta; `news_source_click` no sale a Meta.

Newsletter
- [ ] Bloque en el índice (tras la 3.ª noticia y al final) y en cada ficha; casilla RGPD desmarcada; origen `noticias` guardado; sin modal ni barra fija.
- [ ] `/en/news` avisa de que la newsletter es en español.

Rendimiento
- [ ] LCP del índice y la ficha ≤ 2,5 s en móvil (Lighthouse sobre preview) y CLS < 0,1 con el bloque de newsletter incluido.

Operación
- [ ] Publicar o despublicar purga la caché ISR de la ficha, el índice y la categoría.
- [ ] Search Console: enviar el sitemap, vigilar «Excluida por noindex» (esperada para fichas sin nota) y «Rastreada, actualmente sin indexar» (señal de thin).

## 18. Pendiente y dependencias

- jabali-javi (8.5): campos `has_note`/`note_html` y longitud mínima, `trusted` en `news_sources`, relación de noticias con rocódromos, artículos y eventos, `news` en `content_type` y columna `target` en `guide.events`. leona-lia revisa.
- coneja-lucky (8.10): componentes, rutas nuevas en `localized-routes.ts` y bloques de newsletter y relacionados.
- loro-lola (8.3 y 8.12): titular propio, regla de resumen sin copia, textos `seo.*` es/en, texto introductorio de /noticias y de categorías, aviso de newsletter en español.
- buho-pixel (8.2): ubicación visual de la nota de Xavi, del bloque de newsletter y del enlace de fuente (visible, con confianza).
- Decisión de Xavi: confirmar longitud mínima de la nota para indexar (propuesta: ~60 palabras) y el umbral de 6 noticias para indexar el índice.

## 19. Aporte propio (D91, tarea 8.20a)

Sustituye a la «Nota de Xavi» de D73/D79. /noticias es un agregador: el valor para el lector es descubrir y saltar a la fuente. El valor para Google es el **aporte**: contexto propio, útil para quien escala en Barcelona y Cataluña, que no existe en la fuente. La rutina de IA lo redacta; Xavi lo revisa y lo edita al aprobar (D74). Sin aporte válido, la ficha no se indexa.

### 19.1 Qué es un aporte válido

Política de Google sobre «scaled content abuse»: produce penalización el contenido generado a escala (con IA o sin ella) cuyo fin principal es posicionar y que no aporta valor al usuario, incluido reescribir o resumir fuentes sin añadir nada. No penaliza que lo redacte una IA, sino que sea genérico, repetible y sin supervisión. Defensas de ChalkGuide: aporte con información que la fuente no trae, revisión humana de cada pieza, volumen bajo y enlace visible a la fuente.

Un aporte es válido solo si cumple **todos** estos criterios:

1. **Información nueva respecto a la fuente.** Contiene al menos un dato o relación que el lector no encuentra en la noticia: una ficha de ChalkGuide relacionada, una comparación con otra vía o zona, un grado de referencia, un dato práctico (acceso, época, horarios, precio).
2. **Anclaje local.** Explica por qué importa a quien escala en Barcelona o Cataluña: distancia, rocódromo donde entrenar algo parecido, zona de vías equivalentes, evento cercano. Si la noticia es internacional y no hay relación local honesta, el aporte dice qué se puede aprender o entrenar, sin forzar un vínculo falso. Si ni así hay valor, la noticia se publica sin indexar (19.4) o no se publica.
3. **Verificable.** Cada dato sale de (a) la propia fuente (con atribución: «según Desnivel», «según el comunicado de la federación»), o (b) una ficha de ChalkGuide publicada (rocódromos, artículos, eventos, resoladores). Nada más. La rutina no inventa, no completa de memoria y no usa otras webs como fuente de contexto.
4. **Propio en la forma.** Ninguna frase de más de 8 palabras idéntica a la fuente (mismo control que el resumen, sección 12.3). El aporte no repite el resumen con otras palabras: el resumen dice qué ha pasado; el aporte dice qué significa para el lector.
5. **Útil sin ser opinión disfrazada de hecho.** Valoraciones permitidas solo si Xavi las ha editado y firma el criterio; la rutina redacta contexto, no juicios.
6. **Distinto de otras fichas.** No es una plantilla con huecos. Dos aportes de la misma semana no pueden compartir el mismo esqueleto de frases. Se vigila en revisión (si tres fichas seguidas empiezan igual, Xavi pide variar).

Fuentes de contexto permitidas: fichas publicadas de ChalkGuide (rocódromos, resoladores, pies de gato, artículos, eventos, categorías) y los datos verificables que figuran en la fuente original. Prohibido: otras webs, memoria del modelo, rumores, cifras sin respaldo, y cualquier dato de personas que no esté en la fuente.

Ejemplos. Los hechos entre corchetes son marcadores: en producción salen de la fuente real y se comprueban; no copiar cifras de este ejemplo.

Noticia A (internacional): «Ainhize Belar encadena una vía de 9b [dato y lugar según la fuente]».

- Aporte malo 1 (copia): «Ainhize Belar ha encadenado una vía de 9b, un hito para la escalada femenina». Repite la fuente, sin dato nuevo ni anclaje.
- Aporte malo 2 (relleno genérico): «Esta noticia es muy importante para el mundo de la escalada. Los escaladores deben seguir de cerca los avances de las deportistas. La escalada deportiva sigue creciendo». Vale para cualquier noticia, sin hechos: es exactamente lo que Google llama contenido a escala sin valor.
- Aporte malo 3 (inventado): añade cifras de la vía, año de apertura o historia de intentos que la fuente no da. Dato no verificable: prohibido.
- Aporte bueno: «Ainhize Belar [según la fuente: fecha, vía, sector] firma un 9b en [zona]. Para ponerlo en perspectiva: el 9b es [explicación breve del grado según la fuente], lejos del rango habitual en las vías de deportiva de Cataluña, donde la mayoría de proyectos de referencia se mueven en [dato solo si hay ficha o artículo de ChalkGuide que lo respalde]. Si quieres trabajar la resistencia en panel antes de salir a la roca, en Barcelona [ficha de rocódromo X] tiene [característica comprobable en su ficha, p. ej. zona de pan extraplomada]. La noticia completa, en [fuente].»

Noticia B (local): «Festival de escalada en Barcelona [fecha y lugar según la fuente]».

- Aporte malo: «Un festival imperdible para todos los amantes de la escalada. ¡No te lo pierdas!». Publicidad vacía y sin dato.
- Aporte bueno: «El festival se celebra en [lugar] el [fecha] [según la organización]. Cómo llegar y dónde entrenar antes: [ficha del rocódromo más cercano, con su distancia o barrio]. Si quieres ver más citas del mes, la [agenda de ChalkGuide] reúne las de Barcelona. Entrada y programa completo, en la web de la organización [enlace de fuente].»

Regla práctica para la rutina y para Xavi: si borrando la noticia el aporte sigue valiendo para cualquier otra, es genérico y se reescribe. Si no hay ficha ni dato que respalde un aporte útil, la rutina lo deja vacío y marca la noticia como «sin aporte» en lugar de rellenar: queda `noindex` (19.4).

### 19.2 Longitud y estructura

- Recomendado: **80 a 180 palabras**. Mínimo editorial 80 (por debajo no hay sitio para contexto verificable más enlaces). Máximo 180: más largo compite con la propia fuente, se parece a una reescritura y se recorta en la cuadrícula. Límite duro en BD: 1.400 caracteres.
- Estructura: 1 o 2 párrafos, o una frase de arranque más 2 a 4 viñetas. Un párrafo de 2 a 4 frases es lo normal.
- Orden: (1) primera frase con el término principal y el hecho clave; (2) el contexto local o práctico; (3) enlaces internos de 19.6; (4) cierre breve que remite a la fuente. Sin llamada a la acción comercial.
- La **primera frase** debe sostenerse sola: es la que aparece recortada en la cuadrícula y la que alimenta la meta description. Entre 20 y 28 palabras, sin empezar por «Esta noticia».
- La cuadrícula de /noticias muestra el arranque: hasta ~160 caracteres, cortado en límite de palabra, con «…». Como sale de la misma frase de arranque, no hace falta un campo aparte.
- Cuenta de palabras: el texto sin marcado, igual que `noteWordCount` hoy. La rutina apunta a 100–150; el panel avisa fuera de 80–180.

### 19.3 Keywords

Cómo elegirlas (la rutina propone, Xavi corrige):

1. **Término principal** = la entidad que alguien buscaría: atleta, vía o proyecto, competición o evento, rocódromo, zona de escalada, marca o lanzamiento. Una sola por noticia.
2. **Modificador local** cuando aplique y sea cierto: «Barcelona», «Cataluña», «Montserrat», el barrio o la zona. Ej.: `festival de escalada Barcelona`, `Ainhize Belar 9b`. Si la noticia no tiene relación local real, sin modificador: no forzarlo.
3. **Forma exacta** como la escribiría un usuario: nombre propio completo y grado en su notación habitual (9b, 7c+). Singular o plural según la demanda típica; no inventar variantes.
4. Opcional una secundaria (grado, disciplina o tipo de contenido) que la rutina puede usar una vez.
5. Búsqueda previa: comprobar en Search Console, y en su defecto en el autocompletado de Google, que el término existe como búsqueda. Si es una exclusiva sin demanda, el término principal es el nombre propio que aparece en la fuente.

Dónde va la keyword (en español y en inglés, cada uno con la suya):

| Lugar | Regla |
| --- | --- |
| `title` | Al principio o cerca, dentro de los 60 caracteres; es el titular propio, no el de la fuente |
| H1 | Mismo titular, con la keyword; un H1 por página |
| H2 | Como mucho uno, natural, si el aporte lleva estructura; opcional |
| Primer párrafo del aporte | Una vez, en las primeras 25 palabras, con la forma exacta |
| Resto del aporte | Como mucho una variante o repetición más; el resto, sinónimos y nombres propios |
| `alt` de la foto | Describe la imagen con la keyword solo si es verdad lo que se ve; si no, alt descriptivo normal (D27) |
| Meta description | Va si cabe de forma natural en la primera frase |
| Slug | Lo genera el sistema; no se edita para meter keywords |

Contra el keyword stuffing: la keyword exacta aparece **2 veces como máximo** en el aporte (3 en aportes cercanos a 180 palabras), nunca en dos frases seguidas, nunca en enlaces repetidos, nunca como lista de términos. Densidad objetivo por debajo del 2 %. Prueba de lectura: si suena raro dicho en voz alta, sobra. No ocultar texto, no usar keywords en atributos ajenos, no añadir tags de keywords visibles.

### 19.4 Regla de indexación (sustituye a «nota ≥ 60 palabras»)

- **Ficha indexable** = publicada Y aporte del idioma de la página con **≥ 80 palabras** (N = 80). Si no, `noindex, follow`, fuera del sitemap. El mismo N que el mínimo editorial de 19.2, para que lo que el panel exige y lo que Google ve coincidan.
- Por idioma: `/noticias/{slug}` mira `insight_es`; `/en/news/{slug}` mira `insight_en`. Con aporte en inglés de menos de 80 palabras, la ficha `en` va `noindex` y no entra en el sitemap `en`.
- Tope superior sin efecto en indexación: un aporte de 300 palabras indexa, pero el panel avisa.
- **Descartada por Xavi (D92, 2026-11-19):** no se exige enlace interno para indexar. Texto original de la propuesta: para indexar, el aporte **debe llevar al menos un enlace interno** de `news_links`. Una ficha sin ningún vínculo con ChalkGuide no aporta contexto propio comprobable. Es una decisión de Xavi; mi recomendación es adoptarla. Si la rechaza, basta el N de palabras.
- Aviso de similitud: la columna `similarity` actual compara resumen y extracto; ampliar a aporte frente a extracto. Con similitud ≥ 0,35 (umbral ya existente en la UI) el panel avisa y se recomienda no indexar hasta que Xavi reescriba.

Impacto en el código (para 8.11 y coneja-lucky; yo toco `app/utils/seo.ts`):

- `app/utils/seo.ts`: `MIN_NEWS_NOTE_WORDS = 60` pasa a `MIN_NEWS_INSIGHT_WORDS = 80`; `noteWordCount` pasa a `insightWordCount`; `isNewsIndexable({ note, published })` pasa a `isNewsIndexable({ insight, published, linkCount })` y devuelve `published && insightWordCount(insight) >= MIN_NEWS_INSIGHT_WORDS && linkCount >= 1` (la última condición solo si Xavi la aprueba). Se mantienen exportados `MIN_NEWS_INDEX` e `isNewsIndexIndexable`.
- BD: la columna generada `indexable` / `indexable_en` pasa a contar palabras de `insight_es` / `insight_en` con N = 80. El servidor y la app usan el mismo umbral (una sola constante y un comentario que cite la otra).
- Sitemap (`server/api/__sitemap__/urls.ts`): entran fichas publicadas con `indexable` (por idioma); `lastmod` = máx. de `updated_at` del aporte y del resumen, nunca cambios de ingesta. Los alternates `en` solo si `indexable_en`.
- Índice `/noticias` (≥ 6) y categorías (≥ 3 y texto propio): sin cambios. Nota: con D91 el `ItemList` solo lista fichas indexables, como antes; el índice sigue siendo la página fuerte, y puede indexarse con fichas `noindex` porque el aporte recortado en la cuadrícula suma contenido propio a la página, pero la cuadrícula no debe duplicar el aporte entero.
- Las fichas existentes con «nota de Xavi» migran: `author_note_*` pasa a ser `insight_*` (ver 19.7).

### 19.5 Title, meta description y schema

**Title.** Titular propio (≤ 60 caracteres con sufijo si cabe) que empieza o contiene la keyword principal y no copia el de la fuente. Si la rutina genera `seo_title`, es ese; si está vacío, el titular. Ej. es: `Ainhize Belar encadena un 9b: contexto para escaladores de Barcelona` (ajustado a ≤ 60; los textos finales los afina loro-lola).

**Meta description** (≤ 158, `clampDescription`). Prioridad:
1. `meta_description_es/en` si Xavi la ha escrito.
2. Si no, las primeras 1 o 2 frases del aporte hasta ~150 caracteres, cortadas en frase completa (nunca a mitad de palabra).
3. Si el aporte está vacío (ficha `noindex`), el inicio del resumen propio.
La primera frase del aporte debe valer como description porque la rutina la redacta con esa doble función (19.2). Única por ficha; no repetir la del resumen del índice.

**Schema `Article`** (solo fichas indexables; sin `Article` en `noindex`, igual que 6):
- `headline` = titular propio; `description` = la meta description; `articleBody` no se emite.
- `author`: **`Organization` ChalkGuide** (`@id` del layout). Motivo: el aporte lo redacta la rutina y lo edita Xavi; ponerlo como `Person` Xavi sería atribuirle un texto que no escribe entero, y Google exige que la autoría sea veraz. `editor`: `Person` Xavi (revisa y aprueba; consistente con D74). Los artículos del blog siguen con `author` Xavi. Si Xavi decide reescribirlo entero, el panel podría marcar `author_reviewed` y pasar a `Person`; no lo pido ahora (ver 19.7).
- `isBasedOn`: `NewsArticle` o `CreativeWork` de la fuente, con `url` (`source_url`), `name` (`source_title`), `publisher` (`source_name`) y `datePublished` (`source_published_on`). `citation`: la misma URL. Ya definido en 6; se mantiene.
- `about`: la entidad principal (la de la keyword): `Person` (atleta), `Event` (festival, competición), `Place` o `SportsActivityLocation` (rocódromo, zona). Solo `name`, y `url` si existe una ficha de ChalkGuide de esa entidad. Sin `sameAs` inventados: solo si el dato figura en la fuente o en la ficha.
- `mentions`: las fichas de `news_links` (rocódromos, artículos, eventos de ChalkGuide) como `Thing` con `name` y `url` de ChalkGuide. Máximo 3.
- `datePublished` (aprobación de Xavi), `dateModified` (cambio real del aporte), `inLanguage`, `articleSection`, `mainEntityOfPage`, `image` (solo con licencia), `publisher` (el del layout). Se mantienen `BreadcrumbList` y los demás puntos de 6.
- Prohibido: `NewsArticle` propio, `Review`, `AggregateRating`, `speakable`.

### 19.6 Enlazado interno

- El aporte enlaza **solo** a fichas de ChalkGuide publicadas, hasta **3** (`news_links`, `position` 1–3): rocódromo, artículo, evento, resolador o pies de gato. Anclaje natural (nombre del rocódromo, título del artículo), sin keywords repetidas y sin autolinking por palabra.
- Los enlaces del aporte y el bloque «Relacionado» son los **mismos** `news_links`; no se duplican con un segundo conjunto. El aporte los cita en el texto y «Relacionado» los lista.
- **Nunca enlaces externos en el aporte.** La única salida es el botón «Leer en {fuente}» (sección 7), con sus atributos. Un enlace externo en el cuerpo diluiría la señal y compite con el botón.
- Los enlaces salen en HTML servido (`<a href>`), no por JS.
- La rutina sugiere los candidatos a partir de las fichas existentes por zona, rocódromo y etiquetas; Xavi aprueba. El servidor valida que existan y estén publicados.

### 19.7 Campos que pido al backend (jabali-javi)

Sobre `guide.news` (ver J27 y la ampliación de F8.6):

| Campo | Tipo y reglas | Notas |
| --- | --- | --- |
| `insight_es` / `insight_en` | `text` null; ≤ 1.400 caracteres; `_en` exige `_es` o es independiente según `has_en`; sin HTML (texto plano con saltos de línea; las viñetas como líneas con guion que el front convierte) | Sustituyen a `author_note_es/en`. **Recomiendo renombrar** (`rename column`) para conservar datos y las columnas generadas; el nuevo mínimo es 80, no 60. Exponer a `anon` (hoy se expone `author_note_*`) |
| `indexable` / `indexable_en` | generadas, redefinir | ≥ 80 palabras de `insight_es` / `insight_en` y publicada; sin `exists(news_links)` (D92 la descarta).4 (una columna generada no puede leer otra tabla: en ese caso calcularlo en vista o RPC, o dejar el chequeo de enlaces solo en la app) |
| `seo_keyword_es` / `seo_keyword_en` | `text` null; 2–60 caracteres | **Opcional pero recomendado**: la rutina la propone y el panel la muestra para que Xavi la edite. Sin uso público: no exponer a `anon`. Sirve de control de calidad (¿aparece en título y primer párrafo?) |
| `meta_description_es` / `meta_description_en` | `text` null; ≤ 160 | **Opcional.** Si la vacía, la app usa la primera frase del aporte. Lo podría pedir la rutina, pero la regla del 19.5 evita escribir otra pieza. Recomiendo dejarlo para Xavi (override) |
| `seo_title_es` / `seo_title_en` | `text` null; ≤ 70 | Ya existe el patrón `[seo]` del modelo para otros contenidos. **Opcional**: sin él, el titular propio sirve |
| `insight_status` (`ok` / `empty`) | no hace falta | Se deduce de si `insight_*` está vacío o sin palabras suficientes |

Campos que **sobran** o se retiran: `author_note_es/en` (los sustituye `insight_*`), la insignia «con nota de Xavi» y `has_note` en `search_news` (D90 ya los quita del frente: sustituir por `has_insight` solo si el panel lo necesita, no el sitio público). No pido tabla ni campo nuevo para el recorte de la cuadrícula: se calcula en la app.

`news_links` ya existe (máx. 3): sin cambios. `search_news` / `admin_search`: indexar `insight_es/en` en el FTS (peso C, como la nota) y devolver el arranque; `author_note` deja de buscarse. La rutina (docs/copy/f8/prompt-rutina.md, loro-lola) añade `insight_es`, `insight_en`, `seo_keyword_*` y `link_candidates` (ids de fichas) a su contrato de salida; leona-lia revisa la ampliación (el aporte pasa por saneado como el resto de textos del agente, F1).

### 19.8 Riesgos y medición

Riesgos:
1. **Contenido escalado sin valor.** Mayor riesgo: la política de spam trata la reescritura masiva con IA como infracción. Mitigaciones: criterios 19.1, revisión humana obligatoria, indexación por umbral y por enlace interno, volumen bajo (decenas al mes), y `noindex` para lo débil. Si Search Console muestra una caída o una acción manual por «contenido de baja calidad», pasar todas las fichas a `noindex` (basta subir N a un valor inalcanzable) mientras Xavi revisa.
2. **Plantilla repetida.** Aportes con la misma estructura ⇒ huella de contenido a escala. Control: Xavi y la rutina varían el arranque; revisión mensual de 10 aportes al azar.
3. **Duplicado con la fuente.** Control: regla de 8 palabras y `similarity` ≥ 0,35.
4. **Datos erróneos.** Riesgo reputacional y de confianza si la rutina «completa de memoria». Control: solo datos de fuente o de fichas; Xavi verifica al aprobar; la rutina señala en `agent_meta` de dónde sale cada dato.
5. **Canibalización con la fuente o el blog.** Las fichas compiten con la propia fuente por el nombre del atleta. Hay poco que ganar en queries de gran demanda (el atleta): se espera tráfico de cola larga local (`… Barcelona`, `… Cataluña`, `rocódromo … ` + noticia). No competir por el nombre pelado.
6. **Cuadrícula duplicando el aporte.** El arranque recortado en la cuadrícula es contenido propio de la ficha; no es duplicado dañino (mismo sitio), pero no mostrar el aporte completo fuera de la ficha ni en la newsletter sin recortar.
7. **Fichas sin tráfico indexadas.** Un exceso de URLs finas diluye el dominio nuevo. Control: la regla de 19.4 y el seguimiento de «Rastreada, actualmente sin indexar».
8. **Atribución de autoría.** `author` Organization más `editor` Xavi, veraz. Si la ficha dice «de Xavi» y no lo es, riesgo de confianza (y de transparencia ante el lector). El texto de `/transparencia` explica que el aporte lo redacta una IA y lo revisa Xavi (loro-lola).

Medición (Search Console y analítica propia, sin cookies ni scripts nuevos):
- Search Console, propiedad de dominio: filtro de página `/noticias/` y `/en/news/`. Seguir impresiones, clics, CTR y posición media por semana; consultas con modificador local; páginas con impresiones pero sin clics (title o description flojos). Informes de indexación: «Indexada», «Rastreada, actualmente sin indexar» y «Excluida por noindex» (esperada para las fichas bajo N).
- Comparar a 4 y 8 semanas: fichas con aporte ≥ 80 y enlace interno frente a las que no, para validar N y la regla del enlace.
- Eventos propios (sección 14): `news_source_click` por noticia (calidad de la selección y objetivo del agregador); `news_note_view` pasa a `news_insight_view` (el aporte entra en pantalla); `ficha_click` desde noticias (¿el aporte empuja a rocódromos y artículos?); `newsletter_submit` con origen `noticias`.
- KPI de negocio: altas de newsletter por 1.000 visitas de /noticias y de fichas indexadas.
- Calidad editorial: porcentaje de aportes editados por Xavi al aprobar (proxy de lo bien que redacta la rutina), porcentaje de noticias sin aporte, y media de palabras. Objetivo: ≥ 80 % de aportes indexables sin retoque de fondo tras 8 semanas.
- Umbrales de alarma: caída del 30 % de impresiones de /noticias/* en 2 semanas, o subida de «Rastreada, actualmente sin indexar» a más del 40 % de las fichas indexables ⇒ revisar plantilla de aporte y subir N.

### 19.9 Decisiones para Xavi

1. N = 80 palabras para indexar (alternativa: 100 si prefieres filtrar más).
2. ~~Exigir al menos un enlace interno para indexar~~: descartado (D92).
3. `author` Organization ChalkGuide con `editor` Xavi (recomendado) o `Person` Xavi.
4. `seo_keyword` y `meta_description` opcionales: recomendados `seo_keyword`, y `meta_description` como override.
