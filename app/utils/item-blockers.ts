/**
 * Single source for the publish-blocker texts (codes of guide.item_publish_blockers, the server is the
 * source of truth). `need` completes "falta …"; `hint` is the checklist sentence for the same blocker.
 */
export const BLOCKER_INFO: Record<string, { need: string; hint?: string }> = {
  name: { need: 'el nombre', hint: 'Falta el nombre, la URL o la ciudad, o alguno no es válido.' },
  slug: { need: 'una URL propia (no «sin-nombre»)' },
  city: { need: 'la ciudad' },
  hours: { need: 'un horario con formato válido' },
  disclosure: { need: 'la nota de transparencia (ES), porque la visita es invitada', hint: 'La visita es invitada: escribe la nota de transparencia (ES).' },
  cover: { need: 'la portada', hint: 'Elige la portada: la usan el listado, la tarjeta y la imagen para compartir.' },
  brand_model: { need: 'la marca y el modelo' },
  alt: { need: 'el texto alternativo de las imágenes' },
}

/** What a blocker code asks for, as a noun phrase. */
export const BLOCKER_TEXT: Record<string, string> = Object.fromEntries(Object.entries(BLOCKER_INFO).map(([code, info]) => [code, info.need]))
