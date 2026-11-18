# Investigación SEO del blog de ChalkGuide · noviembre 2026

Autor: Lince-Max (SEO y marketing). Pedido de Xavi, 2026-11-12. Estado: propuesta para decisión; no toca código ni `docs/PLAN.md`.

## Cómo leer este documento

No hay acceso a herramientas de pago (Ahrefs, Semrush, Keyword Planner) ni a Google Trends. Por eso:

- **Dato con fuente**: lleva enlace o referencia. Son pocos y casi todos cualitativos (quién aparece en el SERP, precios publicados, calendarios de acceso).
- **Estimación (E)**: volumen, dificultad y estacionalidad. Los volúmenes son rangos relativos (alto, medio, bajo) basados en tamaño del mercado y en la presencia de agregadores y medios en los resultados, no en cifras medidas. Equivalencia orientativa para España/Cataluña en búsquedas al mes: alto > 1.000, medio 200 a 1.000, bajo < 200.
- Antes de comprometer un artículo grande, validar su keyword en Search Console (cuando haya datos) y, si Xavi lo aprueba, con una prueba puntual de una herramienta gratuita (Google Keyword Planner con cuenta de Ads sin gasto, o Ubersuggest en versión limitada). Ninguna es de pago obligatorio; si se quisiera una suscripción, requiere aprobación de Xavi.

## 1. Resumen ejecutivo

### Hallazgos clave

1. **El SERP local lo dominan agregadores de reservas y blogs de turismo, no medios de escalada.** Para "rocódromos Barcelona", "escalada cerca de Barcelona" o "curso de escalada" aparecen Yumping, Picuco, Explore-Share, Manawa, GuruWalk, Urban Sports Club, ClassPass, Time Out y el blog Barcelona Urbana. Son páginas comerciales de reserva o contenido genérico de turismo, con precios desactualizados y sin criterio. Un medio con voz de autor y datos verificados gana ahí. Fuentes: búsquedas web del 2026-11-12 (ver apéndice A).
2. **"Pies de gato" es ambiguo en español.** Una búsqueda de "mejores pies de gato principiante" devolvió resultados de patines, comida y accesorios para gatos mezclados con los de escalada. Hay que escribir siempre "pies de gato de escalada" o "zapatillas de escalada" en title y H1, y trabajar las dos formas como keywords. Las guías de escalada que rankean son Hola.com (2024), Decathlon y tiendas como Bergfreunde (listados), es decir, poca competencia editorial real. Fuente: apéndice A.
3. **La estacionalidad favorece publicar roca entre octubre y marzo y rocódromo en septiembre-enero.** Las zonas de Tarragona (Siurana, Margalef) tienen temporada de otoño a primavera y el verano se evita por calor (fuente: Explore-Share, thecrag, Diari de Tarragona). El indoor sube con la vuelta a la rutina (septiembre) y los propósitos (enero) (E).
4. **Los 12 artículos de Ana cubren bien "actualidad y datos" (Margalef, Montserrat cerrado, accidentes, precios, lesiones) pero dejan sin cubrir los términos de mayor volumen y más fáciles de convertir**: "dónde escalar en Barcelona", "mejores rocódromos de Barcelona", "cómo elegir pies de gato", "bono vs cuota", "rocódromo con niños", "ir solo y encontrar compañero". Esos son los de la lista original de 10 del plan de proyecto y casi ninguno está escrito.
5. **El catalán es una oportunidad real y poco disputada.** Barcelona Urbana ya publica en catalán sus guías de precios de rocódromos (`/ca/blog/rocodroms-barcelona-preus`), y los cursos federados (FEEC, UEC, CEP, UAB) son todo en catalán. Quien busca "rocòdrom Barcelona" o "curs d'escalada" casi no encuentra medios editoriales. Es recomendación, no decisión (sección 7).
6. **El embudo corto es "guía local → ficha interna → newsletter".** Los artículos de precios, comparativas y "antes de ir" tienen intención transaccional o de planificación y encajan con una promesa de newsletter concreta (aviso de cambios de tarifa, de cierres, de nuevas fichas). Eso respeta D48: sin pop-ups, solo bloque naranja y enlace de una línea.
7. **Dominio nuevo y sin autoridad: los primeros 3 a 6 meses se ganan con long tail local y contenido con datos propios**, no compitiendo por "escalada" o "rocódromo" a secas. Los enlaces vendrán de las fichas, de Instagram y de citas de comunidad (clubes, rocódromos que comparten su ficha).

### Recomendaciones priorizadas (impacto sobre esfuerzo)

| # | Recomendación | Impacto | Esfuerzo | Cuándo |
| --- | --- | --- | --- | --- |
| 1 | Publicar primero los 5 pilares de intención alta que faltan: "mejores rocódromos de Barcelona", "dónde escalar cerca de Barcelona", "cómo elegir pies de gato de escalada", "bono o cuota", "rocódromos con niños" | Alto | Medio | Dic 2026 a feb 2027 |
| 2 | Plantilla on-page única con FAQ + JSON-LD (`Article`, `FAQPage` solo donde haya preguntas reales) y enlazado pilar-cluster-ficha | Alto | Bajo | Antes del primer artículo |
| 3 | Mantener cada artículo "vivo": fecha de verificación visible y revisión anual o semestral (precios, cierres, accesos) | Alto | Bajo | Continuo |
| 4 | Segmentar la newsletter por origen de artículo (etiqueta automática por categoría) sin pedir más datos en el alta | Alto | Bajo | F4.5 |
| 5 | Elegir analítica en F4.5 con eventos propios (alta, confirmación, clic de afiliado) y activar Search Console el día del lanzamiento | Alto | Bajo | F4.5 |
| 6 | Piloto en catalán con 3 a 5 artículos locales tras 3 meses de datos en es | Medio-alto | Medio | Q2 2027, decisión de Xavi |
| 7 | Inglés solo para dos artículos de viajero (Margalef, Montserrat) cuando existan; el resto, no | Medio | Bajo | Q1-Q2 2027 |

