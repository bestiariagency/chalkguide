/* ChalkGuide · D66: diálogo «Más información» común (texto de docs/copy/consentimiento-comunicaciones-afines.md §2)
   y la casilla/encabezado comunes. Solo mockup. */
const RELATED_TEXT_V1 = 'Quiero que me avisen por email de novedades de Chalk app y de otros productos de ChalkGuide relacionados con la escalada. Puedo retirar mi consentimiento cuando quiera.';
const NEWSLETTER_TEXT = 'Quiero recibir novedades de ChalkGuide por email. Puedo darme de baja cuando quiera.';
const ICO = {
  err:`<svg width="16" height="16" class="shrink-0 mt-0.5" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M12 8v4M12 16h.01"/></svg>`,
  info:`<svg width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4M12 8h.01"/></svg>`,
  arrow:`<svg class="arr" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>`,
  x:`<svg width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"/></svg>`,
  dot:`<svg viewBox="0 0 14 14" aria-hidden="true"><circle cx="7" cy="7" r="4" fill="currentColor"/></svg>`,
  clock:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>`,
  minus:`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 12h8"/></svg>`,
  check:`<svg class="success-check" width="56" height="56" viewBox="0 0 56 56" aria-hidden="true"><circle cx="28" cy="28" r="24" fill="none" stroke="#1a6e4e" stroke-width="2.5"/><path d="M17 29l7 7 15-16" fill="none" stroke="#1a6e4e" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
};
/* «Más información»: botón (no enlace), fuera del <label> para que pulsarlo nunca marque la casilla. */
const moreBtn = () => `<button type="button" class="more-btn consent-more" data-info aria-haspopup="dialog">${ICO.info}<span>Más información</span></button>`;

document.addEventListener('DOMContentLoaded', () => {
  document.body.insertAdjacentHTML('beforeend', `
  <dialog class="info" id="related-info" aria-labelledby="ri-h">
    <div class="flex items-start gap-3 px-5 md:px-7 pt-5 md:pt-6 pb-3 border-b border-[#dcd5c8]">
      <h2 id="ri-h" class="text-[20px] md:text-[22px] leading-tight font-medium tracking-[-.01em] pt-2">Avisos de Chalk app y productos afines</h2>
      <button type="button" class="ml-auto grid place-items-center size-11 rounded-lg hover:bg-[#ebe6dc] shrink-0" data-close aria-label="Cerrar">${ICO.x}</button>
    </div>
    <div class="info-body overflow-y-auto px-5 md:px-7 py-5">
      <section><h3>Qué recibirás</h3><p>Emails ocasionales, aparte de la newsletter mensual, con avisos sobre Chalk app (la aplicación para encontrar compañeros de escalada, que comparte cuentas y base de datos con ChalkGuide) y sobre productos de ChalkGuide relacionados con la escalada, cuando existan. ChalkGuide y Chalk app forman parte de Bestiari, de Xavier Pilasi. No es publicidad de terceros.</p></section>
      <section><h3>Quién te escribe</h3><p>Yo, Xavier Pilasi, responsable de ChalkGuide y de Chalk app. No cedo tu email a terceros para que te escriban. Para enviarlos uso Brevo como proveedor de envío.</p></section>
      <section><h3>Es opcional</h3><p>Si no marcas la casilla, te suscribes igualmente a la newsletter. Entrar con Google tampoco te apunta a estos avisos.</p></section>
      <section><h3>Cómo retirarte</h3><p>Con un clic en el enlace de baja de cualquier email, o desde tus preferencias. Retirarte de esto no te da de baja de la newsletter, y al revés.</p></section>
      <section><h3>Cuánto tiempo lo guardo</h3><p>Tu email, mientras no retires el consentimiento. Después guardo solo la prueba de que lo diste y lo retiraste durante 3 años desde la retirada o, si sigues suscrito a la newsletter, mientras dure la suscripción y 3 años más.</p></section>
      <section><h3>Base legal</h3><p>Tu consentimiento (art. 6.1.a RGPD). Más detalle en la <a href="#" class="link text-[#9a4a16]">política de privacidad</a>.</p></section>
    </div>
    <div class="px-5 md:px-7 py-4 border-t border-[#dcd5c8] flex"><button type="button" class="btn btn-ghost w-full sm:w-auto sm:ml-auto" data-close>Cerrar</button></div>
  </dialog>`);
  const dlg = document.getElementById('related-info'); let opener = null;
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-info]');
    if (b) { opener = b; dlg.showModal(); dlg.querySelector('[data-close]').focus(); return; }
    if (e.target.closest('#related-info [data-close]') || e.target === dlg) dlg.close();
  });
  dlg.addEventListener('close', () => opener && opener.focus());
});
