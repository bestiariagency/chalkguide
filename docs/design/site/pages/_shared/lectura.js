/* ChalkGuide · modo de superficie para los mockups 3.18 (se carga en <head>, antes de pintar).
   Por defecto → Opción C elegida por Xavi: tema claro con navegación (cabecera, menú, pie) oscura.
   ?modo=b → Opción B "papel sobre pizarra", solo como referencia. ?tema=oscuro muestra el tema oscuro actual. */
(() => {
  const q = new URLSearchParams(location.search);
  const mode = q.get('modo') === 'b' ? 'b' : 'c';
  const html = document.documentElement;
  html.dataset.mode = mode;
  const mq = matchMedia('(prefers-color-scheme: light)');
  const pref = () => q.get('tema') || 'claro';  // C elegida: claro fijo (sin conmutador en v1)
  const resolve = (p) => p === 'claro' ? 'light' : p === 'oscuro' ? 'dark' : (mq.matches ? 'light' : 'dark');
  const apply = (p) => { html.dataset.theme = mode === 'c' ? resolve(p) : 'dark'; html.dataset.themePref = p; swapLogos(); };
  const swapLogos = () => {};  // la navegación y el pie son siempre oscuros: logo-white
  apply(pref());
  mq.addEventListener('change', () => html.dataset.themePref === 'sistema' && apply('sistema'));

  addEventListener('DOMContentLoaded', () => {
    swapLogos();
    // Iconos extra
    const sprite = document.querySelector('svg[aria-hidden="true"].absolute');
    if (sprite) sprite.insertAdjacentHTML('beforeend', `
      <symbol id="i-sun" viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></symbol>
      <symbol id="i-moon" viewBox="0 0 24 24"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></symbol>
      <symbol id="i-monitor" viewBox="0 0 24 24"><rect width="20" height="14" x="2" y="3" rx="2"/><path d="M8 21h8"/><path d="M12 17v4"/></symbol>
      <symbol id="i-file" viewBox="0 0 24 24"><path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/></symbol>
      <symbol id="i-plus" viewBox="0 0 24 24"><path d="M5 12h14"/><path d="M12 5v14"/></symbol>
      <symbol id="i-swap" viewBox="0 0 24 24"><path d="m16 3 4 4-4 4"/><path d="M20 7H4"/><path d="m8 21-4-4 4-4"/><path d="M4 17h16"/></symbol>
      <symbol id="i-pause" viewBox="0 0 24 24"><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></symbol>
      <symbol id="i-play" viewBox="0 0 24 24"><path d="M6 4l14 8-14 8Z"/></symbol>
      <symbol id="i-ruler" viewBox="0 0 24 24"><path d="M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.41 2.41 0 0 1 0-3.4l2.6-2.6a2.41 2.41 0 0 1 3.4 0Z"/><path d="m14.5 12.5 2-2"/><path d="m11.5 9.5 2-2"/><path d="m8.5 6.5 2-2"/><path d="m17.5 15.5 2-2"/></symbol>
      <symbol id="i-home" viewBox="0 0 24 24"><path d="M3 10.5 12 3l9 7.5"/><path d="M5 9v11h14V9"/></symbol>`);

    // Barra de mockup: cambiar de modo sin perder la página
    const bar = document.querySelector('.mock-bar > div');
    const url = (m, t) => { const u = new URL(location.href); u.searchParams.set('modo', m); t ? u.searchParams.set('tema', t) : u.searchParams.delete('tema'); return u.pathname.split('/').pop() + u.search + u.hash; };
    const cur = (m, t) => (mode === m && (!t || q.get('tema') === t || (!q.get('tema') && t === 'sistema'))) ? ' aria-current="true"' : '';
    if (bar) bar.insertAdjacentHTML('beforeend', `<span class="mode-switch basis-full md:basis-auto">Ver como: <a href="${url('c')}"${mode === 'c' ? ' aria-current="true"' : ''}>C · claro + nav oscura (elegida)</a> · <a href="${url('b')}"${mode === 'b' ? ' aria-current="true"' : ''}>B · papel (referencia)</a> · <a href="../lectura-b-vs-c.html">B vs C</a></span>`);

    // Enlaces entre mockups de esta tarea conservan el modo
    document.querySelectorAll('a[href]').forEach(a => {
      const h = a.getAttribute('href');
      if (/^(lectura|buscador)-[\w-]+\.html/.test(h) && !h.includes('modo=')) a.setAttribute('href', h.replace(/(\.html)(#.*)?$/, `$1${location.search}$2`));
    });

  });
})();