## 2. Mapa de demanda por pilar

Columnas: keyword principal; secundarias; intención (I = informacional, C = comparación/consideración, T = transaccional/local, N = navegacional); volumen (E); dificultad (E, para un dominio nuevo); estacionalidad (E salvo nota); quién rankea; ángulo ganador. Todos los volúmenes y dificultades son estimaciones.

### Pilar 1 · Empezar a escalar

| Keyword principal | Secundarias | Int. | Vol. | Dif. | Estacionalidad | Quién rankea | Ángulo ganador |
| --- | --- | --- | --- | --- | --- | --- | --- |
| cómo empezar a escalar | primera vez rocódromo, qué necesito para escalar, escalada para principiantes | I | Alto | Alta | Pico sep-oct y ene | Decathlon, Desnivel, blogs deportivos, Hola.com-tipo | Versión local: qué pasa el primer día en Barcelona, qué se alquila, qué entrada paga (fichas) |
| curso de escalada Barcelona | curso iniciación escalada, bautizo de escalada, curs d'escalada | T | Medio-alto | Media | Pico sep-oct, primavera | Picuco, Explore-Share, Manawa, GuruWalk, FEEC (PDF de cordadas), UEC | Comparativa de cursos con precio, duración, titulación y para quién, con fecha de consulta. Fuente: apéndice A |
| rocódromo para principiantes Barcelona | rocódromo para ir solo, primera vez | I/C | Medio | Media | Sep-ene | Barcelona Urbana, Time Out | "Cómo ir solo y encontrar compañero" (ficha de rocódromo y Chalk app) |
| aprender a asegurar | test de aseguramiento, asegurar con grigri | I | Medio | Media | Todo el año, pico sep-nov | Fabricantes, Desnivel, vídeos YouTube | Ya cubierto en ángulo accidentes (Ana n.º 8); falta pieza "test de aseguramiento: cómo se hace en cada rocódromo de Barcelona" |
| escalada para niños | rocódromo niños, cumpleaños escalada | T | Medio | Media | Sep-oct, primavera (cumpleaños) | Picuco, Yumping, Salir.com, Barcelona Urbana | Rocódromos con zona infantil (índice familia). Fuente: apéndice A |

### Pilar 2 · Dónde escalar

| Keyword principal | Secundarias | Int. | Vol. | Dif. | Estacionalidad | Quién rankea | Ángulo ganador |
| --- | --- | --- | --- | --- | --- | --- | --- |
| rocódromos Barcelona | mejores rocódromos Barcelona, rocódromo cerca de mí, rocòdroms Barcelona | T/C | Alto | Alta | Sep-ene (E) | Yumping, Time Out, Urban Sports Club, ClassPass, Barcelona Urbana | Guía con criterio y datos propios (nota por criterios de la reseña de autor). Fuente: apéndice A |
| escalada cerca de Barcelona | escalar cerca de Barcelona, escalada en roca Barcelona | I/T | Alto | Media-alta | Oct-mar | Explore-Share, GuruWalk, Barcelona Urbana, Eurovista, thecrag | Zonas a menos de 2 h con transporte público, grado de entrada y avisos de cierre |
| Montserrat escalada | escalar en Montserrat, sectores principiantes, Penya Ginesta | I | Medio-alto | Media | Otoño y primavera | Explore-Share, Barcelona Urbana, thecrag | Cómo ir en tren, qué sectores para empezar, estado de cierres (Ana n.º 6 cubre cierres) |
| Margalef escalada | Margalef parking reserva, Margalef sectores | I | Alto en temporada | Media | Pico nov-mar, desplome en verano | thecrag, 27crags, La Crux, prensa local, Explore-Share | Ya cubierto (Ana n.º 5). Falta guía práctica de zonas por nivel |
| Siurana escalada | Siurana sectores, Siurana grados | I | Medio-alto | Media-alta | Primavera y otoño | thecrag, Explore-Share, 27crags | Guía de visita y alojamiento sin copiar a la guía de zonas; enlaces a fichas |
| Rodellar / Montsant / Terradets / Oliana | escalada Rodellar, Montsant sectores | I | Medio | Media | Primavera, otoño | thecrag, 27crags | Panorama "qué zona elegir según nivel y época" (cluster del pilar) |
| escalar cuando llueve en Barcelona | rocódromo cuando llueve | I | Bajo-medio con picos | Baja | Picos con lluvia, otoño | Prácticamente nadie | Alta probabilidad de ganar: artículo 1 de la lista original del plan. Pico de oportunidad en el primer día de lluvias de otoño |

### Pilar 3 · Material

