/* ChalkGuide · layout compartido de los mockups F1.6 (header, menú, barra compacta, footer, iconos).
   Cada página declara en <body>: data-nav (clave activa), data-route-es / data-route-en (rutas reales §6). */
(() => {
  const B = '../../../../public/brand/';
  const body = document.body;
  const nav = body.dataset.nav || '';
  const cur = (k) => nav === k ? ' aria-current="page"' : '';
  const LOGO = (cls, alt = '') => `<img src="${B}logo-white.svg" alt="${alt}" width="2073" height="384" class="${cls} w-auto">`;
  const BARS = (cls) => `<svg viewBox="0 22 315 338" class="${cls}" fill="currentColor" aria-hidden="true" focusable="false"><rect y="102" width="69" height="258" rx="34.5"/><rect x="82" y="22" width="69" height="275" rx="34.5"/><rect x="164" y="84" width="69" height="246" rx="34.5"/><rect x="246" y="143" width="69" height="154" rx="34.5"/></svg>`;
  const CHEV = '<svg class="chev ico !w-3.5 !h-3.5" aria-hidden="true"><use href="#i-chevron-down"/></svg>';
  const guias = [
    ['rocodromos', 'rocodromos.html', 'Rocódromos', '5 fichas con precios y mi reseña'],
    ['resolar', 'resolar-pies-de-gato.html', 'Resolar pies de gato', 'Precio por par, plazo y calidad'],
    ['pies', 'pies-de-gato.html', 'Pies de gato', 'Comparador lado a lado'],
  ];
  const guiasActive = guias.some(g => g[0] === nav);
  const ddItems = guias.map(g => `<li><a class="dd-item" href="${g[1]}"${cur(g[0])}><span class="block text-foreground">${g[2]}</span><span class="block text-sm text-meta">${g[3]}</span></a></li>`).join('');
  const navList = (id) => `
    <ul class="flex items-center gap-7 text-[15px]">
      <li class="dd" data-dd>
        <button type="button" class="dd-btn${guiasActive ? ' !text-foreground' : ''}" aria-expanded="false" aria-controls="${id}">Guías ${CHEV}</button>
        <ul id="${id}" class="dd-panel">${ddItems}</ul>
      </li>
      <li><a class="navlink" href="blog.html"${cur('blog')}>Blog</a></li>
      <li><a class="navlink" href="agenda.html"${cur('agenda')}>Agenda</a></li>
      <li><a class="navlink" href="sobre-mi.html"${cur('sobre')}>Sobre mí</a></li>
    </ul>`;

  const sprite = `<svg width="0" height="0" class="absolute" aria-hidden="true">
  <symbol id="i-arrow-right" viewBox="0 0 24 24"><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></symbol>
  <symbol id="i-chevron-down" viewBox="0 0 24 24"><path d="m6 9 6 6 6-6"/></symbol>
  <symbol id="i-check" viewBox="0 0 24 24"><path d="M20 6 9 17l-5-5"/></symbol>
  <symbol id="i-x" viewBox="0 0 24 24"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></symbol>
  <symbol id="i-search" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></symbol>
  <symbol id="i-menu" viewBox="0 0 24 24"><path d="M4 6h16"/><path d="M4 12h16"/><path d="M4 18h16"/></symbol>
  <symbol id="i-map-pin" viewBox="0 0 24 24"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></symbol>
  <symbol id="i-clock" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></symbol>
  <symbol id="i-calendar" viewBox="0 0 24 24"><rect width="18" height="18" x="3" y="4" rx="2"/><path d="M16 2v4"/><path d="M8 2v4"/><path d="M3 10h18"/></symbol>
  <symbol id="i-info" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></symbol>
  <symbol id="i-alert" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 8v4"/><path d="M12 16h.01"/></symbol>
  <symbol id="i-external" viewBox="0 0 24 24"><path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/></symbol>
  <symbol id="i-users" viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></symbol>
  <symbol id="i-mail" viewBox="0 0 24 24"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></symbol>
  <symbol id="i-gift" viewBox="0 0 24 24"><rect x="3" y="8" width="18" height="4" rx="1"/><path d="M12 8v13"/><path d="M19 12v7a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-7"/><path d="M7.5 8a2.5 2.5 0 0 1 0-5C9.5 3 11 5 12 8c1-3 2.5-5 4.5-5a2.5 2.5 0 0 1 0 5"/></symbol>
  <symbol id="i-link" viewBox="0 0 24 24"><path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/></symbol>
  <symbol id="i-badge-check" viewBox="0 0 24 24"><path d="M3.85 8.62a4 4 0 0 1 4.78-4.77 4 4 0 0 1 6.74 0 4 4 0 0 1 4.78 4.78 4 4 0 0 1 0 6.74 4 4 0 0 1-4.77 4.78 4 4 0 0 1-6.75 0 4 4 0 0 1-4.78-4.77 4 4 0 0 1 0-6.76Z"/><path d="m9 12 2 2 4-4"/></symbol>
  <symbol id="i-train" viewBox="0 0 24 24"><rect width="16" height="16" x="4" y="3" rx="2"/><path d="M4 11h16"/><path d="M12 3v8"/><path d="m8 19-2 3"/><path d="m18 22-2-3"/><path d="M8 15h.01"/><path d="M16 15h.01"/></symbol>
  <symbol id="i-sliders" viewBox="0 0 24 24"><path d="M4 21v-7"/><path d="M4 10V3"/><path d="M12 21v-9"/><path d="M12 8V3"/><path d="M20 21v-5"/><path d="M20 12V3"/><path d="M2 14h4"/><path d="M10 8h4"/><path d="M18 16h4"/></symbol>
  <symbol id="i-pencil" viewBox="0 0 24 24"><path d="M21.17 6.81a2.83 2.83 0 0 0-4-4L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5Z"/><path d="m15 5 4 4"/></symbol>
  <symbol id="i-star" viewBox="0 0 24 24"><path d="M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z"/></symbol>
  <symbol id="i-globe" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"/><path d="M12 2a14.5 14.5 0 0 0 0 20 14.5 14.5 0 0 0 0-20"/><path d="M2 12h20"/></symbol>
  <symbol id="i-truck" viewBox="0 0 24 24"><path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2"/><path d="M15 18H9"/><path d="M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14"/><circle cx="17" cy="18" r="2"/><circle cx="7" cy="18" r="2"/></symbol>
  <symbol id="i-arrow-left" viewBox="0 0 24 24"><path d="m12 19-7-7 7-7"/><path d="M19 12H5"/></symbol>
  <symbol id="i-minus" viewBox="0 0 24 24"><path d="M5 12h14"/></symbol>
</svg>`;
  const mock = `<div class="mock-bar"><div class="max-w-page mx-auto px-4 md:px-6 py-1.5 flex flex-wrap gap-x-4 gap-y-0.5 justify-between">
      <span>Mockup F1.6 · ruta <span class="text-foreground">${body.dataset.routeEs || ''}</span>${body.dataset.routeEn ? ` · EN <span class="text-foreground">${body.dataset.routeEn}</span>` : ''}</span>
      <a href="../index.html">← índice de mockups</a></div></div>`;
  const sticky = `
  <div class="sticky-bar" id="stickyBar" aria-hidden="true" inert>
    <div class="max-w-page mx-auto px-4 md:px-6 h-14 flex items-center justify-between gap-4">
      <a href="../direccion-e-pizarra.html" class="flex items-center min-h-[44px]" aria-label="ChalkGuide, inicio">${BARS('h-6 w-auto text-white md:hidden')}${LOGO('hidden md:block h-5')}</a>
      <nav aria-label="Principal (compacta)" class="hidden md:block">${navList('dd-guias-2')}</nav>
      <div class="flex items-center gap-2">
        <a href="../direccion-e-pizarra.html#newsletter" class="btn btn-primary hidden sm:inline-flex"><span class="label">Newsletter</span></a>
        <button type="button" data-menu-toggle class="btn btn-ghost md:hidden" aria-controls="menu" aria-expanded="false"><span class="label">Menú</span></button>
      </div>
    </div>
  </div>`;
  const sheet = `
  <div class="sheet" id="menu" aria-hidden="true">
    <div class="scrim" data-menu-close></div>
    <div class="panel" role="dialog" aria-modal="true" aria-label="Menú">
      <div class="w-12 h-1 bg-line-strong rounded-full mx-auto mt-3" aria-hidden="true"></div>
      <nav aria-label="Principal (móvil)" class="px-5 pt-3 pb-2">
        <ul class="text-xl">
          <li class="border-b-[0.5px] border-line">
            <button type="button" class="acc-btn w-full flex items-center justify-between min-h-[52px]" aria-expanded="${guiasActive}" aria-controls="acc-guias">Guías <svg class="chev ico" aria-hidden="true"><use href="#i-chevron-down"/></svg></button>
            <div id="acc-guias" class="acc${guiasActive ? ' is-open' : ''}"><div>
              <ul class="pb-3 pl-4 border-l-[0.5px] border-line-strong ml-1 text-[17px]">
                ${guias.map(g => `<li><a class="flex items-center min-h-[44px] ${nav === g[0] ? 'text-foreground' : 'text-meta'} hover:text-foreground" href="${g[1]}"${cur(g[0])}>${g[2]}</a></li>`).join('')}
              </ul></div></div>
          </li>
          <li><a class="flex items-center min-h-[52px] border-b-[0.5px] border-line" href="blog.html"${cur('blog')}>Blog</a></li>
          <li><a class="flex items-center min-h-[52px] border-b-[0.5px] border-line" href="agenda.html"${cur('agenda')}>Agenda</a></li>
          <li><a class="flex items-center min-h-[52px]" href="sobre-mi.html"${cur('sobre')}>Sobre mí</a></li>
        </ul>
      </nav>
      <div class="px-5 pb-6 flex items-center justify-between gap-3">
        <div class="flex gap-1 font-mono text-sm"><a href="#" aria-current="true" class="px-3 min-h-[44px] inline-flex items-center rounded-sm bg-elevated">ES</a><a href="#" lang="en" class="px-3 min-h-[44px] inline-flex items-center text-meta">EN</a></div>
        <button type="button" class="btn btn-ghost" data-menu-close><span class="label">Cerrar</span></button>
      </div>
    </div>
  </div>`;
  const header = `
  <header id="masthead" class="border-b-[0.5px] border-line-strong">
    <div class="max-w-page mx-auto px-4 md:px-6">
      <div class="flex items-center justify-between gap-4 h-16 md:h-20">
        <a href="../direccion-e-pizarra.html" class="logo-lockup logo-lockup--header" aria-label="ChalkGuide Barcelona, inicio">${LOGO('h-[22px] md:h-7')}<span class="label-mini logo-tag" aria-hidden="true">Barcelona</span></a>
        <nav aria-label="Navegación principal" class="hidden md:block">${navList('dd-guias')}</nav>
        <div class="flex items-center gap-2">
          <nav aria-label="Idioma" class="hidden sm:flex font-mono text-sm"><a href="#" aria-current="true" aria-label="Español" class="px-2.5 min-h-[44px] inline-flex items-center rounded-sm bg-elevated">ES</a><a href="#" lang="en" aria-label="Cambiar a inglés" class="px-2.5 min-h-[44px] inline-flex items-center text-meta hover:text-foreground transition-colors">EN</a></nav>
          <button type="button" data-menu-toggle class="btn btn-ghost md:hidden" aria-controls="menu" aria-expanded="false"><span class="label">Menú</span></button>
        </div>
      </div>
    </div>
  </header>`;
  const footer = `
  <footer class="border-t-[0.5px] border-line-strong">
    <div class="max-w-page mx-auto px-4 md:px-6 py-12 grid grid-cols-2 md:grid-cols-5 gap-8 text-[15px]">
      <div class="col-span-2">
        <p class="logo-lockup" style="--logo-h:24px">${LOGO('h-6', 'ChalkGuide')}<span class="label-mini logo-tag" aria-hidden="true">Barcelona</span></p>
        <p class="text-meta mt-3 max-w-[36ch]">Escalar en Barcelona, con datos y voz de autor. Hermano de <a href="#" class="link">Chalk app</a>.</p>
      </div>
      <nav aria-label="Guías"><p class="label-mini">Guías</p><ul class="mt-2">${guias.map(g => `<li><a href="${g[1]}" class="navlink">${g[2]}</a></li>`).join('')}</ul></nav>
      <nav aria-label="Medio"><p class="label-mini">Medio</p><ul class="mt-2"><li><a href="blog.html" class="navlink">Blog</a></li><li><a href="agenda.html" class="navlink">Agenda</a></li><li><a href="../direccion-e-pizarra.html#newsletter" class="navlink">Newsletter</a></li><li><a href="sobre-mi.html" class="navlink">Sobre mí</a></li></ul></nav>
      <nav aria-label="Cuentas claras"><p class="label-mini">Cuentas claras</p><ul class="mt-2"><li><a href="#" class="navlink">Transparencia</a></li><li><a href="#" class="navlink">Privacidad</a></li><li><a href="#" class="navlink">Cookies</a></li><li><a href="#" class="navlink">Aviso legal</a></li><li><a href="#" lang="en" class="navlink">English</a></li></ul></nav>
    </div>
    <p class="max-w-page mx-auto px-4 md:px-6 pb-8 label-mini !tracking-[.08em]">© 2026 ChalkGuide · Ninguna reseña se compra · Lo pagado se marca</p>
  </footer>
  <div class="toasts" id="toast-region"></div>`;

  const skip = '<a href="#main" class="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2 focus:z-[80] bg-accent text-on-accent px-3 py-2 rounded-md">Saltar al contenido</a>';
  body.insertAdjacentHTML('afterbegin', skip + sprite + mock + sticky + sheet + (body.dataset.noHeader ? '' : header));
  if (!body.dataset.noFooter) body.insertAdjacentHTML('beforeend', footer);
  else body.insertAdjacentHTML('beforeend', '<div class="toasts" id="toast-region"></div>');
  window.CG_BARS = BARS;
})();
