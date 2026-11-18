/* ChalkGuide · Editorial v2 · utilidades de los mockups (no es código de la app).
   Configura Tailwind CDN, pinta cabecera, bloque naranja y pie tal y como están hoy (no cambian),
   y añade comportamientos del mockup: notas, reveal, trazo de tiza, índice y progreso. */
document.documentElement.classList.add('js')
window.tailwind = window.tailwind || {}
tailwind.config = { theme: { extend: {
  colors: {
    background:'var(--color-background)', board:'var(--color-board)', elevated:'var(--color-elevated)', tray:'var(--color-tray)',
    line:'var(--color-line)', 'line-strong':'var(--color-line-strong)', control:'var(--color-control)',
    accent:'var(--color-accent)', 'accent-fill':'var(--color-accent-fill)', 'accent-muted':'var(--color-accent-muted)', chalk:'var(--color-chalk)',
    foreground:'var(--color-foreground)', prose:'var(--color-prose)', meta:'var(--color-meta)', muted:'var(--color-muted)',
    paper:'#f4f1ea', ink:'#1c1a17',
  },
  fontFamily: { sans:['Inter','system-ui','sans-serif'], mono:['"JetBrains Mono"','ui-monospace','monospace'], hand:['Caveat','cursive'] },
  maxWidth: { page:'1200px', prose:'640px' },
} } }

const EV2 = {
  img: (p) => 'https://eqtjlafxtrzbjazhhyin.supabase.co/storage/v1/object/public/media/' + p,
  root: '../../../../public/',
}
const ICON = {
  arrow: '<svg class="arr" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
}

function siteHeader(active, withNews) {
  const items = [['rocodromos','Rocódromos'],['pies','Pies de gato'],['resolar','Resolar'],['blog','Blog']]
  // F8 (propuesta): «Noticias» entra tras Blog solo en los mockups que lo piden (data-news)
  if (withNews) items.push(['noticias','Noticias'])
  items.push(['agenda','Agenda'],['sobre','Sobre mí'])
  const nav = items.map(([k, l]) => `<a href="#" class="relative flex items-center h-11 px-1 text-[15px] ${k === active ? 'text-[#e8923a]' : 'text-[#f0ede8] hover:text-[#e8923a]'} transition-colors duration-150" ${k === active ? 'aria-current="page"' : ''}>${l}${k === active ? '<span class="absolute left-0 right-0 bottom-0.5 h-[2px] rounded bg-[#e8923a]"></span>' : ''}</a>`).join('')
  return `<header class="chrome-dark relative z-30">
  <div class="max-w-page mx-auto px-4 md:px-6 h-16 lg:h-20 flex items-center justify-between gap-6">
    <a href="#" class="flex items-end gap-2" aria-label="ChalkGuide, inicio"><img src="${EV2.root}brand/logo-white.svg" alt="" class="h-6 lg:h-7 w-auto block"><span class="font-mono text-[12px] tracking-[.14em] leading-none pb-[3px] text-[#a19d94]" aria-hidden="true">BCN</span></a>
    <nav class="hidden lg:flex items-center ${withNews ? 'gap-5 xl:gap-8 whitespace-nowrap' : 'gap-8'}" aria-label="Principal">${nav}</nav>
    <div class="hidden lg:flex items-center gap-1 font-mono text-[13px] tracking-[.1em]"><span class="grid place-items-center w-11 h-11 rounded-lg bg-[#242424]">ES</span><a href="#" class="grid place-items-center w-11 h-11 text-[#a19d94]">EN</a></div>
    <button type="button" class="lg:hidden grid place-items-center w-11 h-11 -mr-2" aria-label="Abrir menú"><svg width="26" height="20" viewBox="0 0 26 20" fill="none" stroke="#f0ede8" stroke-width="2.4" stroke-linecap="round" aria-hidden="true"><path d="M2 3h22M8 10h16M2 17h22"/></svg></button>
  </div>
</header>`
}