| Keyword principal | Secundarias | Int. | Vol. | Dif. | Estacionalidad | Quién rankea | Ángulo ganador |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pies de gato de escalada | zapatillas de escalada, mejores pies de gato, pies de gato principiante | C/T | Alto | Alta | Pico nov-dic (regalos) y sep | Hola.com (2024), Decathlon, Bergfreunde, tiendas. Fuente: apéndice A | Comparador con fuente única Barrabes y criterio (perfil, rigidez, uso). Marcar afiliado |
| cómo elegir pies de gato | talla pies de gato, pies de gato asimétricos | I/C | Medio-alto | Media | Igual | Decathlon (guía), BBVA (generalista) | Guía por nivel y estilo (lista original n.º 6) enlazada al comparador |
| resolar pies de gato | cuándo resolar, resoladores Barcelona, precio resolado | T | Medio | Baja | Todo el año, algo más en primavera | Talleres locales, pocas guías | Ficha de resoladores + "cuándo resolar" (n.º 7 y 3 de lista) |
| cuándo cambiar la cuerda | caducidad arnés, vida útil material de escalada | I | Medio | Media | Todo el año | Fabricantes (Petzl FAQ), foros | Ya cubierto (Ana n.º 9) |
| casco de escalada | casco en escalada deportiva | I | Bajo-medio | Media | Primavera-otoño | BMC, retail | Ya cubierto (Ana n.º 10) |
| mochila / magnesio / cuerda para empezar | qué comprar para empezar a escalar | C | Medio | Alta | Navidad, sep | Decathlon, retail | Lista de "lo mínimo para el primer año" con coste total; sin ficha, así que enlazar al pilar de costes |

### Pilar 4 · Progresión y cuidado

| Keyword principal | Secundarias | Int. | Vol. | Dif. | Estacionalidad | Quién rankea | Ángulo ganador |
| --- | --- | --- | --- | --- | --- | --- | --- |
| lesión de polea | dolor de dedos escalada, polea A2 | I | Medio-alto | Alta (YMYL) | Todo el año | Fisioterapeutas, Desnivel, retail | Ya cubierto (Ana n.º 11); mantener tono prudente, remitir a profesional |
| calentamiento escalada | calentar antes de escalar, rutina | I | Medio | Media | Todo el año | Blogs de entrenamiento | Ya cubierto (Ana n.º 12) |
| entrenar escalada en casa | hangboard, campus board, dominadas | I | Medio-alto | Media | Ene (propósitos), invierno | Blogs de entrenamiento, YouTube | Programa mínimo de 4 semanas con regletas; riesgo de lesión, tono prudente |
| cómo mejorar en escalada | pasar de 6a a 6b, estancamiento | I | Medio-alto | Media | Todo el año | Blogs, vídeos | Hueco: progresión para el que sale de boulder a deportiva, con ejemplos de Barcelona |
| escalada y descanso entre sesiones | frecuencia semanal | I | Bajo-medio | Baja | Todo el año | Pocos | Cluster corto, enlazado a polea |

### Pilar 5 · Costes

| Keyword principal | Secundarias | Int. | Vol. | Dif. | Estacionalidad | Quién rankea | Ángulo ganador |
| --- | --- | --- | --- | --- | --- | --- | --- |
| precio rocódromo Barcelona | cuánto cuesta escalar, entrada rocódromo, tarifas | T | Alto | Media | Sep y ene | Barcelona Urbana (ca/es), Time Out, webs de cada rocódromo | Ya cubierto (Ana n.º 3); añadir el índice precio de las fichas y fecha de consulta. Fuente: apéndice A |
| abono / cuota rocódromo | bono 10 entradas, matrícula, permanencia | T/C | Medio | Baja | Sep y ene | Webs de cada centro | Ya cubierto en parte (Ana n.º 4); falta "bono o cuota según cuántas veces vas" (lista n.º 8) |
| escalar barato | Urban Sports Club, ClassPass, entradas descuento | C | Medio | Media | Sep | Urban Sports Club, ClassPass (propios) | Comparativa honesta de planes agregadores vs. cuota directa, sin afiliación encubierta |
| cuánto cuesta una salida a roca | coste del equipo y transporte, licencia federativa | I | Bajo-medio | Baja | Oct-mar | Casi nadie | Cálculo del coste real de la primera temporada; licencia FEEC requiere ser socio de entidad afiliada (fuente: FEEC, apéndice A) |

### Pilar 6 · Comunidad

| Keyword principal | Secundarias | Int. | Vol. | Dif. | Estacionalidad | Quién rankea | Ángulo ganador |
| --- | --- | --- | --- | --- | --- | --- | --- |
| compañero de escalada | encontrar compañero escalada Barcelona, grupo de escalada | T | Medio | Baja | Sep-oct | Grupos de Facebook/Meetup, Chalk app | Ángulo natural para F9: "dónde ir solo" + espera de Chalk app |
| etiqueta rocódromo | normas, reglas no escritas | I | Bajo-medio | Baja | Sep | Gripped, pocos en español | Ya cubierto (Ana n.º 2) |
| competición escalada | World Climbing Series, LA28, Alberto Ginés | I | Medio-alto picos | Alta en picos | Picos con eventos (E) | Prensa deportiva, World Climbing | Ya cubierto (Ana n.º 1). Es actualidad y pasa rápido: no depender de este tráfico |
| eventos de escalada Barcelona | agenda, competiciones locales, charlas | N/I | Bajo-medio | Baja | Todo el año | Webs de clubes, FEEC | Agenda de ChalkGuide como ancla; artículo mensual "qué hay este mes" |
| clubs de escalada Barcelona | clubes, asociaciones, UEC | T | Bajo-medio | Baja | Sep | FEEC, webs de clubes | Guía de entidades y cómo federarse |

