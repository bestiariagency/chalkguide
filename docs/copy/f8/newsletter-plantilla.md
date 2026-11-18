# Plantilla de la newsletter semanal · ChalkGuide F8 v2

Tarea 8.3 · Versión 0.1 (2026-11-13). Estructura y microcopy en español de España e inglés
británico (D75). Todo es redacción propia; no se reproduce texto de fuentes.

Notas para coordinación:

- D75: dos campañas según idioma. Según el plan, la versión en inglés es opcional; si una semana
  no hay `intro_en`/`subject_en`, los suscriptores en inglés reciben la versión en español o no
  reciben envío (decisión de Xavi y jabali-javi en 8.13).
- Marcadores `{{...}}` son variables. Los nombres los fijan jabali-javi y coneja-lucky (8.13/8.14);
  los de aquí son orientativos. Si Brevo usa otra sintaxis, se adaptan.
- Longitudes pensadas para clientes de correo: asunto ≤ 60, preheader ≤ 110, titulares de ítem ≤ 90,
  resumen de ítem ≤ 220 en el email (el resumen completo, ≤ 600, vive en la web).
- RGPD (regla 8): enlace de baja visible en cada envío, motivo del correo y origen del consentimiento.
- El correo vive fuera de `i18n/locales`: lo gestiona Brevo. Esto se pega allí o en la plantilla
  que construya coneja-lucky. Si pasa a `es.json`/`en.json`, se avisa para dividir en claves.

## 1. Asunto y preheader

Patrón del asunto: lo más útil de la semana, sin gancho vacío ni mayúsculas. El agente propone el
asunto en la intro de los jueves; Xavi lo edita.

| Idioma | Asunto tipo | Preheader tipo |
| --- | --- | --- |
| es | `{{n_eventos}} planes y {{n_noticias}} noticias de escalada para esta semana` | `Agenda de Barcelona, novedades y lo último del blog, con la fuente de cada cosa.` |
| es (si hay un ítem fuerte) | `{{titular_principal_corto}}: la semana en ChalkGuide` | `Y además, lo que hay en la agenda de los próximos 14 días.` |
| en | `{{n_eventos}} things on and {{n_noticias}} climbing news items this week` | `Barcelona listings, news and the latest from the blog, with a source for each item.` |
| en (strong item) | `{{titular_principal_corto}}: this week at ChalkGuide` | `Plus what is on the calendar over the next 14 days.` |

Reglas: sin «¡!», sin «imperdible» ni superlativos, sin «urgente». Si no hay eventos o noticias,
el asunto no promete cantidades (usar `La semana en ChalkGuide` / `This week at ChalkGuide`).

## 2. Cabecera

- Wordmark ChalkGuide (logo oficial, sin tocar el isotipo).
- Línea de edición: `Semana del {{fecha_inicio}} al {{fecha_fin}}` / `Week of {{start_date}} to {{end_date}}`.

## 3. Intro (voz de Xavi)

La redacta la rutina los jueves como borrador (350–600 caracteres); Xavi la revisa y la firma.
Primera persona, cercana y útil. Estructura: saludo breve, qué pasa esta semana, qué señalo yo.

Ejemplo de tono (marcado como ejemplo; no usar tal cual):

- es: `Hola, soy Xavi. Esta semana hay poca competición, pero sí un par de cosas útiles si escalas por
  Barcelona: te dejo abajo lo más cercano en la agenda y una noticia sobre accesos que conviene
  mirar antes de salir a roca. Cada ítem lleva su fuente, por si quieres leerlo entero.`
- en: `Hi, Xavi here. It is a quiet week for competitions, but there are a couple of useful things
  if you climb around Barcelona: the nearest dates are below, plus a note on access worth reading
  before you head out to the crag. Each item links to its source if you want the full story.`

`[XAVI: cierra la intro con una frase tuya cuando quieras: una opinión, una anécdota o una
recomendación personal. Eso no lo puede escribir el agente.]`

## 4. Sección Agenda

Eventos aprobados de los próximos 14 días, ordenados por fecha.

| Elemento | es | en |
| --- | --- | --- |
| Título de sección | `Agenda de los próximos 14 días` | `Coming up in the next 14 days` |
| Texto de ítem | `{{fecha_larga}} · {{lugar}}` + `{{titular}}` + `{{resumen_corto}}` | `{{long_date}} · {{place}}` + `{{headline}}` + `{{short_summary}}` |
| Precio | `Precio: {{price_text}}` | `Price: {{price_text}}` |
| Enlace | `Ver en ChalkGuide` | `See on ChalkGuide` |
| Cita de fuente | `Fuente: {{source_name}}` (enlace a `source_url`) | `Source: {{source_name}}` |
| Vacío | `Esta semana no hay planes nuevos en la agenda. Mira la agenda completa por si ha entrado algo después.` | `Nothing new on the calendar this week. Check the full calendar in case something has been added.` |
| Pie de sección | `Ver toda la agenda` | `See the full calendar` |

