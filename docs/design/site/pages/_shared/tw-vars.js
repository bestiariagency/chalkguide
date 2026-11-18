/* ChalkGuide · Tailwind para los mockups 3.18/3.19.
   Igual que tw.js, pero los colores apuntan a variables CSS: así un bloque `.paper` (opción B) o el tema
   claro (opción C) redefinen los tokens por ámbito y todos los componentes cambian solos.
   Sin modificadores de opacidad (`bg-elevated/60`): con variables hex no funcionan. */
tailwind.config = {
  theme: {
    extend: {
      colors: {
        background: 'var(--background)', board: 'var(--board)', elevated: 'var(--elevated)',
        line: 'var(--line)', 'line-strong': 'var(--line-strong)', control: 'var(--control)',
        accent: 'var(--accent)', 'accent-fill': 'var(--accent-fill)', 'accent-hover': 'var(--accent-hover)',
        'accent-muted': 'var(--accent-muted)', 'on-accent': 'var(--on-accent)',
        foreground: 'var(--foreground)', prose: 'var(--prose)', meta: 'var(--meta)', muted: 'var(--muted)', hint: 'var(--hint)',
        success: 'var(--success)', 'success-text': 'var(--success-text)', 'success-muted': 'var(--success-muted)',
        danger: 'var(--danger)', 'danger-text': 'var(--danger-text)', 'danger-muted': 'var(--danger-muted)',
        chalk: 'var(--chalk)'
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'monospace'],
        hand: ['Caveat', 'cursive']
      },
      borderRadius: { sm: '4px', md: '8px', lg: '12px', xl: '16px' },
      maxWidth: { page: '1200px', read: '680px', sheet: '840px' }
    }
  }
}