## 3. Calendario editorial priorizado

Supuesto: sitio publicado hacia diciembre 2026 o enero 2027. Si el lanzamiento se retrasa, los meses se desplazan en bloque conservando el orden. Tipos: **P** pilar (guía larga, 1.500+ palabras, hub), **C** cluster (artículo de apoyo, enlaza al pilar), **A** actualidad (vida corta). Ritmo sugerido del plan: un artículo cada dos semanas; aquí se prioriza lo de mayor impacto primero. "Ana" marca los que ya cubre un artículo de `temas.json` (n.º entre paréntesis).

| # | Título de trabajo | Keyword | Pilar | Tipo | Mes | Ficha interna | Gancho de newsletter | Estado |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Mejores rocódromos de Barcelona: guía con criterio y datos | rocódromos Barcelona | Dónde | P | Dic 2026 | Listado de rocódromos y 3 fichas destacadas | "Aviso si un rocódromo cambia tarifas o abre uno nuevo" | Nuevo |
| 2 | Cuánto cuesta escalar en Barcelona en 2026 | precio rocódromo Barcelona | Costes | P | Dic 2026 | Fichas con índice precio | Aviso de cambios de tarifas | Ana (3), ampliar |
| 3 | Cómo elegir pies de gato de escalada según nivel y estilo | pies de gato de escalada | Material | P | Dic 2026 | Comparador | Un pie de gato destacado cada mes | Nuevo |
| 4 | Dónde escalar en Barcelona cuando llueve | escalar cuando llueve Barcelona | Dónde | C | Ene 2027 (primer pico de lluvia) | Rocódromos | Planes de lluvia por mes | Nuevo |
| 5 | Primer bono o cuota mensual: qué conviene según cuántas veces vas | bono rocódromo cuota | Costes | C | Ene 2027 | Fichas (precios) | Comparativa actualizada | Ana (4) parcial |
| 6 | La letra pequeña de los abonos: matrícula, permanencia, pausas | abono rocódromo permanencia | Costes | C | Ene 2027 | Fichas | Aviso de cambios de condiciones | Ana (4) |
| 7 | Zonas de roca a menos de 2 horas de Barcelona para empezar | escalada cerca de Barcelona | Dónde | P | Ene 2027 | Agenda (salidas), fichas | Aviso de cierres y accesos | Nuevo |
| 8 | Del rocódromo a la roca: qué cambia en la primera salida | pasar del rocódromo a la roca | Empezar | C | Feb 2027 | Rocódromos con escuela, agenda | Checklist de la primera salida (en la propia newsletter) | Ana (7) |
| 9 | Margalef con barrera: reserva, coste y qué ha cambiado | Margalef reserva aparcamiento | Dónde | A | Ya; revisión feb 2027 | Agenda | Aviso de cambios de acceso | Ana (5), verificar estado actual |
| 10 | Montserrat o Montsant cerrados: cómo comprobarlo antes de salir | Montserrat cerrado escalada | Dónde | A | Ya; revisión primavera | Agenda | Avisos de cierre | Ana (6), verificar estado a nov 2026 |
| 11 | Rocódromos con zona infantil para ir con hijos | rocódromo niños Barcelona | Empezar | P | Feb 2027 | Fichas con índice familia | Plan de fin de semana en familia | Nuevo |
| 12 | Mi primer resolado: errores que cometí y qué revisar | resolar pies de gato | Material | C | Feb 2027 | Resoladores | Aviso cuando haya resolador nuevo | Nuevo |
| 13 | Cuándo resolar: señales de que tus pies de gato lo necesitan | cuándo resolar pies de gato | Material | C | Mar 2027 | Resoladores | Idem | Nuevo |
| 14 | Rocódromos para ir solo y encontrar compañero | compañero de escalada Barcelona | Comunidad | C | Mar 2027 | Fichas + espera Chalk app | Aviso de lanzamiento Chalk app | Nuevo |
| 15 | Curso de escalada en Barcelona: opciones y precios | curso de escalada Barcelona | Empezar | P | Mar 2027 | Rocódromos con escuela | Aviso de cursos nuevos | Nuevo |
| 16 | Asegurar bien desde el primer día: errores frecuentes | aprender a asegurar | Empezar | C | Mar 2027 | Rocódromos (test de aseguramiento) | Checklist de chequeo mutuo | Ana (8) |
| 17 | Test de aseguramiento: cómo lo hace cada rocódromo de Barcelona | test de aseguramiento rocódromo | Empezar | C | Abr 2027 | Fichas (campo test de aseguramiento) | Idem | Nuevo, falta |
| 18 | Montserrat para empezar: sectores fáciles y cómo llegar en tren | Montserrat escalada principiantes | Dónde | P | Abr 2027 | Agenda, fichas | Avisos de cierre | Nuevo |
| 19 | Calentar antes de escalar: lo que dice la ciencia | calentamiento escalada | Progresión | C | Abr 2027 | Rocódromos con zona de entrenamiento | Rutina corta de 5 minutos | Ana (12) |
| 20 | Lesión de polea: qué dice la evidencia | lesión polea dedo escalada | Progresión | C | Abr 2027 | n/a | Consejos de prevención (sin consejo clínico) | Ana (11) |
| 21 | Cuándo retirar cuerda, arnés y casco | cuándo cambiar la cuerda | Material | C | May 2027 | n/a | Checklist de revisión de material | Ana (9) |
| 22 | Casco en escalada deportiva: cuándo tiene sentido | casco escalada deportiva | Material | C | May 2027 | n/a | Idem | Ana (10) |
| 23 | Entrenar escalada en casa: programa mínimo sin lesionarte | entrenar escalada en casa | Progresión | C | Jun 2027 (verano: indoor y casa) | Rocódromos con zona de entrenamiento | Plan de 4 semanas | Nuevo |
| 24 | Margalef, Siurana o Montsant: qué zona elegir según nivel y época | Siurana Margalef Montsant | Dónde | P | Sep 2027 (antes de temporada) | Agenda | Guía de temporada otoño | Nuevo |
| 25 | Normas no escritas del rocódromo | etiqueta rocódromo | Comunidad | C | Sep 2027 (vuelta) | Rocódromos | Checklist de primer día | Ana (2) |
| 26 | Clubs de escalada de Barcelona y cómo federarte (FEEC) | clubs escalada Barcelona licencia FEEC | Comunidad | C | Sep 2027 | Agenda | Aviso de cursos y federación | Nuevo |
| 27 | World Climbing Series y LA28: cómo seguirlo | clasificación olímpica escalada LA28 | Comunidad | A | Oportunista (picos de competición) | n/a | Calendario de pruebas (ocasional) | Ana (1) |
| 28 | Qué comprar para empezar a escalar: coste del primer año | qué necesito para escalar | Costes | P | Oct-nov 2027 (campaña de regalos) | Comparador | Guía de regalos para escaladores | Nuevo |

