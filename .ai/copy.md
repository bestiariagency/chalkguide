# Copy y voz editorial · ChalkGuide

## Voz

- Autor: **Xavi**, 6 años escalando en Barcelona, 7b a los 41, que recuerda haber empezado sin a
  quién preguntar. Primera persona en reseñas y artículos.
- Útil antes que brillante: datos concretos, consejos aplicables, errores propios contados sin pose.
- Cercana y honesta; nunca "el mejor sitio de…". Sin superlativos vacíos ni promesas no verificables.
- Para dos públicos: quien empieza (explica sin condescendencia, define la jerga la primera vez) y
  quien escala hace años (no le hagas perder el tiempo).
- Lo pagado se marca; una visita invitada se dice en la reseña.

## Marca

- En todo texto: **ChalkGuide** (una palabra, C y G mayúsculas), en es y en. Nunca "Chalk Guide"
  ni "chalkguide" (esa forma en minúsculas es solo el wordmark del logo). La app hermana: "Chalk app".

## Idiomas

- **Español de España** (Barcelona) por defecto: tuteo, ortografía y tildes impecables. Términos de
  escalada como se usan aquí: rocódromo, pies de gato, resolar, bloque/boulder, vía, autobelay, bono.
- **Costes**, no "costos": la categoría del pilar se escribe "Costes" (slug `costes`). Nunca "costos" en la interfaz.
- Comparador de pies de gato: máximo **3 modelos** (mínimo 2).
- **Inglés británico** (`en-GB`) para expats: traducción natural, no literal.
- Toda clave nueva se escribe en `i18n/locales/es.json` y `en.json` a la vez, respetando la estructura.

## Dónde vive el texto

- Microcopy de UI: `i18n/locales/*.json`. Edita solo ahí; no toques componentes ni estilos.
- Contenido editorial (artículos, reseñas, páginas, fichas): vive en Supabase y Xavi lo edita desde
  `/administrador`. Antes de que exista el panel, los borradores van en `docs/content/` o como seed
  (coordinado con jabali-javi). Datos dummy: realistas y marcados como ejemplo.
- Respeta longitudes del diseño; si un texto no cabe, avisa.

## Pilares y primeros artículos

Pilares: empezar a escalar, dónde escalar, material, progresión y cuidado, costes, comunidad.
Lista de los 10 primeros en `docs/Chalk_Guide_Plan_de_proyecto.md`. La IA redacta y ordena; el
criterio y la experiencia son de Xavi: deja marcados `[XAVI: …]` los huecos que solo él puede llenar.

## Newsletter y agente de novedades

- Newsletter semanal (D75): borrador cada jueves con la agenda de las próximas 2 semanas, noticias aprobadas de la semana (con fuente) y el último artículo; sale 1 h después de que Xavi la apruebe.
- Prompt del agente de novedades: extraer actividades (título, fecha, rocódromo, enlace) sin inventar;
  si un dato no está, se deja vacío. Siempre borrador para aprobación.
- Cada artículo se recicla en 2–3 piezas de Instagram si Xavi lo pide.
