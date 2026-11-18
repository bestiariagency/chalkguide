tailwind.config = {
  theme: {
    extend: {
      colors: {
        background: '#0f0f0f', board: '#1a1a1a', elevated: '#242424',
        line: '#2a2a2a', 'line-strong': '#333333', control: '#75716A',
        accent: '#E8923A', 'accent-hover': '#C4721F', 'accent-muted': '#3a2010', 'on-accent': '#1a0a00',
        foreground: '#F0EDE8', meta: '#A19D94', muted: '#888880', hint: '#444440',
        success: '#1D9E75', 'success-text': '#3DBE93', 'success-muted': '#0a2a1e',
        danger: '#E24B4A', 'danger-text': '#F06A68', 'danger-muted': '#2a0a0a'
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'monospace'],
        hand: ['Caveat', 'cursive']
      },
      borderRadius: { sm: '4px', md: '8px', lg: '12px', xl: '16px' },
      maxWidth: { page: '1200px', read: '680px' }
    }
  }
}