Resumen: los 12 artículos de Ana aparecen en 13 filas (el n.º 4 de Ana cubre las filas 5 y 6 en parte; filas 2, 5, 6, 8, 9, 10, 16, 19, 20, 21, 22, 25 y 27) y 15 filas son nuevas. Prioridad: los números 1, 3, 4, 7 y 11 son los de mayor intención y menor competencia editorial.

Notas de calendario (E):

- Roca (Dónde): publicar entre septiembre y febrero para llegar a la temporada; revisar en abril.
- Indoor y costes: reforzar en septiembre y enero.
- Pies de gato: noviembre-diciembre para regalos y campaña de afiliados (marcados).
- Actualidad: no más del 20 % del calendario; su valor es de picos y de Instagram, no de tráfico sostenido.

## 4. Implementación en artículos

### Plantilla on-page

- **Title**: keyword principal al inicio + año o modificador local, máximo 60 caracteres. Ejemplo: "Precio de rocódromos en Barcelona 2026 | ChalkGuide". Único por idioma.
- **Meta description**: 140 a 155 caracteres, con keyword y promesa concreta (dato, tabla, comparativa).
- **H1**: una sola, con la keyword natural, distinta del title en redacción.
- **H2/H3**: responder preguntas reales ("¿Cuánto cuesta…?", "¿Cuándo…?"). Tabla o lista cerca del inicio cuando el artículo sea de datos.
- **Respuesta directa arriba**: dos o tres líneas con la conclusión (ayuda a fragmentos destacados).
- **FAQ**: 3 a 5 preguntas reales al final. `FAQPage` en JSON-LD solo si las preguntas son visibles y propias. Google restringió los rich results de FAQ para la mayoría de sitios, así que el valor es sobre todo de estructura y lectura, no de SERP (hecho conocido; verificar la política vigente antes de invertir tiempo).
- **Schema**: `Article` con `author` (`Person`: Xavi, o Ana según el caso), `datePublished`, `dateModified`, imagen. `BreadcrumbList`. Ya definido en `.ai/marketing-seo.md`.
- **Enlazado interno**: cada cluster enlaza a su pilar; cada pilar enlaza a sus clusters y a las fichas relevantes (rocódromos, resoladores, comparador, agenda). Mínimo 2 enlaces a fichas por artículo. Texto de enlace descriptivo, no "pincha aquí".
- **Imágenes**: propias siempre que sea posible (visitas), `alt` descriptivo en español, formato moderno y dimensiones fijas (cuida el LCP; ver `docs/marketing/lcp-audit-2026-11.md`). Imagen OG 1200x630 por artículo.
- **Fecha visible y "verificado el …"**: obligatorio en artículos con precios, accesos o cierres. Revisión semestral para precios y accesos, anual para lo evergreen. Al revisar se actualiza `dateModified` solo si hay cambio real (evita parecer manipulación).
- **Afiliados**: enlaces con `rel="sponsored nofollow"` y aviso visible; visitas invitadas marcadas. Ninguna reseña comprada.
- **Newsletter**: bloque naranja al final y un enlace discreto de una línea (D48). Nada de pop-ups ni interstitials (D22). El texto del bloque se adapta a la categoría (sección 5); eso lo redacta loro-lola y lo implementa coneja-lucky.

### Versión en inglés: cuándo vale la pena

