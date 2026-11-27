/* ChalkGuide · Panel · shell y comportamientos comunes de los mockups (F5.5).
   No es código de producción: reproduce el layout `admin` y los patrones
   (menú, barra inferior, Nuevo, modales/hojas, toasts, pestañas, selección, arrastrar). */

tailwind.config = { theme: { extend: {
  fontFamily: { sans: ['Inter','ui-sans-serif','system-ui','sans-serif'], mono: ['JetBrains Mono','ui-monospace','monospace'] },
  colors: {
    bg:'var(--bg)', side:'var(--side)', subtle:'var(--subtle)', elev:'var(--elev)',
    line:'var(--line)', 'line-strong':'var(--line-strong)', control:'var(--control)',
    fg:'var(--fg)', meta:'var(--meta)', muted:'var(--muted)',
    acc:'var(--acc)', 'acc-soft':'var(--acc-soft)', primary:'var(--primary)', 'on-primary':'var(--on-primary)',
    'st-draft':'var(--st-draft)', 'st-sched':'var(--st-sched)', 'st-pub':'var(--st-pub)', 'st-rev':'var(--st-rev)', 'st-rev-bg':'var(--st-rev-bg)',
    danger:'var(--danger)', 'danger-soft':'var(--danger-soft)', warn:'var(--warn)', 'warn-soft':'var(--warn-soft)', 'warn-icon':'var(--warn-icon)', ok:'var(--ok)', 'ok-soft':'var(--ok-soft)'
  },
  fontSize: { '2xs':['11px','16px'], xs:['12px','16px'], sm:['13px','20px'], base:['14px','22px'], lg:['16px','24px'], xl:['20px','28px'], '2xl':['24px','32px'], '3xl':['30px','36px'] },
  screens: { sm:'640px', md:'768px', lg:'1024px', xl:'1280px', '2xl':'1440px' }
}}};

