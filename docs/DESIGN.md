# DESIGN.md — Chalk design system

> A digital chalkboard. The UI should feel like chalk on a blackboard — tactile, legible, human.
> Dark surfaces. Cream text. One warm accent. Chalk texture as the visual metaphor.

---

## Index

1. [Design philosophy](#1-design-philosophy)
2. [CSS tokens](#2-css-tokens)
3. [Color palette](#3-color-palette)
4. [Typography](#4-typography)
5. [Spacing](#5-spacing)
6. [Border radius](#6-border-radius)
7. [Depth and texture](#7-depth-and-texture)
8. [Buttons](#8-buttons)
9. [Inputs and forms](#9-inputs-and-forms)
10. [Badges](#10-badges)
11. [Board entry card](#11-board-entry-card)
12. [Board view — the main screen](#12-board-view--the-main-screen)
13. [Inbox](#13-inbox)
14. [Navigation — mobile bottom nav](#14-navigation--mobile-bottom-nav)
15. [Modals and bottom sheets](#15-modals-and-bottom-sheets)
16. [Locked state — free users](#16-locked-state--free-users)
17. [Animations and transitions](#17-animations-and-transitions)
18. [Layout and responsive](#18-layout-and-responsive)
19. [Tailwind config](#19-tailwind-config)
20. [Replication checklist](#20-replication-checklist)

---

## 1. Design philosophy

### The chalkboard metaphor
The main screen is a board. Entries are written on it like chalk on a blackboard — clear, legible, informal. Not a feed, not a list of cards, not a table. A board.

The color palette reflects this directly:
- Background: near-black `#0f0f0f` (the blackboard)
- Text: warm off-white `#F0EDE8` (chalk)
- Accent: chalk orange `#E8923A` (the gym's colored chalk, used sparingly)
- Board surface: `#1a1a1a` (the board itself, slightly lighter than the wall behind it)

### Passive and calm
The board doesn't demand attention. No animations fighting for focus. No red badges everywhere. The board just shows who's there — you look at it when you want to.

### Human, not algorithmic
Names on the board are real names (or nicknames). Levels are shown as climbers write them (`6c+`, not "intermediate"). Time slots are plain words (Mañana, Tarde, Noche). Nothing feels like a tech product — it feels like a notice board.

### Mobile first, gym context
This app is used standing up, between sets, in a sweaty gym. Tap targets must be large. Text must be readable at arm's length. No tiny icons, no dense information.

---

## 2. CSS tokens

```css
:root {
  /* === SURFACES === */
  --background: #0f0f0f;     /* the wall behind the board */
  --board: #1a1a1a;          /* the board surface */
  --surface: #1a1a1a;        /* cards, panels */
  --elevated: #242424;       /* modals, inputs, hover */

  /* === ACCENT === */
  --accent: #E8923A;
  --accent-hover: #C4721F;
  --accent-muted: #3a2010;

  /* === TEXT === */
  --foreground: #F0EDE8;     /* chalk white */
  --muted: #888880;          /* secondary text */
  --hint: #444440;           /* placeholder, disabled */

  /* === BORDERS === */
  --border: #2a2a2a;
  --border-strong: #333333;

  /* === SEMANTIC === */
  --success: #1D9E75;
  --success-muted: #0a2a1e;
  --danger: #E24B4A;
  --danger-muted: #2a0a0a;

  /* === RADIUS === */
  --radius-sm: 4px;
  --radius-md: 8px;
  --radius-lg: 12px;
  --radius-xl: 16px;
}
```

---

## 3. Color palette

### Surfaces

| Token | Hex | Usage |
|---|---|---|
| `--background` | `#0f0f0f` | Page background — the wall |
| `--board` | `#1a1a1a` | The board surface — main content area |
| `--elevated` | `#242424` | Inputs, modals, dropdowns |
| `--border` | `#2a2a2a` | Default borders |
| `--border-strong` | `#333333` | Hover, focus borders |

### Accent

| Token | Hex | Usage |
|---|---|---|
| `--accent` | `#E8923A` | Primary CTA, active slots, unread indicators |
| `--accent-hover` | `#C4721F` | Pressed accent |
| `--accent-muted` | `#3a2010` | Accent background tint |

### Text — chalk tones

| Token | Hex | Usage |
|---|---|---|
| `--foreground` | `#F0EDE8` | Names, primary content |
| `--muted` | `#888880` | Labels, metadata, gym names |
| `--hint` | `#444440` | Placeholders, disabled |

### Semantic

| Token | Hex | Usage |
|---|---|---|
| `--success` | `#1D9E75` | Confirmed, available |
| `--danger` | `#E24B4A` | Errors, unavailable |

---

## 4. Typography

**Base size:** 14px. Two weights only: 400 and 500. Never bold or semibold in UI.

```css
h1 { font-size: 20px; font-weight: 500; }  /* page titles */
h2 { font-size: 16px; font-weight: 500; }  /* section headers */
p  { font-size: 14px; font-weight: 400; line-height: 1.6; }
```

### Fonts

| Font | Usage |
|---|---|
| Inter | All UI — headings, body, labels, buttons |
| JetBrains Mono | Climbing levels (`6c+`), time references, technical data only |

### Key patterns

| Class combo | Usage |
|---|---|
| `text-sm font-medium text-[--foreground]` | Names on the board |
| `text-xs font-mono text-[--muted]` | Level badges (`6c+`) |
| `text-xs text-[--muted]` | Gym, date, slot labels |
| `text-xs font-medium text-[--accent]` | Active states, accent labels |
| `text-base font-medium` | Buttons |
| `text-xl font-medium text-[--foreground]` | Page titles |

---

## 5. Spacing

All spacing in multiples of 4px.

```
4px  → p-1, gap-1
8px  → p-2, gap-2
12px → p-3, gap-3
16px → p-4, gap-4
20px → p-5, gap-5
24px → p-6, gap-6
32px → p-8, gap-8
```

### By context

**Pages:** `p-4` mobile · `p-6` desktop · `space-y-6` between sections
**Board entries:** `p-4` internal · `gap-3` between entries
**Forms:** `space-y-4` between fields · `mb-2` label to input · `gap-3` between buttons
**Bottom nav:** `p-2` per button · `pb-[env(safe-area-inset-bottom)]`

---

## 6. Border radius

```
--radius-sm : 4px   → small chips, time slot pills
--radius-md : 8px   → inputs, buttons, board entries
--radius-lg : 12px  → cards, panels
--radius-xl : 16px  → modals, bottom sheets
rounded-t-2xl       → bottom sheet top corners only
rounded-full        → avatars, unread dots
```

Note: board entries use `rounded-md` (8px) to feel hand-written and natural, not perfectly rounded.

---

## 7. Depth and texture

Depth comes from surface layers, not shadows.

```
background (#0f0f0f)  — the wall
  └── board (#1a1a1a) — the board
        └── elevated (#242424) — inputs, modals
```

Borders: always `0.5px solid` — barely visible, like chalk lines.

```css
border: 0.5px solid #2a2a2a;   /* default */
border: 0.5px solid #333333;   /* hover / focus */
border: 0.5px solid #E8923A;   /* selected / active */
```

The board itself can have a very subtle texture suggestion — a faint grid or ruled lines in the background of the board area (`#1f1f1f` at low opacity) to reinforce the chalkboard metaphor without being decorative noise.

---

## 8. Buttons

### Primary

```html
<button class="bg-accent hover:bg-accent-hover active:scale-[0.98]
               text-[#1a0a00] font-medium text-sm
               px-4 py-3 rounded-md w-full min-h-[44px]
               transition-colors duration-200">
  Escribir en la pizarra
</button>
```

### Ghost

```html
<button class="bg-transparent border border-border hover:border-border-strong
               text-muted hover:text-foreground
               font-medium text-sm
               px-4 py-3 rounded-md min-h-[44px]
               transition-colors duration-200">
  Cancelar
</button>
```

### Message (inline, on board entry)

```html
<button class="bg-accent-muted hover:bg-elevated
               text-accent text-xs font-medium
               px-3 py-1.5 rounded-md flex-shrink-0
               transition-colors duration-200">
  Escribir
</button>
```

### Rules
- All interactive elements: `transition-colors duration-200`
- Minimum height: 44px on all tap targets
- Primary: accent fill · dark text `#1a0a00` · no border
- Ghost: transparent · subtle border · muted text that brightens on hover
- `active:scale-[0.98]` on primary for tactile feel

---

## 9. Inputs and forms

### Text input

```html
<input
  type="text"
  class="w-full bg-elevated border border-border rounded-md
         px-3 py-3 text-sm text-foreground
         placeholder:text-hint
         focus:outline-none focus:border-border-strong
         transition-colors duration-200 min-h-[44px]"
/>
```

### Gym selector

```html
<select class="w-full bg-elevated border border-border rounded-md
               px-3 py-3 text-sm text-foreground
               focus:outline-none focus:border-border-strong
               transition-colors duration-200 min-h-[44px]">
  <option value="bloc-district">Bloc District</option>
</select>
```

### Note field (optional, on board entry)

```html
<textarea
  placeholder="Nota opcional — ej: busco alguien para deportiva"
  maxlength="80"
  rows="2"
  class="w-full bg-elevated border border-border rounded-md
         px-3 py-3 text-sm text-foreground
         placeholder:text-hint resize-none
         focus:outline-none focus:border-border-strong
         transition-colors duration-200">
</textarea>
```

### Message compose (inbox)

```html
<textarea
  placeholder="Escribe un mensaje..."
  maxlength="500"
  rows="3"
  class="w-full bg-elevated border border-border rounded-md
         px-3 py-3 text-sm text-foreground
         placeholder:text-hint resize-none
         focus:outline-none focus:border-border-strong
         transition-colors duration-200">
</textarea>
```

---

## 10. Badges

```html
<!-- Slot badge -->
<span class="bg-elevated text-muted text-xs px-2 py-0.5 rounded-sm font-mono">
  Tarde
</span>

<!-- Level badge -->
<span class="bg-elevated text-muted text-xs px-2 py-0.5 rounded-sm font-mono">
  6c+
</span>

<!-- Own entry indicator -->
<span class="bg-accent-muted text-accent text-xs px-2 py-0.5 rounded-sm font-medium">
  Tú
</span>

<!-- Unread message dot -->
<span class="w-2 h-2 rounded-full bg-accent inline-block"></span>
```

---

## 11. Board entry card

The core unit of the entire app. Should feel like a line written on a chalkboard — clear and direct.

```html
<div class="bg-board border border-border rounded-md p-4
            flex items-center gap-3
            hover:border-border-strong transition-colors duration-200">

  <!-- Avatar — initials, like signing your name on the board -->
  <div class="w-9 h-9 rounded-full bg-elevated border border-border
              flex items-center justify-center flex-shrink-0">
    <span class="text-xs font-medium text-accent">CG</span>
  </div>

  <!-- Info -->
  <div class="flex-1 min-w-0 space-y-0.5">
    <p class="text-sm font-medium text-foreground truncate">Carlos G.</p>
    <div class="flex items-center gap-2 flex-wrap">
      <span class="text-xs font-mono text-muted">6c+</span>
      <span class="text-hint text-xs">·</span>
      <span class="text-xs text-muted">Jue 10 abr</span>
      <span class="text-hint text-xs">·</span>
      <span class="text-xs text-muted">Tarde</span>
    </div>
    <!-- Optional note -->
    <p class="text-xs text-hint truncate">Busco alguien para deportiva</p>
  </div>

  <!-- Message CTA — only shown to paid users, not on own entries -->
  <button class="bg-accent-muted hover:bg-elevated text-accent
                 text-xs font-medium px-3 py-1.5 rounded-md flex-shrink-0
                 transition-colors duration-200">
    Escribir
  </button>

</div>
```

### Own entry (no message button, highlighted differently)

```html
<div class="bg-accent-muted border border-accent rounded-md p-4
            flex items-center gap-3">
  <!-- same structure, accent-tinted background -->
  <!-- badge "Tú" instead of message button -->
  <span class="bg-elevated text-muted text-xs px-2 py-0.5 rounded-sm flex-shrink-0">
    Tú
  </span>
</div>
```

---

## 12. Board view — the main screen

The board is the app. Everything else (inbox, profile) is secondary.

### Board header

```html
<div class="flex items-center justify-between mb-4">
  <div>
    <h1 class="text-xl font-medium text-foreground">Bloc District</h1>
    <p class="text-xs text-muted">Semana del 7 — 13 abr</p>
  </div>
  <button class="bg-accent text-[#1a0a00] text-sm font-medium
                 px-3 py-2 rounded-md min-h-[44px]">
    + Apuntarme
  </button>
</div>
```

### Day sections

Entries grouped by day, not by slot. Each day is a simple section with a date label.

```html
<div class="space-y-1 mb-6">
  <p class="text-xs font-medium text-muted uppercase tracking-wider mb-2">
    Jueves 10 abr
  </p>
  <!-- board entries -->
</div>
```

### Empty state

```html
<div class="text-center py-12">
  <p class="text-sm text-muted">Nadie apuntado este día todavía.</p>
  <p class="text-xs text-hint mt-1">Sé el primero en apuntarte.</p>
</div>
```

### Week navigation

Simple prev/next week arrows at the top. No calendar picker — just two weeks visible.

---

## 13. Inbox

### Inbox list

```html
<div class="space-y-1">

  <!-- Conversation row -->
  <div class="flex items-center gap-3 p-3 rounded-md
              hover:bg-elevated transition-colors duration-150 cursor-pointer">

    <div class="w-9 h-9 rounded-full bg-elevated border border-border
                flex items-center justify-center flex-shrink-0 relative">
      <span class="text-xs font-medium text-accent">MR</span>
      <!-- Unread dot -->
      <span class="absolute top-0 right-0 w-2 h-2 rounded-full bg-accent"></span>
    </div>

    <div class="flex-1 min-w-0">
      <div class="flex items-center justify-between">
        <p class="text-sm font-medium text-foreground truncate">Marta R.</p>
        <span class="text-xs text-hint flex-shrink-0 ml-2">Hoy 19:34</span>
      </div>
      <p class="text-xs text-muted truncate">¿El jueves a las 19h te va bien?</p>
    </div>

  </div>

</div>
```

### Message thread

```html
<div class="space-y-3 px-4 py-4">

  <!-- Received message -->
  <div class="flex justify-start">
    <div class="bg-elevated border border-border rounded-md rounded-tl-sm
                px-3 py-2 max-w-[75%]">
      <p class="text-sm text-foreground">Hola, vi que estás disponible el jueves. ¿Quieres escalar?</p>
      <p class="text-xs text-hint mt-1">19:30</p>
    </div>
  </div>

  <!-- Sent message -->
  <div class="flex justify-end">
    <div class="bg-accent-muted border border-accent rounded-md rounded-tr-sm
                px-3 py-2 max-w-[75%]">
      <p class="text-sm text-accent">Sí, perfecto. Mi número es 612 345 678 si quieres coordinar.</p>
      <p class="text-xs text-accent/60 mt-1">19:45</p>
    </div>
  </div>

</div>
```

### Compose bar (bottom of thread)

```html
<div class="border-t border-border p-3 flex gap-2">
  <textarea
    placeholder="Escribe un mensaje..."
    rows="1"
    class="flex-1 bg-elevated border border-border rounded-md
           px-3 py-2.5 text-sm text-foreground
           placeholder:text-hint resize-none
           focus:outline-none focus:border-border-strong
           transition-colors duration-200">
  </textarea>
  <button class="bg-accent text-[#1a0a00] text-sm font-medium
                 px-4 py-2 rounded-md self-end min-h-[44px]
                 transition-colors duration-200">
    Enviar
  </button>
</div>
```

---

## 14. Navigation — mobile bottom nav

```html
<nav class="fixed bottom-0 left-0 right-0
            bg-board border-t border-border
            pb-[env(safe-area-inset-bottom)]">
  <div class="flex items-center justify-around px-2 py-2">

    <!-- Active tab -->
    <button class="flex flex-col items-center gap-1 p-2 min-w-[60px] text-accent">
      <!-- icon 22px -->
      <span class="text-[10px] font-medium">Pizarra</span>
    </button>

    <!-- Inactive tab with unread dot -->
    <button class="flex flex-col items-center gap-1 p-2 min-w-[60px]
                   text-hint hover:text-muted relative transition-colors duration-150">
      <!-- icon 22px -->
      <span class="absolute top-1.5 right-3 w-1.5 h-1.5 rounded-full bg-accent"></span>
      <span class="text-[10px]">Mensajes</span>
    </button>

    <!-- Inactive tab -->
    <button class="flex flex-col items-center gap-1 p-2 min-w-[60px]
                   text-hint hover:text-muted transition-colors duration-150">
      <!-- icon 22px -->
      <span class="text-[10px]">Perfil</span>
    </button>

  </div>
</nav>
```

### Nav items
1. Pizarra (board — home)
2. Mensajes (inbox)
3. Perfil

---

## 15. Modals and bottom sheets

```html
<div style="min-height:400px; background:rgba(0,0,0,0.7);
            display:flex; align-items:flex-end;">
  <div class="w-full bg-board border-t border-border
              rounded-t-2xl p-6 space-y-4">

    <div class="w-12 h-1 bg-border rounded-full mx-auto mb-2"></div>

    <h3 class="text-base font-medium text-foreground">Apuntarme a la pizarra</h3>

    <!-- Form content -->

    <div class="flex gap-3 pt-2">
      <button class="flex-1 bg-transparent border border-border
                     text-muted text-sm font-medium
                     py-3 rounded-md transition-colors duration-200">
        Cancelar
      </button>
      <button class="flex-1 bg-accent text-[#1a0a00]
                     text-sm font-medium
                     py-3 rounded-md transition-colors duration-200">
        Publicar
      </button>
    </div>

  </div>
</div>
```

---

## 16. Locked state — free users

Free users see the board but not who's on it. Use a blur + overlay approach on the entry list.

```html
<!-- Locked entries -->
<div class="relative">

  <!-- Blurred entries (fake/placeholder) -->
  <div class="filter blur-sm pointer-events-none select-none space-y-3">
    <div class="bg-board border border-border rounded-md p-4 h-16"></div>
    <div class="bg-board border border-border rounded-md p-4 h-16"></div>
    <div class="bg-board border border-border rounded-md p-4 h-16"></div>
  </div>

  <!-- Overlay with upgrade prompt -->
  <div class="absolute inset-0 flex flex-col items-center justify-center
              bg-background/80 rounded-md text-center px-6">
    <p class="text-sm font-medium text-foreground mb-1">Hay 3 personas disponibles</p>
    <p class="text-xs text-muted mb-4">Activa tu acceso para ver quién está en la pizarra</p>
    <button class="bg-accent text-[#1a0a00] text-sm font-medium
                   px-6 py-2.5 rounded-md transition-colors duration-200">
      Activar acceso — desde 3 €
    </button>
  </div>

</div>
```

Key detail: show the count ("Hay 3 personas disponibles") but not the names. This creates genuine urgency without being dishonest.

---

## 17. Animations and transitions

### Timing
- 150ms — hover color changes
- 200ms — state transitions (most UI)
- 300ms — bottom sheets, modals

### Vue transitions

```vue
<!-- Fade -->
<style>
.fade-enter-active, .fade-leave-active { transition: opacity 0.2s ease; }
.fade-enter-from, .fade-leave-to       { opacity: 0; }
</style>

<!-- Slide up (bottom sheet) -->
<style>
.slide-up-enter-active { transition: transform 0.3s ease-out; }
.slide-up-leave-active { transition: transform 0.25s ease-in; }
.slide-up-enter-from,
.slide-up-leave-to     { transform: translateY(100%); }
</style>
```

---

## 18. Layout and responsive

### App wrapper

```html
<div class="min-h-screen bg-background">
  <main class="pb-20">
    <div class="p-4 max-w-lg mx-auto">
      <!-- content -->
    </div>
  </main>
  <MobileBottomNav />
</div>
```

### Max widths
- Mobile: full width, `p-4`
- Tablet+: `max-w-lg` (500px) centered
- Desktop: `max-w-xl` (576px) — the board doesn't need to be wide

---

## 19. Tailwind config

```js
export default {
  content: ['./index.html', './src/**/*.{vue,js}'],
  theme: {
    extend: {
      colors: {
        background:       '#0f0f0f',
        board:            '#1a1a1a',
        surface:          '#1a1a1a',
        elevated:         '#242424',
        border:           '#2a2a2a',
        'border-strong':  '#333333',
        accent:           '#E8923A',
        'accent-hover':   '#C4721F',
        'accent-muted':   '#3a2010',
        foreground:       '#F0EDE8',
        muted:            '#888880',
        hint:             '#444440',
        success:          '#1D9E75',
        'success-muted':  '#0a2a1e',
        danger:           '#E24B4A',
        'danger-muted':   '#2a0a0a',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'ui-monospace', 'monospace'],
      },
      borderRadius: {
        sm:    '4px',
        md:    '8px',
        lg:    '12px',
        xl:    '16px',
        '2xl': '20px',
      },
    }
  }
}
```

---

## 20. Replication checklist

Before shipping any screen:

- [ ] Background is `#0f0f0f`, board surface is `#1a1a1a`
- [ ] Text uses `--foreground (#F0EDE8)` — warm white, not pure white
- [ ] Only one accent color on screen — `#E8923A`
- [ ] No `font-bold` or `font-semibold` anywhere
- [ ] All interactive elements have `transition-colors duration-200`
- [ ] All tap targets minimum 44px tall
- [ ] Climbing levels use `font-mono`
- [ ] Board entries feel like lines on a chalkboard — not tech cards
- [ ] Free user locked state shows count but not names
- [ ] Gym selector always first before availability grid
- [ ] Availability grid shows next 2 full weeks only
- [ ] Inbox messages: received left, sent right, accent-tinted
- [ ] Bottom nav has `pb-[env(safe-area-inset-bottom)]`
- [ ] Main content has `pb-20` to clear bottom nav
- [ ] Bottom sheets use `rounded-t-2xl` with drag handle

---

*The board should feel like it belongs in the gym — not in a startup pitch deck.*