Recomendación (E): **no traducir todo.** Traducir solo artículos con búsqueda internacional real y sin competencia local fuerte:

- Viajero a Cataluña: Margalef (reserva y barrera), Siurana, Montserrat para principiantes, "rock climbing Barcelona" y "climbing gyms in Barcelona". Los resultados en inglés incluyen Climbing House, Mountain Project, Brocnbells y Barcelona Urbana (en inglés), lo que indica demanda y competencia moderada. Fuente: apéndice A.
- El resto (costes locales, resoladores, cuándo resolar, clubes FEEC) tiene poco público angloparlante.
- Criterio técnico ya fijado en el proyecto (D3): hreflang solo entre versiones que existen; listados `/en` con umbral. Mantener la regla para artículos.
- Momento: cuando haya 3 meses de datos en Search Console y al menos 2 artículos con impresiones desde fuera de España.

## 5. Embudo a newsletter

### Principio

D48 limita la captación en el artículo a un bloque naranja y un enlace de una línea. Por tanto el "gancho" no es un incentivo (no hay descarga con muro) sino la **promesa concreta de la newsletter**, adaptada al contenido del artículo. La segmentación es **implícita por origen** (el artículo que originó el alta) y se afina después con preferencias opcionales.

### Segmentos y ganchos

| Segmento | Origen típico | Gancho en el bloque naranja (dentro de D48) |
| --- | --- | --- |
| Principiante | Empezar a escalar, curso, asegurar | "Cada mes, una guía corta para tu primer año y avisos de cursos nuevos" |
| Boulder / urbano | Rocódromos, costes, comparativa | "Aviso cuando un rocódromo cambie tarifas, abra o actualice rutas" |
| Roca / viajero | Montserrat, Margalef, Siurana, cierres | "Avisos de cierres y accesos antes de la temporada" |
| Familias | Rocódromos con zona infantil | "Planes de escalada para ir con hijos, por temporada" |
| Material | Pies de gato, resolado, cuerda | "Un pie de gato destacado cada mes y cuándo conviene comprar" |
| Compañero / comunidad | Ir solo, Chalk app, etiqueta | "Te avisamos cuando abra Encuentra compañero en tu rocódromo" (lista de espera de Chalk app) |
| Competición | LA28, World Climbing | Solo como etiqueta; no como segmento principal |

Lead magnets compatibles con D48: son entregables dentro de la newsletter de bienvenida (no en pop-ups): checklist de la primera salida a roca, checklist de revisión de material, calendario estacional de zonas de Cataluña, cuadro de tarifas de rocódromos (versión actualizada). Se anuncian solo en una frase del bloque y se entregan en el email de confirmación o de bienvenida.

### Campos y etiquetas a guardar

Ya se guarda email, consentimiento, fecha y origen del consentimiento e idioma (`guide.subscribers`). Propuesta, siempre mínima y con base legal clara (RGPD, minimización):

- `origen_articulo` (slug del artículo) y `origen_categoria` (pilar). Es el dato de segmentación principal, sin pedir nada al usuario.
- `segmento_inferido` derivado de la categoría (tabla de arriba), editable en Brevo.
- `idioma` (es/en/ca si llega el catalán).
- Preferencias opcionales declaradas, solo tras confirmar el doble opt-in y con enlace de preferencias en el primer email: nivel (principiante, intermedio, avanzado), tipo (boulder, deportiva, ambas), zona (Barcelona ciudad, Cataluña, viajero) y si hay hijos (opcional). Todo con casilla clara y no obligatorio.
- No guardar nada de comportamiento individual (qué lee cada persona) sin consentimiento. Las métricas de comportamiento se miden en agregado.
- Para Chalk app (F9): una etiqueta `interes_compañero` solo si la persona se apunta de forma explícita a la lista de espera; no inferirla desde la newsletter. Reutilizar datos para venta de producto afín o para apps requiere base legal propia y texto de consentimiento específico (recomendación para leona-lia y loro-lola; punto abierto en sección 7).

## 6. Medición

### Qué es dato y qué es objetivo

Todos los objetivos son hipótesis (E) para un dominio nuevo sin autoridad. Se recalibran en el mes 3 con datos reales.

### KPIs por etapa

| Etapa | KPI | Fuente | Nota |
| --- | --- | --- | --- |
| Visibilidad | Impresiones, clics, CTR, posición media por consulta y por página | Google Search Console | Gratis; requiere dominio y verificación |
| Tráfico | Sesiones orgánicas, páginas más vistas, páginas por sesión | D5 (Cloudflare Web Analytics o `page_views`) | Sin cookies |
| Interés | Scroll al 75 %, clics a fichas internas desde artículos | Evento propio | Ver eventos |
| Conversión | Altas de newsletter por artículo y tasa de conversión (altas / sesiones del artículo) | Evento + Brevo | Lo más importante |
| Calidad del alta | Tasa de confirmación del doble opt-in | Brevo | Objetivo en torno al 60-80 % (E; benchmark genérico, no medido) |
| Retención | Tasa de apertura y de clic de la newsletter, bajas por envío | Brevo | Apertura es poco fiable por la protección de privacidad de correo; priorizar clics |
| Afiliados | Clics a Barrabes desde el comparador y desde artículos | Evento propio | Marcados `sponsored nofollow` |
| Comunidad | Login para opinar, opiniones enviadas | Evento propio | Ya en `.ai/marketing-seo.md` |

