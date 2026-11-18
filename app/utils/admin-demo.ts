/** Sample data for the `/administrador/componentes` showcase only. */
export interface DemoArticle {
  id: string
  title: string
  category: string
  status: AdminStatusKind
  changes?: number
  updated: string
}

const CATEGORIES = ['Empezar a escalar', 'Progresión y cuidado', 'Material', 'Costes']
const STATUSES: AdminStatusKind[] = ['published', 'draft', 'scheduled', 'revised', 'hidden']
const TITLES = [
  'Dónde escalar en Barcelona cuando llueve',
  'Pies de gato para pie ancho',
  'Cuánto cuesta escalar en Barcelona',
  'Magnesio líquido o en polvo',
  'Cómo ir solo a un rocódromo',
  'Resolar o comprar nuevos',
  'Qué pedir en recepción la primera vez',
  'Rocódromos tranquilos entre semana',
]

export const DEMO_ARTICLES: DemoArticle[] = Array.from({ length: 64 }, (_, i) => ({
  id: `art-${i + 1}`,
  title: `${TITLES[i % TITLES.length]}${i >= TITLES.length ? ` (${Math.floor(i / TITLES.length) + 1})` : ''}`,
  category: CATEGORIES[i % CATEGORIES.length] as string,
  status: STATUSES[i % STATUSES.length] as AdminStatusKind,
  changes: i % STATUSES.length === 3 ? (i % 4) + 1 : undefined,
  updated: new Date(Date.UTC(2026, 9, 9, 8) - (i * 7 + 1) * 3_600_000 * (i % 5 + 1)).toISOString(),
}))

export const DEMO_COLUMNS: AdminColumn<DemoArticle>[] = [
  { key: 'title', label: 'Título', sortable: true, pin: 'left', minWidth: 'min-w-72' },
  { key: 'status', card: true, label: 'Estado', sortable: true },
  { key: 'category', card: true, label: 'Categoría', sortable: true, minWidth: 'min-w-44' },
  { key: 'updated', card: true, label: 'Actualizado', sortable: true },
  { key: 'actions', label: 'Acciones', hideLabel: true, pin: 'right', searchable: false },
]

export const DEMO_CATEGORIES = CATEGORIES.map((label) => ({ id: label.toLowerCase().replace(/\s+/g, '-'), label }))