(function(){
const PAGES = [
  ['login','login.html','Login'],['inicio','inicio.html','Inicio'],['articulos','articulos.html','Artículos'],
  ['editor','articulo-editor.html','Editor'],['categorias','categorias.html','Categorías'],['paginas','paginas.html','Páginas'],['medios','medios.html','Medios'],
  ['rocodromo','rocodromo-editor.html','Rocódromo'],['pie','pie-de-gato-editor.html','Pie de gato'],['resolador','resolador-editor.html','Resolador'],['criterios','criterios.html','Criterios'],
  ['opiniones','opiniones.html','Opiniones'],['agenda','agenda.html','Agenda'],['agenda-f8','agenda-f8.html','Agenda · F8'],['noticias','noticias.html','Noticias'],['noticias-videos','noticias-videos.html','Noticias · vídeos'],['newsletter','newsletter.html','Newsletter'],['bienvenida','email-bienvenida.html','Bienvenida'],['ingesta','ingesta.html','Ingesta'],['suscriptores','suscriptores.html','Suscriptores'],['exportar','exportar.html','Exportar (modal)'],['importar','importar.html','Importar fichas'],
  ['estadisticas','estadisticas.html','Estadísticas'],['actividad','actividad.html','Actividad'],['ajustes','ajustes.html','Ajustes'],['ds','design-system.html','Design system']
];
const NAV = [
  [null,[['inicio','inicio.html','layout-dashboard','Inicio']]],
  ['Editorial',[['articulos','articulos.html','file-text','Artículos'],['noticias','noticias.html','newspaper','Noticias','14','por revisar'],['categorias','categorias.html','folder-tree','Categorías'],['paginas','paginas.html','file','Páginas']]],
  ['Guías',[['rocodromo','rocodromo-editor.html','mountain','Rocódromos'],['resolador','resolador-editor.html','wrench','Resoladores'],['pie','pie-de-gato-editor.html','footprints','Pies de gato'],['criterios','criterios.html','list-checks','Criterios de nota']]],
  ['Comunidad',[['opiniones','opiniones.html','message-square','Opiniones','7','nuevas'],['agenda','agenda.html','calendar-days','Agenda','5','por aprobar'],['suscriptores','suscriptores.html','mail','Suscriptores'],['newsletter','newsletter.html','send','Newsletter']]],
  ['Biblioteca',[['medios','medios.html','image','Medios']]],
  ['Datos',[['estadisticas','estadisticas.html','chart-line','Estadísticas'],['actividad','actividad.html','history','Actividad'],['ingesta','ingesta.html','bot','Ingesta']]], /* D37: Exportar sale del menú (modal en cada módulo) */
];
const ACTIVE_ALIAS = { editor:'articulos', 'agenda-f8':'agenda', 'noticias-videos':'noticias', bienvenida:'newsletter' };
let page='', active='';
const logoSrc = '../../../public/brand/logo-dark.svg';
const iso = '<svg viewBox="0 22 315 338" class="w-5 h-5" fill="currentColor" aria-hidden="true"><rect x="0" y="22" width="69" height="338" rx="6"/><rect x="82" y="102" width="69" height="258" rx="6"/><rect x="164" y="182" width="69" height="178" rx="6"/><rect x="246" y="262" width="69" height="98" rx="6"/></svg>';

function mockbar(){
  const links = PAGES.map(([k,h,l])=>`<a href="${h}" class="px-2 py-1 rounded hover:bg-white/10 whitespace-nowrap" ${k===page?'aria-current="page"':''}>${l}</a>`).join('');
  return `<div class="mockbar bg-[#27272A] text-[#F4F4F5] text-xs"><div class="px-3 md:px-4 py-1.5 flex items-center gap-3">
    <a href="index.html" class="underline underline-offset-2 opacity-80 hover:opacity-100 whitespace-nowrap">← Índice</a>
    <span class="font-mono uppercase tracking-[.14em] text-[10px] opacity-70 hidden lg:inline whitespace-nowrap">Mockup 5.5 · A Consola</span>
    <nav aria-label="Pantallas del mockup" class="flex gap-0.5 overflow-x-auto min-w-0">${links}</nav></div></div>`;
}
function navItem([k,h,ic,label,count,countLabel]){
  const cur = k===active ? ' aria-current="page"' : '';
  const c = count ? `<span class="count ml-auto md:absolute md:top-0.5 md:right-0.5 md:!px-1 xl:static xl:!px-[5px]"><span class="sr-only">, </span>${count}<span class="sr-only"> ${countLabel}</span></span>` : '';
  return `<a href="${h}" class="navi t md:justify-center xl:justify-start" title="${label}"${cur}><i data-lucide="${ic}"></i><span class="md:sr-only xl:not-sr-only">${label}</span>${c}</a>`;
}
function sidebar(){
  const groups = NAV.map(([g,items])=>(g?`<p class="mt-4 mb-1 px-2.5 grp-label md:hidden xl:block">${g}</p><hr class="hidden md:block xl:hidden my-2 border-line">`:'')+items.map(navItem).join('')).join('');
  return `<div id="scrim" class="fixed inset-0 bg-black/40 z-40 hidden" aria-hidden="true"></div>
  <aside id="sidebar" aria-label="Menú del panel" class="fixed md:sticky top-0 z-50 h-[100dvh] md:h-screen w-[280px] md:w-14 xl:w-60 -translate-x-full md:translate-x-0 t bg-side border-r border-line flex flex-col flex-none">
    <div class="h-12 px-3 xl:px-4 flex items-center gap-2 border-b border-line flex-none">
      <img src="${logoSrc}" alt="ChalkGuide" class="h-[15px] md:hidden xl:block"><span class="hidden md:block xl:hidden mx-auto text-fg" aria-label="ChalkGuide">${iso}</span>
      <span class="grp-label ml-auto md:hidden xl:inline">Admin</span>
      <button id="closeNav" type="button" class="icon-btn md:hidden" aria-label="Cerrar menú"><i data-lucide="x"></i></button>
    </div>
    <div class="p-2 xl:p-3 space-y-2 flex-none">
      <button type="button" data-open="cmdk" class="w-full t flex items-center gap-2 h-8 md:justify-center xl:justify-start px-2.5 rounded-md border border-line-strong bg-elev text-sm text-muted hover:text-fg" aria-label="Buscar o ir a… (⌘K)"><i data-lucide="search" class="w-4 h-4"></i><span class="md:hidden xl:inline">Buscar o ir a…</span><span class="kbd ml-auto md:hidden xl:inline">⌘K</span></button>
      <button type="button" data-open="nuevo" class="w-full btn btn-primary t md:px-0 xl:justify-start xl:px-3" aria-haspopup="dialog" aria-label="Nuevo (C)"><i data-lucide="plus"></i><span class="md:hidden xl:inline">Nuevo</span><span class="kbd ml-auto !bg-transparent !border-white/30 !text-white/70 md:hidden xl:inline">C</span></button>
    </div>
    <nav class="flex-1 overflow-y-auto px-2 xl:px-3 pb-3" aria-label="Secciones">${groups}</nav>
    <div class="border-t border-line p-2 xl:p-3 space-y-0.5 flex-none">
      ${navItem(['ajustes','ajustes.html','settings','Ajustes'])}
      <a href="#" class="navi t md:justify-center xl:justify-start" title="Ver sitio (se abre en otra pestaña)"><i data-lucide="external-link"></i><span class="md:sr-only xl:not-sr-only">Ver sitio</span></a>
      <div class="flex items-center gap-2 px-1.5 h-10 md:justify-center xl:justify-start">
        <span class="w-6 h-6 rounded-full bg-primary text-on-primary grid place-items-center text-[11px] font-medium flex-none" aria-hidden="true">X</span>
        <span class="md:hidden xl:block leading-4"><span class="block text-sm text-fg">Xavi</span><span class="block text-2xs text-muted">Superadmin</span></span>
        <a href="login.html" class="icon-btn ml-auto md:hidden xl:inline-grid" aria-label="Cerrar sesión"><i data-lucide="log-out"></i></a>
      </div>
    </div>
  </aside>`;
}
function mobileTop(){
  return `<div class="md:hidden h-14 px-1 flex items-center gap-1 border-b border-line bg-bg sticky top-0 z-30">
    <button id="openNav" type="button" class="icon-btn" aria-label="Abrir menú" aria-controls="sidebar" aria-expanded="false"><i data-lucide="menu" class="!w-5 !h-5"></i></button>
    <img src="${logoSrc}" alt="ChalkGuide" class="h-[14px]">
    <button type="button" data-open="cmdk" class="icon-btn ml-auto" aria-label="Buscar o ir a…"><i data-lucide="search" class="!w-5 !h-5"></i></button>
  </div>`;
}
function bottomNav(){
  const it=(k,h,ic,l,c)=>`<a href="${h}" class="flex flex-col items-center justify-center gap-1 relative ${k===active?'text-fg font-medium':'text-meta'}" ${k===active?'aria-current="page"':''}><i data-lucide="${ic}" class="w-5 h-5 ${k===active?'text-acc':''}"></i>${l}${c?`<span class="absolute top-1.5 left-1/2 ml-1.5 count !bg-acc !text-white !text-[10px] !leading-4"><span class="sr-only">, </span>${c}<span class="sr-only"> nuevas</span></span>`:''}</a>`;
  return `<nav aria-label="Accesos rápidos" class="md:hidden fixed bottom-0 inset-x-0 z-30 h-16 pb-[env(safe-area-inset-bottom)] bg-bg border-t border-line grid grid-cols-4 text-2xs">
    ${it('inicio','inicio.html','layout-dashboard','Inicio')}${it('opiniones','opiniones.html','message-square','Opiniones','7')}${it('medios','medios.html','image','Medios')}
    <button type="button" data-open="nuevo" class="flex flex-col items-center justify-center gap-1 text-meta" aria-haspopup="dialog"><span class="w-7 h-7 -my-0.5 rounded-lg bg-primary text-on-primary grid place-items-center"><i data-lucide="plus" class="w-4 h-4"></i></span>Nuevo</button>
  </nav>`;
}
function globals(){
  const n=(ic,l,h,d,k)=>`<a href="${h}" class="menu-i !h-auto py-2 items-start"><i data-lucide="${ic}" class="mt-0.5"></i><span class="flex-1"><span class="block font-medium">${l}</span><span class="block text-xs text-meta">${d}</span></span>${k?`<span class="kbd hidden md:inline">${k}</span>`:''}</a>`;
  return `
  <div id="nuevo" class="overlay" role="dialog" aria-modal="true" aria-labelledby="nuevo-h">
    <div class="dialog !max-w-[400px]"><div class="grab"></div>
      <div class="dialog-h flex items-center"><h2 id="nuevo-h">Crear</h2><button type="button" class="icon-btn ml-auto -mr-2" data-close aria-label="Cerrar"><i data-lucide="x"></i></button></div>
      <div class="p-2 pb-3">
        ${n('file-text','Artículo','articulo-editor.html','Borrador nuevo en el blog','A')}
        ${n('mountain','Rocódromo','rocodromo-editor.html','Ficha con reseña y notas','R')}
        ${n('wrench','Resolador','resolador-editor.html','Taller, servicios y plazos','')}
        ${n('footprints','Pie de gato','pie-de-gato-editor.html','Ficha técnica y precio','')}
        ${n('calendar-plus','Evento','agenda.html#nuevo','Para la agenda','E')}
        <div class="menu-sep !mx-0"></div>
        ${n('upload','Subir fotos','medios.html#subir','A la biblioteca de medios','U')}
      </div>
    </div>
  </div>
  <div id="cmdk" class="overlay !items-start md:!pt-[12vh]" role="dialog" aria-modal="true" aria-label="Buscar o ir a">
    <div class="dialog !max-w-[560px]"><div class="grab"></div>
      <div class="flex items-center gap-2 px-4 h-12 border-b border-line"><i data-lucide="search" class="w-4 h-4 text-muted"></i><label for="cmdk-q" class="sr-only">Buscar</label><input id="cmdk-q" class="flex-1 bg-transparent outline-none text-[15px]" placeholder="Busca artículos, fichas, fotos o ve a una sección…" value="parets"><span class="kbd">esc</span></div>
      <div class="p-2 text-sm max-h-[50vh] overflow-auto" role="listbox" aria-label="Resultados">
        <p class="grp-label px-2 pt-2 pb-1">Fichas</p>
        <a href="rocodromo-editor.html" role="option" aria-selected="true" class="menu-i" data-active><i data-lucide="mountain"></i>La <mark class="bg-acc-soft text-fg rounded px-0.5">Paret</mark> de Gràcia<span class="ml-auto text-xs text-meta">Rocódromo</span></a>
        <p class="grp-label px-2 pt-3 pb-1">Artículos</p>
        <a href="articulo-editor.html" role="option" class="menu-i"><i data-lucide="file-text"></i>Rocódromos con <mark class="bg-acc-soft text-fg rounded px-0.5">paredes</mark> altas para cuerda<span class="ml-auto text-xs text-meta">Borrador</span></a>
        <p class="grp-label px-2 pt-3 pb-1">Ir a</p>
        <a href="medios.html" role="option" class="menu-i"><i data-lucide="image"></i>Medios<span class="kbd ml-auto">G M</span></a>
      </div>
    </div>
  </div>
  <div class="toasts" id="toasts" aria-live="polite" aria-atomic="false"></div>
  <div class="sr-only" id="announcer" aria-live="assertive"></div>`;
}

/* ---------- API pública ---------- */
const CG = window.CG = {};
CG.toast = function(msg,opts={}){
  const t=opts.type||'ok';const el=document.createElement('div');
  el.className='toast toast-'+t; if(t==='err') el.setAttribute('role','alert');
  const ic = t==='err'?'circle-alert':t==='info'?'info':'check';
  el.innerHTML=`<i data-lucide="${ic}" class="ic"></i><span class="flex-1">${msg}</span>`+
    (opts.action?`<button type="button" class="ta font-medium ${t==='ok'?'':'underline underline-offset-2'}">${opts.action}</button>`:'')+
    (t==='err'?'<button type="button" class="icon-btn !w-7 !h-7 -mr-1" aria-label="Cerrar aviso"><i data-lucide="x"></i></button>':'');
  document.getElementById('toasts').appendChild(el); lucide.createIcons({attrs:{'stroke-width':1.75}});
  el.querySelectorAll('button').forEach(b=>b.onclick=()=>el.remove());
  if(t!=='err') setTimeout(()=>el.remove(), opts.ms||5000);
};
CG.open = function(id,from){const o=document.getElementById(id);if(!o)return;o._from=from||document.activeElement;o.classList.add('open');document.body.style.overflow='hidden';
  const f=o.querySelector('[autofocus],input:not([type=hidden]),button:not([data-close]),a[href]');setTimeout(()=>f&&f.focus(),30);};
CG.close = function(o){if(typeof o==='string')o=document.getElementById(o);if(!o)return;o.classList.remove('open');document.body.style.overflow='';o._from&&o._from.focus&&o._from.focus();};
CG.announce = m=>{const a=document.getElementById('announcer');a.textContent='';setTimeout(()=>a.textContent=m,30);};
CG.icons = ()=>lucide.createIcons({attrs:{'stroke-width':1.75}});

document.addEventListener('DOMContentLoaded',()=>{
  page = document.body.dataset.page || ''; active = ACTIVE_ALIAS[page] || page;
  const main=document.getElementById('contenido');
  if(document.body.dataset.shell!=='none'){
    const wrap=document.createElement('div');
    wrap.innerHTML = mockbar()+`<div class="flex min-h-screen">${sidebar()}<div id="col" class="flex-1 min-w-0 flex flex-col">${mobileTop()}</div></div>`;
    document.body.prepend(...wrap.childNodes);
    const col=document.getElementById('col'); col.appendChild(main); main.classList.add('flex-1','min-w-0','pb-16','md:pb-0');
    if(document.body.dataset.bottomnav!=='none') col.insertAdjacentHTML('beforeend',bottomNav());
  } else { document.body.insertAdjacentHTML('afterbegin',mockbar()); }
  document.body.insertAdjacentHTML('beforeend',globals());
  CG.icons();

  /* menú móvil */
  const sb=document.getElementById('sidebar'),scrim=document.getElementById('scrim'),ob=document.getElementById('openNav');
  const closeNav=()=>{if(!sb)return;sb.classList.add('-translate-x-full');scrim.classList.add('hidden');ob&&ob.setAttribute('aria-expanded','false');};
  if(ob){ob.onclick=()=>{sb.classList.remove('-translate-x-full');scrim.classList.remove('hidden');ob.setAttribute('aria-expanded','true');sb.querySelector('a,button').focus();};
    document.getElementById('closeNav').onclick=closeNav;scrim.onclick=closeNav;}

  /* overlays */
  document.addEventListener('click',e=>{
    const op=e.target.closest('[data-open]'); if(op){e.preventDefault();CG.open(op.dataset.open,op);return;}
    const cl=e.target.closest('[data-close]'); if(cl){const o=cl.closest('.overlay');CG.close(o);if(cl.dataset.toast)CG.toast(cl.dataset.toast,{action:cl.dataset.action||'Deshacer'});return;}
    if(e.target.classList&&e.target.classList.contains('overlay')) CG.close(e.target);
    const tb=e.target.closest('[data-toast]'); if(tb&&!tb.closest('[data-close]')){CG.toast(tb.dataset.toast,{type:tb.dataset.type||'ok',action:tb.dataset.action===''?null:(tb.dataset.action||'Deshacer')});}
  });
  addEventListener('keydown',e=>{
    if(e.key==='Escape'){const o=[...document.querySelectorAll('.overlay.open')].pop();if(o){CG.close(o);return;}closeNav();}
    if((e.metaKey||e.ctrlKey)&&e.key.toLowerCase()==='k'){e.preventDefault();CG.open('cmdk');}
    const tag=(e.target.tagName||'').toLowerCase();
    if(!e.metaKey&&!e.ctrlKey&&!['input','textarea','select'].includes(tag)&&!e.target.isContentEditable&&e.key==='c'&&!document.querySelector('.overlay.open')){CG.open('nuevo');}
  });
  /* trampa de foco simple en overlays */
  document.addEventListener('keydown',e=>{if(e.key!=='Tab')return;const o=[...document.querySelectorAll('.overlay.open')].pop();if(!o)return;
    const f=[...o.querySelectorAll('a[href],button:not([disabled]),input,select,textarea,[tabindex]:not([tabindex="-1"])')].filter(x=>x.offsetParent!==null);if(!f.length)return;
    if(e.shiftKey&&document.activeElement===f[0]){e.preventDefault();f[f.length-1].focus();}else if(!e.shiftKey&&document.activeElement===f[f.length-1]){e.preventDefault();f[0].focus();}});

  /* pestañas genéricas: [role=tablist][data-tabs] con aria-controls */
  document.querySelectorAll('[role=tablist][data-tabs]').forEach(tl=>{
    const tabs=[...tl.querySelectorAll('[role=tab]')];
    const sel=t=>{tabs.forEach(x=>{const on=x===t;x.setAttribute('aria-selected',on);x.tabIndex=on?0:-1;const p=document.getElementById(x.getAttribute('aria-controls'));p&&(p.hidden=!on);});};
    tabs.forEach((t,i)=>{t.onclick=()=>sel(t);t.onkeydown=e=>{let j=null;if(e.key==='ArrowRight')j=(i+1)%tabs.length;if(e.key==='ArrowLeft')j=(i-1+tabs.length)%tabs.length;if(j!==null){e.preventDefault();tabs[j].focus();sel(tabs[j]);}};});
    const first=tabs.find(t=>t.getAttribute('aria-selected')==='true')||tabs[0];sel(first);const sc=tl.parentElement;if(sc&&sc.scrollWidth>sc.clientWidth){sc.scrollLeft=first.offsetLeft-sc.clientWidth/2+first.offsetWidth/2;}
  });
  /* segmentados con role=radio */
  document.addEventListener('click',e=>{const b=e.target.closest('.seg [role=radio]');if(!b)return;b.parentElement.querySelectorAll('[role=radio]').forEach(x=>x.setAttribute('aria-checked',x===b));b.dispatchEvent(new CustomEvent('seg',{bubbles:true}));});
  document.addEventListener('keydown',e=>{const b=e.target.closest&&e.target.closest('.seg [role=radio]');if(!b||!['ArrowRight','ArrowLeft'].includes(e.key))return;e.preventDefault();
    const r=[...b.parentElement.querySelectorAll('[role=radio]')];let i=r.indexOf(b)+(e.key==='ArrowRight'?1:-1);i=(i+r.length)%r.length;r[i].click();r[i].focus();});
  document.addEventListener('click',e=>{const s=e.target.closest('.switch');if(s){s.setAttribute('aria-checked',s.getAttribute('aria-checked')!=='true');}});

  /* arrastrar para ordenar: ul.sortable > li con .handle (ratón y teclado) */
  document.querySelectorAll('ul.sortable,ol.sortable').forEach(initSortable);
});

function initSortable(list){
  let drag=null;
  const label=li=>li.dataset.label||li.textContent.trim().split('\n')[0];
  const pos=li=>[...list.children].indexOf(li)+1;
  list.addEventListener('dragstart',e=>{const li=e.target.closest('li');if(!li)return;drag=li;li.classList.add('is-dragging');e.dataTransfer.effectAllowed='move';e.dataTransfer.setData('text/plain','');});
  list.addEventListener('dragend',()=>{if(drag)drag.classList.remove('is-dragging');list.querySelectorAll('li').forEach(l=>l.classList.remove('drop-before','drop-after'));if(drag){CG.announce(`${label(drag)}, posición ${pos(drag)} de ${list.children.length}.`);list.dispatchEvent(new Event('sorted'));}drag=null;});
  list.addEventListener('dragover',e=>{if(!drag)return;e.preventDefault();const li=e.target.closest('li');if(!li||li===drag||li.parentElement!==list)return;
    const r=li.getBoundingClientRect();const after=e.clientY>r.top+r.height/2;list.querySelectorAll('li').forEach(l=>l.classList.remove('drop-before','drop-after'));li.classList.add(after?'drop-after':'drop-before');
    after?li.after(drag):li.before(drag);});
  list.querySelectorAll(':scope>li').forEach(li=>{
    const h=li.querySelector('.handle');if(!h)return;
    h.addEventListener('mousedown',()=>li.draggable=true);h.addEventListener('touchstart',()=>li.draggable=true,{passive:true});
    li.addEventListener('mouseup',()=>li.draggable=false);
    h.addEventListener('keydown',e=>{
      const lifted=li.classList.contains('is-lifted');
      if(e.key===' '||e.key==='Enter'){e.preventDefault();
        if(!lifted){li.classList.add('is-lifted');li._start=pos(li);h.setAttribute('aria-pressed','true');CG.announce(`${label(li)} levantado. Posición ${pos(li)} de ${list.children.length}. Usa las flechas para moverlo, Espacio para soltar, Escape para cancelar.`);}
        else{li.classList.remove('is-lifted');h.setAttribute('aria-pressed','false');CG.announce(`${label(li)} soltado en la posición ${pos(li)} de ${list.children.length}.`);list.dispatchEvent(new Event('sorted'));}
      }
      if(lifted&&(e.key==='ArrowDown'||e.key==='ArrowUp')){e.preventDefault();
        if(e.key==='ArrowDown'&&li.nextElementSibling)li.nextElementSibling.after(li);
        if(e.key==='ArrowUp'&&li.previousElementSibling)li.previousElementSibling.before(li);
        h.focus();CG.announce(`Posición ${pos(li)} de ${list.children.length}.`);}
      if(lifted&&e.key==='Escape'){e.preventDefault();e.stopPropagation();const tgt=list.children[li._start-1];if(tgt&&tgt!==li){pos(li)<li._start?tgt.after(li):tgt.before(li);}li.classList.remove('is-lifted');h.setAttribute('aria-pressed','false');h.focus();CG.announce(`Cancelado. ${label(li)} vuelve a la posición ${pos(li)}.`);}
    });
  });
}
CG.initSortable = initSortable;
})();