### Eventos de conversión a instrumentar

1. `newsletter_view` del bloque (solo conteo agregado; opcional).
2. `newsletter_submit` con `origen_articulo` y `pilar`.
3. `newsletter_confirmed` (confirmación del doble opt-in; mejor desde el webhook de Brevo en servidor, sin script de terceros en el navegador).
4. `ficha_click` (de artículo a ficha de rocódromo, resolador, comparador o agenda).
5. `affiliate_click` con `partner` e `item`.
6. `login_for_review`, `review_submitted`.
7. `outbound_gym` (clic a la web del rocódromo), opcional.

Todos sin identificadores personales; con `page_views` propia o API de eventos se pueden registrar en una tabla `guide.events` (propuesta para jabali-javi). Cloudflare Web Analytics no admite eventos personalizados de forma nativa (verificar en la documentación vigente antes de decidir); si se elige, los eventos de conversión se medirían con la tabla propia y GSC. **Esto condiciona la decisión de D5 en F4.5.**

### Objetivos (hipótesis, E)

| Horizonte | Impresiones GSC/mes | Clics orgánicos/mes | Altas acumuladas | Comentario |
| --- | --- | --- | --- | --- |
| 3 meses | 2.000 a 6.000 | 100 a 300 | 30 a 100 | Indexación, primeras consultas long tail, ajustes de title |
| 6 meses | 15.000 a 40.000 | 800 a 2.500 | 200 a 500 | Los pilares empiezan a posicionar; efecto Instagram y enlaces de fichas |
| 12 meses | 60.000 a 150.000 | 4.000 a 10.000 | 800 a 2.500 | Depende de actualizar y de enlaces externos; conversión de partida 0,5 % a 1,5 % de sesiones |

Si el bloque naranja convierte menos del 0,5 % en artículos con más de 300 sesiones, revisar copy y posición del bloque antes de añadir presión (no se añade pop-up por D22).

### Cadencia de revisión

- Semanal (15 min): GSC, consultas nuevas, errores de indexación, altas.
- Mensual: ranking de artículos por altas y por clics; actualizar los 3 con más impresiones y peor CTR (title y meta); detectar canibalización.
- Trimestral: revisar precios y accesos de todos los artículos con fecha; recalibrar objetivos; decidir catalán e inglés con datos.
- Anual: auditoría de contenido (fusionar, redirigir 301, retirar).

### Qué requiere F4.5 / D5

- Elegir proveedor de analítica sin cookies y confirmar si soporta eventos (ver arriba).
- Decidir si los eventos de conversión viven en una tabla propia del schema `guide` (jabali-javi, y leona-lia para RLS y minimización).
- Webhook de Brevo para `newsletter_confirmed`.
- Search Console: verificar el dominio el día del lanzamiento y enviar el sitemap (ya existe vía `@nuxtjs/sitemap`).
- Ninguna herramienta de pago nueva sin aprobación de Xavi.

## 7. Riesgos y decisiones abiertas

### Decisiones para Xavi

1. **Catalán**: ¿se hace piloto de 3 a 5 artículos en catalán? Argumentos a favor: casi sin competencia editorial en "rocòdrom/curs d'escalada", audiencia local alta y fidelizable, FEEC y cursos en catalán. En contra: coste de mantenimiento y de i18n (hoy solo es/en), riesgo de diluir esfuerzo. Mi recomendación: decidir tras 3 meses de datos; si se hace, empezar por precios y cursos. Implica `ca` en i18n y hreflang (coneja-lucky y yo).
2. **Dominio** (`.com` o `.es`): sin dominio no hay indexación, ni GSC, ni autoridad acumulada. Recomendación: decidir antes del lanzamiento; `.es` es más coherente con foco local, `.com` con la marca y el inglés (E). Cambiar de dominio después cuesta posicionamiento.
3. **Analítica D5** (Cloudflare Web Analytics o `page_views`): ver sección 6. Preferencia SEO: tabla propia si se necesitan eventos.
4. **Reutilización de la audiencia** para producto afín y Chalk app: necesita consentimiento específico y texto legal (loro-lola y leona-lia). Sin eso, la lista solo sirve para la newsletter.
5. **Autoría**: ¿aparece Ana como autora en sus artículos o todo bajo la voz de Xavi? Afecta a `Person` en JSON-LD y a la señal de experiencia (E-E-A-T). Recomendación: autoría real y visible, con ficha de autor.
6. **Ritmo editorial**: un artículo cada dos semanas (plan) frente al ritmo del calendario (28 piezas en 12 meses implica más del doble). Los primeros 3 meses justifican acelerar.

### Riesgos

