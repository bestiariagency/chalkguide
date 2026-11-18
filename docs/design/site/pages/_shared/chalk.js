/* ChalkGuide · comportamiento compartido de los mockups F1.6 (mismo que design-system.html). */
(() => {
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const finePointer = matchMedia('(hover: hover) and (pointer: fine)').matches;
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const vt = (fn) => (!reduce && document.startViewTransition) ? document.startViewTransition(fn) : fn();
  window.CG = { $, $$, vt, reduce };

  /* Barra compacta */
  const bar = $('#stickyBar'), mast = $('#masthead');
  if (bar && mast) new IntersectionObserver(([e]) => {
    const on = !e.isIntersecting;
    bar.classList.toggle('is-on', on); bar.setAttribute('aria-hidden', String(!on)); bar.inert = !on;
    if (!on) $$('[data-dd]', bar).forEach(dd => dd._close && dd._close(false));
  }).observe(mast);

  /* Desplegable Guías */
  $$('[data-dd]').forEach(dd => {
    const btn = $('.dd-btn', dd), links = $$('.dd-panel a', dd); let tO, tC;
    const open = (f) => { dd.classList.add('is-open'); btn.setAttribute('aria-expanded', 'true'); if (f) links[0].focus(); };
    const close = (r) => { dd.classList.remove('is-open'); btn.setAttribute('aria-expanded', 'false'); if (r) btn.focus(); };
    dd._close = close;
    btn.addEventListener('click', () => dd.classList.contains('is-open') ? close(false) : open(false));
    btn.addEventListener('keydown', (e) => { if (e.key === 'ArrowDown') { e.preventDefault(); open(true); } if (e.key === 'Escape') close(true); });
    dd.addEventListener('keydown', (e) => {
      if (e.target === btn) return; const i = links.indexOf(e.target);
      if (e.key === 'Escape') { e.preventDefault(); close(true); }
      if (i < 0) return;
      if (e.key === 'ArrowDown') { e.preventDefault(); links[(i + 1) % links.length].focus(); }
      if (e.key === 'ArrowUp') { e.preventDefault(); i === 0 ? btn.focus() : links[i - 1].focus(); }
      if (e.key === 'Home') { e.preventDefault(); links[0].focus(); }
      if (e.key === 'End') { e.preventDefault(); links[links.length - 1].focus(); }
    });
    dd.addEventListener('focusout', (e) => { if (!dd.contains(e.relatedTarget)) close(false); });
    if (finePointer) { dd.addEventListener('mouseenter', () => { clearTimeout(tC); tO = setTimeout(() => open(false), 120); }); dd.addEventListener('mouseleave', () => { clearTimeout(tO); tC = setTimeout(() => close(false), 300); }); }
  });
  document.addEventListener('click', (e) => $$('[data-dd].is-open').forEach(dd => { if (!dd.contains(e.target)) dd._close(false); }));

  /* Acordeones */
  $$('.acc-btn').forEach(b => b.addEventListener('click', () => { const o = b.getAttribute('aria-expanded') !== 'true'; b.setAttribute('aria-expanded', o); document.getElementById(b.getAttribute('aria-controls')).classList.toggle('is-open', o); }));

  /* Sheets / diálogos: [data-sheet-open="id"], [data-sheet-close] */
  let lastFocus;
  const setSheet = (sheet, open) => {
    sheet.classList.toggle('is-open', open); sheet.setAttribute('aria-hidden', String(!open));
    $$(`[aria-controls="${sheet.id}"]`).forEach(b => b.setAttribute('aria-expanded', open));
    document.documentElement.style.overflow = open ? 'hidden' : '';
    if (open) { lastFocus = document.activeElement; setTimeout(() => { const f = $('[autofocus], button, a, input', $('.panel', sheet)); f && f.focus(); }, 60); }
    else if (lastFocus) lastFocus.focus();
  };
  window.CG.setSheet = setSheet;
  $$('[data-menu-toggle]').forEach(b => b.addEventListener('click', () => setSheet($('#menu'), true)));
  $$('[data-sheet-open]').forEach(b => b.addEventListener('click', () => setSheet(document.getElementById(b.dataset.sheetOpen), true)));
  document.addEventListener('click', (e) => { const c = e.target.closest('[data-menu-close], [data-sheet-close]'); if (c) setSheet(c.closest('.sheet'), false); });
  addEventListener('keydown', (e) => {
    const open = $('.sheet.is-open'); if (!open) return;
    if (e.key === 'Escape') setSheet(open, false);
    if (e.key === 'Tab') { /* foco atrapado */
      const f = $$('a[href], button:not([disabled]), input:not([disabled]), textarea, select', $('.panel', open)).filter(el => el.offsetParent !== null);
      if (!f.length) return; const first = f[0], last = f[f.length - 1];
      if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
      else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  });

  /* Reveal, barras y trazos */
  const io = new IntersectionObserver((ents) => ents.forEach(e => { if (e.isIntersecting) { e.target.classList.add('is-in'); io.unobserve(e.target); } }), { rootMargin: '0px 0px -6% 0px', threshold: .05 });
  window.CG.observe = (root = document) => $$('[data-reveal], .bar, [data-draw]', root).forEach(el => io.observe(el));
  window.CG.observe();

  /* Segmented + tabs */
  const place = (seg) => { const a = seg.querySelector('[aria-selected="true"],[aria-pressed="true"]'), ind = seg.querySelector('.ind'); if (!a || !ind) return; ind.style.width = a.offsetWidth + 'px'; ind.style.transform = `translateX(${a.offsetLeft}px)`; };
  window.CG.place = place;
  const segs = $$('[data-seg]'); segs.forEach(place); addEventListener('resize', () => segs.forEach(place)); document.fonts && document.fonts.ready.then(() => segs.forEach(place));
  $$('[role="tablist"]').forEach(list => {
    const tabs = $$('[role="tab"]', list);
    const select = (t, f) => { tabs.forEach(x => { const on = x === t; x.setAttribute('aria-selected', on); x.tabIndex = on ? 0 : -1; const p = document.getElementById(x.getAttribute('aria-controls')); if (p) { p.hidden = !on; if (on) { p.classList.remove('is-entering'); void p.offsetWidth; p.classList.add('is-entering'); window.CG.observe(p); } } }); place(list); if (f) t.focus(); };
    tabs.forEach((t, i) => { t.addEventListener('click', () => select(t)); t.addEventListener('keydown', (e) => { if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { e.preventDefault(); select(tabs[(i + (e.key === 'ArrowRight' ? 1 : tabs.length - 1)) % tabs.length], true); } }); });
  });

  /* Botón ocupado */
  window.CG.busy = (btn, ms) => new Promise(r => { btn.setAttribute('aria-busy', 'true'); setTimeout(() => { btn.removeAttribute('aria-busy'); r(); }, ms); });

  /* Toasts */
  const icons = { success: ['i-check', 'text-success-text'], error: ['i-alert', 'text-danger-text'], info: ['i-info', 'text-foreground'] };
  window.CG.toast = (type, title, body = '') => {
    const wrap = $('#toast-region'); if (!wrap) return;
    const [ic, col] = icons[type]; const t = document.createElement('div'); t.className = 'toast'; t.setAttribute('role', type === 'error' ? 'alert' : 'status');
    t.innerHTML = `<svg class="ico ${col} mt-0.5" aria-hidden="true"><use href="#${ic}"/></svg><div class="flex-1"><p class="text-[15px]">${title}</p>${body ? `<p class="text-sm text-meta">${body}</p>` : ''}</div><button type="button" class="w-11 h-11 -m-2 grid place-items-center text-meta hover:text-foreground rounded-md" aria-label="Cerrar aviso"><svg class="ico !w-4 !h-4" aria-hidden="true"><use href="#i-x"/></svg></button>`;
    const dismiss = () => { if (reduce) return t.remove(); t.classList.add('is-leaving'); t.addEventListener('animationend', () => t.remove(), { once: true }); };
    $('button', t).addEventListener('click', dismiss); wrap.appendChild(t);
    if (type !== 'error') setTimeout(() => t.isConnected && dismiss(), 5000);
  };

  /* Ordenar listas: [data-sort-group="x"] botones con data-key; [data-sortable="x"] listas con data-* numéricos; data-asc="price,days" */
  $$('[data-sort-group]').forEach(seg => {
    const g = seg.dataset.sortGroup, asc = (seg.dataset.asc || '').split(','), status = document.getElementById(seg.dataset.status || '');
    $$('button', seg).forEach(b => b.addEventListener('click', () => {
      if (b.getAttribute('aria-pressed') === 'true') return;
      const key = b.dataset.key; $$('button', seg).forEach(x => x.setAttribute('aria-pressed', x === b)); place(seg);
      vt(() => $$(`[data-sortable="${g}"]`).forEach(list => [...list.children].sort((a, c) => asc.includes(key) ? a.dataset[key] - c.dataset[key] : c.dataset[key] - a.dataset[key]).forEach(n => list.appendChild(n))));
      if (status) status.textContent = 'Ordenado por ' + b.textContent.trim().toLowerCase();
    }));
  });

  /* Chips toggle genéricos */
  $$('[data-chip]').forEach(c => c.addEventListener('click', () => { c.setAttribute('aria-pressed', c.getAttribute('aria-pressed') !== 'true'); c.dispatchEvent(new CustomEvent('chip-change', { bubbles: true })); }));

  /* Newsletter genérico: form[data-nl] con [data-nl-email], [data-nl-consent], [data-nl-err-email], [data-nl-err-consent], [data-nl-success] */
  $$('form[data-nl]').forEach(form => {
    const email = $('[data-nl-email]', form), consent = $('[data-nl-consent]', form), ok = document.getElementById(form.dataset.nl);
    const showErr = (input, sel, bad) => { input.setAttribute('aria-invalid', bad); const m = $(sel, form); m.classList.toggle('hidden', !bad); m.classList.toggle('flex', bad); };
    form.addEventListener('submit', async (e) => {
      e.preventDefault();
      const bad = !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value.trim());
      showErr(email, '[data-nl-err-email]', bad); showErr(consent, '[data-nl-err-consent]', !consent.checked);
      if (bad) return email.focus(); if (!consent.checked) return consent.focus();
      const btn = $('[type="submit"]', form); if (btn.getAttribute('aria-busy') === 'true') return;
      await window.CG.busy(btn, 1000);
      vt(() => { form.classList.add('hidden'); ok.classList.remove('hidden'); ok.focus(); });
    });
    consent.addEventListener('change', () => consent.checked && showErr(consent, '[data-nl-err-consent]', false));
  });

  /* Lista de espera */
  $$('[data-waitlist]').forEach(b => b.addEventListener('click', async () => {
    if (b.getAttribute('aria-busy') === 'true' || b.disabled) return; await window.CG.busy(b, 900);
    b.disabled = true; $('.label', b).textContent = 'En la lista de espera'; const ok = document.getElementById(b.dataset.waitlist); ok.classList.remove('hidden'); ok.classList.add('flex');
  }));
})();
