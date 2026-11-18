# Chalk Guide · Plan de proyecto

Oct 4, 2026 · @Xavi

## Visión y propuesta de valor

Chalk Guide es un medio editorial de escalada en Barcelona: información útil, con voz de autor, para escaladores amateurs entusiastas. No promete ser el mejor sitio de nada; publica lo que a un escalador constante le sirve de verdad.

- **Audiencia:** amplia a propósito, para ir afinándola según cómo responda. Dos grupos principales: quienes se están iniciando (uno o dos meses escalando, entusiasmados y llenos de dudas sobre dónde escalar, qué pies de gato comprar, cómo mejorar y qué cuidar) y quienes escalan 2 o 3 veces por semana hace años sin ser profesionales. Locales y expats. Posible subtarget a futuro: personas que empiezan o progresan pasados los 40.
- **Referencia de estilo:** Mama Proof, pero para escaladores. Datos concretos, artículos prácticos, recomendaciones y novedades.
- **Diferenciador:** la experiencia real del autor (6 años escalando en Barcelona, nivel 7b a los 41, y el recuerdo de haber empezado sin a quién preguntar) más datos ordenados y comparables que hoy están dispersos.
- **Objetivo:** construir una audiencia propia (emails) de forma orgánica, que en el futuro alimente a Chalk app y permita monetizar.
- **Horizonte:** semilla de largo plazo, sin urgencia de ingresos.

## Marca y estructura

Chalk es la marca paraguas: Chalk Guide es el sitio editorial y Chalk app es la herramienta para encontrar compañero. Comparten backend y usuarios.

| Pieza | Qué es | Dominio | Repo |
| --- | --- | --- | --- |
| Chalk Guide | Sitio público: fichas, comparador, artículos, opiniones | chalkguide.com o .es (por confirmar) | chalk-web |
| Chalk app | Matching de compañeros por rocódromo | app.chalkguide.com | chalk-app |
| Backend | Supabase compartido (proyecto actual de Chalk) | n/a | n/a |

Pendiente: confirmar disponibilidad del dominio y del handle de Instagram antes de cerrar el nombre.

## Secciones del sitio

El MVP tiene tres secciones de datos y una editorial. Todo con opinión del autor primero y opiniones de usuarios después.

| Sección | Contenido | Voz del autor | Usuarios |
| --- | --- | --- | --- |
| Rocódromos | Ficha técnica completa + artículo de visita | Reseña destacada por cada rocódromo visitado | Opinión con nota por criterios |
| Resoladores | Precio por par, plazo, rand, envío por correo, calidad | Experiencia propia y errores cometidos | Opinión con nota |
| Pies de gato | Comparador de datos técnicos públicos, lado a lado, con filtros y rango de precio | "Lo que aprendí" en los modelos que tengo | No en MVP |
| Artículos | Guías prácticas y novedades | Toda la sección | Comentarios no en MVP |
| Agenda | Actividades, competiciones y salidas del mes | Selección del autor | No |
| Sobre mí | Quién escribe y por qué | Breve | No |

Chalk app entra como "Encuentra compañero" dentro de cada ficha de rocódromo, con lista de espera por gimnasio.

## Pilares de contenido y primeros 10 artículos

Seis pilares: empezar a escalar, dónde escalar, material, progresión y cuidado, costos y comunidad. La IA ayuda a redactar y ordenar datos; el criterio y la experiencia son del autor.

1. Dónde escalar en Barcelona cuando llueve
2. Rocódromos con zona infantil para ir con hijos
3. Mi primer resolado: errores que cometí y qué revisar
4. Cuánto cuesta realmente escalar en Barcelona al mes
5. Rocódromos para ir solo y encontrar compañero
6. Cómo elegir pies de gato según tu nivel y estilo
7. Cuándo resolar: señales de que tus pies de gato lo necesitan
8. Primer bono o cuota mensual: qué conviene según cuántas veces vas
9. Zonas de roca a menos de 2 horas de Barcelona para empezar
10. Lo que aprendí de mis pies de gato después de años usándolos

Ritmo sugerido: un artículo cada dos semanas, alineado con las visitas a rocódromos. Cada pieza se recicla en 2 o 3 publicaciones de Instagram.

## Modelo de datos

Modelo genérico desde el inicio: cada entidad evaluable comparte una tabla base, y los criterios de nota se definen por categoría. Así sumar cuerdas, arneses o sectores de roca es configuración, no reconstrucción.

| Tabla | Propósito | Campos clave |
| --- | --- | --- |
| items | Base común de todo lo evaluable | categoría, nombre, slug, resumen, publicado, fecha de verificación, fuente |
| gyms | Detalle de rocódromos | ubicación, metro, horarios, precios (matrícula, día, bono 10, mensual, descuentos), m², altura, vías, boulder, autobelays, zona de entrenamiento, test de aseguramiento, alquiler de material, cafetería, cerveza, zona infantil, duchas, wifi |
| resolers | Detalle de resoladores | ubicación, precio por par, precio rand, plazo, envío por correo, marcas de goma |
| shoes | Detalle de pies de gato | marca, modelo, perfil, asimetría, cierre, goma, rigidez, uso recomendado, rango de precio, fecha de precio, enlace de afiliado |
| author\_reviews | Reseña del autor | item, texto, nota por criterio, fecha de visita, visita pagada o invitada |
| criteria | Criterios de nota por categoría | categoría, nombre, orden |
| user\_reviews | Opiniones de usuarios | item, usuario, nota por criterio, texto corto, estado de moderación |
| profiles | Usuarios (compartido con Chalk app) | nombre, avatar, roles |
| subscribers | Lista de newsletter | email, consentimiento, fecha y origen del consentimiento, idioma |
| events | Agenda de actividades | rocódromo, título, fecha, enlace, estado (borrador o aprobado) |
| gym\_waitlist | Lista de espera de Chalk app | rocódromo, usuario |

