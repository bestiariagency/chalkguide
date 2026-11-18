# Spec SEO de /noticias (F8 · tarea 8.4)

Autor: lince-max. Fecha: 2026-11-13. Solo especificación: no hay código. La implementa lince-max en 8.11 sobre lo que entregue coneja-lucky en 8.10.

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