Formato de fecha: `sáb 5 dic, 10:00` / `Sat 5 Dec, 10:00` (hora local de Madrid).

## 5. Sección Noticias

Noticias aprobadas de los últimos 7 días, agrupadas por la categoría del ítem o por orden de
relevancia (decisión de buho-pixel).

| Elemento | es | en |
| --- | --- | --- |
| Título de sección | `Noticias de la semana` | `This week in climbing news` |
| Ítem | `{{categoria}}` + `{{titular}}` + `{{resumen_corto}}` | `{{category}}` + `{{headline}}` + `{{short_summary}}` |
| Enlace principal | `Leer el resumen` (a la ficha propia) | `Read the summary` |
| Cita de fuente | `Fuente: {{source_name}}` (enlace a la noticia original) | `Source: {{source_name}}` |
| Aclaración | `Resumen propio de ChalkGuide; el texto completo está en la fuente.` | `ChalkGuide's own summary; the full text is at the source.` |
| Vacío | `Una semana tranquila: no ha habido noticias que valga la pena contar.` | `A quiet week: no news worth passing on.` |

Cada ítem muestra siempre la cita de fuente. Una imagen solo si la ficha tiene licencia clara, con
su crédito (`Imagen: {{credito}}, {{licencia}}` / `Image: {{credit}}, {{licence}}`).

Si la noticia lleva «Nota de Xavi» (D73), se muestra tras el resumen:

- es: `Nota de Xavi: {{nota}}` (corta, ≤ 200 caracteres). `[XAVI: la escribes tú.]`
- en: `Xavi's note: {{note}}`.

## 6. Sección Del blog

El último artículo publicado.

| Elemento | es | en |
| --- | --- | --- |
| Título de sección | `Del blog` | `From the blog` |
| Ítem | `{{titulo}}` + `{{entradilla}}` (≤ 160 car.) | `{{title}}` + `{{standfirst}}` |
| Enlace | `Leer el artículo` | `Read the article` |
| Vacío | (la sección se omite) | (section omitted) |

No hay cita de fuente: es contenido propio de ChalkGuide.

## 7. Pie

Texto fijo, redacción propia. Debe aparecer en **todos** los envíos.

**es**

> Recibes este correo porque te suscribiste a la newsletter de ChalkGuide en {{origen_alta}} el
> {{fecha_alta}}. Es un correo semanal de un proyecto editorial independiente, escrito por Xavi.
>
> Las noticias y la agenda se recopilan con ayuda de una herramienta automática y las revisa Xavi
> antes de publicarlas. Cada ítem indica su fuente y los resúmenes son propios. Si ves un error,
> responde a este correo y lo corrijo.
>
> ChalkGuide es independiente: ningún anunciante ni rocódromo compra una reseña ni un hueco aquí.
> Si algo lleva enlace de afiliado o viene de una visita invitada, se indica.
>
> [Darme de baja] · [Política de privacidad] · [Ver en el navegador]

**en**

> You are receiving this email because you subscribed to the ChalkGuide newsletter at
> {{signup_origin}} on {{signup_date}}. It is a weekly email from an independent editorial project,
> written by Xavi.
>
> News and listings are gathered with the help of an automated tool and reviewed by Xavi before
> they go out. Each item names its source and the summaries are our own. If you spot a mistake,
> reply to this email and I will correct it.
>
> ChalkGuide is independent: no advertiser or climbing gym buys a review or a slot here. Anything
> with an affiliate link or from a guest visit is labelled.
>
> [Unsubscribe] · [Privacy policy] · [View in browser]

Notas del pie:

- La referencia a la «herramienta automática» cumple con la transparencia y la regla 7. Si Xavi
  prefiere otra formulación, se ajusta, pero no se omite.
- Si un envío incluye un ítem de afiliado o de visita invitada (hoy no hay), se añade una línea
  junto al ítem: `Enlace de afiliado.` / `Affiliate link.` y `Visita invitada.` / `Guest visit.`
- La dirección postal o datos del responsable los fija el apartado legal (llega con F7). `[XAVI:
  datos del responsable y dirección postal para el pie legal, antes del lanzamiento.]`
- El enlace de baja es de un clic, sin login.

## 8. Variantes de estado (panel Newsletter, 8.14)

Microcopy orientativo para el panel (solo en español, panel interno):

- `Borrador semanal listo para revisar`
- `Aprobar y programar (sale en 1 h)`
- `Cancelar envío`
- `Programado para {{hora}}. Puedes editarlo o cancelarlo hasta entonces.`
- `Enviado el {{fecha}} a {{n}} suscriptores`

No va en `i18n/locales` si el panel está fuera de i18n (solo español); lo decide coneja-lucky.