function newsletterBlock(weekly) {
  return `<section id="newsletter" class="field-orange dust" aria-labelledby="t-news">
  <div class="max-w-page mx-auto px-4 md:px-6 py-20 md:py-28 lg:py-[120px]">
    <h2 id="t-news" class="title-section-lg">${weekly ? 'Una carta a la semana.<br>Nada más.' : 'Una carta al mes.<br>Nada más.'}</h2>
    <div class="mt-10 lg:mt-14 grid lg:grid-cols-12 gap-x-6 gap-y-8 items-start">
      <div class="lg:col-span-5">
        <p class="text-[20px] md:text-[24px] leading-[1.35] tracking-[-.01em] font-medium max-w-[26ch]">${weekly ? 'Las noticias de la semana con su fuente, la agenda de las dos próximas y el artículo nuevo.' : 'Novedades de los rocódromos, el artículo nuevo y un pie de gato que merece la pena.'}</p>
        <p class="mt-4 text-[15px] text-meta">Sin spam. Baja en un clic.</p>
      </div>
      <div class="lg:col-span-6 lg:col-start-7">
        <div class="on-paper slab-dark bg-paper p-5 md:p-7">
          <form onsubmit="return false" novalidate>
            <div class="flex flex-col gap-3 lg:flex-row lg:items-start">
              <div class="flex-1 min-w-0">
                <label for="nl-email" class="block text-[15px] font-medium mb-2">Tu email</label>
                <input id="nl-email" type="email" autocomplete="email" placeholder="nombre@correo.com" class="w-full min-h-[52px] px-3.5 rounded-lg border border-[#827a6d] bg-[#fbf9f5] text-[16px] placeholder:text-[#6b6559]">
              </div>
              <button type="submit" class="btn btn-ink w-full lg:w-auto lg:mt-[32px]"><span>Suscribirme</span>${ICON.arrow}</button>
            </div>
            <label class="mt-4 flex items-start gap-3 min-h-11 text-[15px] leading-[1.45]"><input type="checkbox" class="mt-0.5 w-[22px] h-[22px] accent-[#e8923a] flex-none"><span>Quiero recibir novedades de ChalkGuide por email. Puedo darme de baja cuando quiera. <a href="#" class="link text-[#9a4a16]">Política de privacidad</a>.</span></label>
          </form>
        </div>
      </div>
    </div>
  </div>
</section>`
}

function siteFooter() {
  const li = (l) => `<li><a href="#" class="flex items-center min-h-11 hover:text-accent transition-colors duration-150">${l}</a></li>`
  return `<footer class="chrome-dark">
  <div class="max-w-page mx-auto px-4 md:px-6 pt-16 md:pt-20 pb-8">
    <div class="grid lg:grid-cols-12 gap-x-6 gap-y-12">
      <div class="lg:col-span-5">
        <img src="${EV2.root}brand/logo-white.svg" alt="ChalkGuide" class="h-7 w-auto block">
        <p class="mt-8 text-[24px] md:text-[28px] leading-[1.2] tracking-[-.015em] font-medium max-w-[20ch]">Ninguna reseña se compra. Lo pagado se marca.</p>
      </div>
      <div class="lg:col-span-7 grid grid-cols-2 sm:grid-cols-3 gap-x-6 gap-y-10 text-[15px]">
        <nav aria-label="Guías"><p class="text-[13px] font-medium text-meta">Guías</p><ul class="mt-2">${li('Rocódromos')}${li('Pies de gato')}${li('Resolar pies de gato')}</ul></nav>
        <nav aria-label="Medio"><p class="text-[13px] font-medium text-meta">Medio</p><ul class="mt-2">${li('Blog')}${li('Agenda')}${li('Newsletter')}${li('Sobre mí')}</ul></nav>
        <nav aria-label="Cuentas claras"><p class="text-[13px] font-medium text-meta">Cuentas claras</p><ul class="mt-2">${li('Transparencia')}${li('Privacidad')}${li('Cookies')}</ul></nav>
      </div>
    </div>
    <div class="mt-12 pt-5 border-t border-line-strong flex flex-wrap justify-between gap-x-6 text-[13px] text-meta"><p class="flex items-center min-h-11">© 2026 ChalkGuide</p><a href="#" lang="en" class="flex items-center min-h-11">English</a></div>
  </div>
</footer>`
}

function mockBar(title, links) {
  return `<div class="mock-bar"><div class="max-w-page mx-auto px-4 md:px-6 py-2 flex flex-wrap items-center gap-x-4 gap-y-1">
    <strong class="font-medium">${title}</strong>${links}
    <a href="editorial-v2.html">Índice de la propuesta</a>
    <button type="button" id="toggle-notes">Ver notas</button></div></div>`
}

document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('[data-ev2]').forEach((el) => {
    const k = el.dataset.ev2
    if (k === 'header') el.outerHTML = siteHeader(el.dataset.active, 'news' in el.dataset)
    if (k === 'newsletter') el.outerHTML = newsletterBlock('weekly' in el.dataset)
    if (k === 'footer') el.outerHTML = siteFooter()
    if (k === 'mockbar') el.outerHTML = mockBar(el.dataset.title, el.innerHTML)
  })
  document.getElementById('toggle-notes')?.addEventListener('click', (e) => {
    const on = document.body.classList.toggle('notes')
    e.currentTarget.textContent = on ? 'Ocultar notas' : 'Ver notas'
  })
  // Reveal y trazo de tiza (una vez)
  const io = new IntersectionObserver((es) => es.forEach((x) => { if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target) } }), { rootMargin: '0px 0px -8% 0px' })
  document.querySelectorAll('.reveal,[data-draw]').forEach((el) => io.observe(el))
  window.EV2_READY && window.EV2_READY()
})