- **Contenido que caduca**: precios, accesos (Margalef, Montserrat) y cierres cambian. Mitigación: fecha visible, revisión semestral y calendario de actualización. Un dato obsoleto daña confianza y ranking.
- **YMYL ligero** (lesiones, seguridad con cuerda): tono prudente, remitir a profesional o a escuela, citar fuentes. Los datos de accidentes de Ana son de Alemania y Austria, no de España; mantenerlo explícito.
- **Dependencia de fuentes únicas**: pies de gato solo desde Barrabes; si Barrabes cambia modelos o precios, el comparador se vacía. Registrar fecha de precio.
- **Canibalización**: los artículos de precios (Ana 3, 4, nuevos 2, 5, 6) se parecen. Mapear una keyword por URL y usar el pilar de costes como hub.
- **Dominio nuevo sin autoridad**: sin enlaces externos el tráfico tarda. Mitigación: fichas compartibles con rocódromos y resoladores, Instagram, menciones de comunidad y clubes. Prohibido comprar enlaces.
- **Independencia editorial**: cualquier artículo con afiliado o visita invitada lleva aviso visible. Los rocódromos que comparten la ficha no compran reseña.
- **Estimaciones**: todos los volúmenes y objetivos son hipótesis. Validar con Search Console desde el primer mes antes de invertir en piezas largas.
- **Falta de datos de mercado agregados**: no se encontraron cifras de federados ni de crecimiento de rocódromos en España en esta sesión; los datos de crecimiento citados por Ana vienen de la encuesta de Climbing Wall Association (EE. UU.), no de España.

## Apéndice A · Fuentes consultadas (2026-11-12)

Búsquedas web (resultados y SERP observados; no son cifras de volumen):

- Rocódromos de Barcelona y precios: [Time Out Barcelona](https://www.timeout.es/barcelona/es/deportes/rocodromos-indoor-de-barcelona), [Yumping](https://www.yumping.com/rocodromos/barcelona), [Picuco](https://www.picuco.com/es-es/activities/rocodromo-barcelona), [Urban Sports Club](https://urbansportsclub.com/es/venues/kimera-climbing-barcelona), [Barcelona Urbana, precios en catalán](https://barcelonaurbana.com/ca/blog/rocodroms-barcelona-preus), [Climbing House](https://climbinghouse.com/best-gyms-barcelona/), [ClassPass Sharma](https://classpass.com/studios/sharma-climbing-bcn-barcelona).
- Escalada cerca de Barcelona y zonas: [Barcelona Urbana](https://barcelonaurbana.com/blog/escalada-cerca-barcelona), [Eurovista](https://eurovistatrips.com/es/zonas-escalada-cerca-barcelona/), [Explore-Share](https://www.explore-share.com/es/trip/escalada-en-roca-catalonia/), [theCrag Margalef](https://www.thecrag.com/es/escalar/spain/margalef), [theCrag Siurana](https://www.thecrag.com/es/escalar/spain/siurana), [theCrag Montsant](https://www.thecrag.com/es/escalar/spain/montsant), [Diari de Tarragona](https://www.diaridetarragona.com/internacional/100166/escalada-en-el-priorat-20180919-0039-jsdt201809190039.html), [Manawa](https://www.manawa.com/es-ES/actividad/espana/montserrat/escalada/iniciacion-a-la-escalada-en-grupo-en-montserrat-cerca-de-barcelona/5010), [GuruWalk](https://www.guruwalk.com/es/walks/p80502-montserrat-bautizo-de-escalada-cerca-de-barcelona-cGFub3B0ZXM).
- Estacionalidad en Tarragona: [Explore-Share Siurana](https://www.explore-share.com/es/escalada-en-roca/espana/siurana/), [Picuco Cataluña](https://www.picuco.com/es-es/what-in/cataluna/escalada-en-roca/).
- Pies de gato: [Hola.com](https://www.hola.com/seleccion/20240228674339/mejores-pies-de-gato/), [Decathlon guía](https://www.decathlon.es/es/c/htc/como-elegir-pies-de-gato_f9811862-dba9-451c-9f1b-1438ec2a1691), [Bergfreunde](https://www.bergfreunde.es/pies-de-gato/nivel-de-experiencia--iniciacion/), [BBVA](https://www.bbva.com/es/los-pies-de-gato-el-calzado-ideal-para-escalar-en-roca/).
- Cursos y federación: [FEEC licencias 2026](https://www.feec.cat/wp-content/uploads/2025/12/LLicencies-2026.pdf), [Cordada AEE nivel 1](https://www.feec.cat/wp-content/uploads/2022/04/Cordada_AEE_escalada_nivell_1.pdf), [UEC Horta](https://www.feec.cat/wp-content/uploads/2023/07/UEC_Horta_escalada_nivell_1-2.pdf), [UAB iniciación](https://www.uab.cat/doc/IniciacioEscalada).
- Familias: [Yumping La Panxa del Bou](https://www.yumping.com/multiaventura/la-panxa-del-bou--e19688475), [Yumping FLASHH](https://www.yumping.com/rocodromos/flashh-barcelona--e19777621), [Barcelona Urbana cumpleaños](https://barcelonaurbana.com/blog/cumpleanos-infantiles-barcelona).
- Mercado y datos de contexto: los de `docs/content/blog-ana/temas.json` (CWA 2026, DAV/KLEVER, World Climbing, La Crux, prensa catalana).

Limitaciones de esta investigación:

- Sin Google Trends, sin herramientas de volumen, sin ver los SERP reales con ubicación Barcelona. Los resultados de las búsquedas pueden variar por ubicación y personalización.
- No se verificó el contenido concreto de Desnivel ni del blog de Barrabes: las búsquedas no los devolvieron. Se citan como competidores probables (E), por lo que conviene comprobarlos a mano antes de redactar cada pilar.
- Precios y condiciones de rocódromos de agregadores y blogs son orientativos; confirmar siempre en la web de cada centro y registrar fecha de consulta.
