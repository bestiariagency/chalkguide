/* ChalkGuide · Tailwind de los mockups D66 (newsletter-afines, confirmada-afines, preferencias).
   Mismos tokens que pages/newsletter.html (tema claro, D20 + home v2). */
tailwind.config = { theme: { extend: {
  colors: {
    background:'var(--color-background)', board:'var(--color-board)', elevated:'var(--color-elevated)', tray:'var(--color-tray)',
    line:'var(--color-line)', 'line-strong':'var(--color-line-strong)', control:'var(--color-control)',
    accent:'var(--color-accent)', 'accent-fill':'var(--color-accent-fill)', 'accent-muted':'var(--color-accent-muted)', 'on-accent':'var(--color-on-accent)', chalk:'var(--color-chalk)',
    foreground:'var(--color-foreground)', prose:'var(--color-prose)', meta:'var(--color-meta)', muted:'var(--color-muted)',
    paper:'#f4f1ea', ink:'#1c1a17',
    'success-text':'var(--color-success-text)', 'danger-text':'var(--color-danger-text)',
  },
  fontFamily: { sans:['Inter','system-ui','sans-serif'], mono:['"JetBrains Mono"','ui-monospace','monospace'], hand:['Caveat','cursive'] },
  maxWidth: { page:'1200px', read:'680px', measure:'62ch' },
} } }