Puntajes derivados (no son opinión, se calculan): índice principiante, índice precio (costo mensual a 2 visitas por semana) e índice familia.

## Opiniones de usuarios y login

Las opiniones quedan abiertas desde el día uno, pero la ficha nunca depende de ellas: la reseña del autor siempre llena la página.

- **Login con Google** obligatorio para opinar. Sin fricción y deja el email en la base.
- **Formato corto:** nota de 1 a 5 por criterio + texto breve opcional.
- **Jerarquía:** reseña del autor arriba y destacada; opiniones de usuarios debajo.
- **Promedio de usuarios** visible solo con 3 o más opiniones.
- **Moderación:** el autor puede ocultar opiniones. Una opinión por usuario e ítem, editable.
- **Transparencia:** si una visita fue invitada por el rocódromo, se indica en la reseña.

## Newsletter y agente de novedades

El newsletter es el canal propio; Instagram es prestado. Mensual al principio.

- **Consentimiento (RGPD):** iniciar sesión con Google no autoriza enviar newsletter. Casilla explícita "quiero recibir novedades", desmarcada por defecto, y registro de fecha y origen del consentimiento.
- **Fuente de verdad:** la lista vive en Supabase. El envío lo hace un servicio con plan gratuito (Brevo o Resend), que gestiona bajas.
- **Contenido tipo:** novedades del mes en rocódromos + artículo nuevo + un pie de gato destacado.
- **Agente de novedades:** tarea programada semanal que revisa las webs de los rocódromos, detecta actividades y deja borradores en la tabla de agenda. El autor aprueba; nada se publica solo.
- **Instagram (D82, 2026-11-13):** se lee por la API oficial de Meta (Business Discovery), solo cuentas profesionales y en solo lectura. Las cuentas personales siguen cargándose a mano.

## Monetización

No hay ingresos en los primeros 12 meses; el objetivo es audiencia. Las vías, en orden de llegada probable:

| Vía | Cuándo | Requisito |
| --- | --- | --- |
| Afiliados de material (Deporvillage, Barrabes, Decathlon) | Desde el lanzamiento del comparador | Programas de afiliado activos |
| Patrocinio del newsletter (marcas de material, rocódromos, resoladores) | Con 2.000 a 3.000 suscriptores | Audiencia local comprometida |
| Destacados o alianzas con rocódromos | Con datos de demanda (lista de espera de Chalk) | Credibilidad e independencia intactas |
| Chalk app premium | Cuando haya densidad por rocódromo | Matching funcionando |

Regla: ninguna vía compra una reseña. Lo pagado se marca.

## Stack técnico

Un solo Supabase, dos frontends, costo cero en hosting.

| Capa | Herramienta | Motivo |
| --- | --- | --- |
| Sitio | Nuxt (Vue) + Tailwind | HTML generado: SEO, previews al compartir, carga rápida en móvil |
| App | Vue + Vite (Chalk actual) | App detrás de login, no necesita SEO |
| Backend | Supabase (Auth con Google, Postgres, Storage) | Usuarios y rocódromos compartidos entre sitio y app |
| Idiomas | @nuxtjs/i18n, español por defecto e inglés | Locales y expats |
| Deploy | Netlify, render híbrido (prerender + SSR donde haga falta) | Gratis y ya conocido |
| Email | Brevo o Resend, plan gratuito | Envío y bajas del newsletter |
| Agente | Tarea programada + Claude API | Borradores de agenda semanales |

## Fases y próximos pasos

1. **Fase 1 (meses 0 a 6):** rocódromos, resoladores, comparador de pies de gato y primeros artículos. Login con Google, opiniones y captura de newsletter ya construidos. Instagram desde el primer artículo.
2. **Fase 2 (meses 6 a 12):** agente de novedades, agenda mensual y newsletter mensual. Todos los rocódromos del área metropolitana visitados.
3. **Fase 3 (desde el mes 12):** Chalk app integrada como "Encuentra compañero" y activación por rocódromo con 30 a 50 interesados.

Presupuesto: unos 300 a 450 € en entradas durante el primer año. Hosting y herramientas en planes gratuitos.

Próximos pasos:

- [ ] Confirmar dominio y handle de Instagram para Chalk Guide
- [ ] Correr el prompt de scaffold de Nuxt en Claude Code
- [ ] Escribir el prompt de arquitectura (orquestador, agentes, CLAUDE.md, MCP) a partir de este plan
- [ ] Listar los rocódromos del área metropolitana y definir el orden de visitas
- [ ] Mostrar las primeras 3 o 4 fichas a 5 o 10 compañeros de rocódromo
