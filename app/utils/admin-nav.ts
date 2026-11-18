import type { Component } from 'vue'
import {
  Bot,
  CalendarDays,
  ChartLine,
  File,
  FileText,
  FolderTree,
  Footprints,
  History,
  Image,
  LayoutDashboard,
  ListChecks,
  Mail,
  MessageSquare,
  Mountain,
  Newspaper,
  Settings,
  UsersRound,
  Wrench,
} from 'lucide-vue-next'

export interface AdminNavItem {
  /** Path segment after /administrador ('' = Inicio). */
  slug: string
  label: string
  icon: Component
}

export interface AdminNavGroup {
  label: string | null
  items: AdminNavItem[]
}

/** Menu groups and destinations (docs/design/admin/arquitectura.html). */
export const ADMIN_NAV: AdminNavGroup[] = [
  { label: null, items: [{ slug: '', label: 'Inicio', icon: LayoutDashboard }] },
  {
    label: 'Editorial',
    items: [
      { slug: 'articulos', label: 'Artículos', icon: FileText },
      { slug: 'noticias', label: 'Noticias', icon: Newspaper },
      { slug: 'categorias', label: 'Categorías', icon: FolderTree },
      { slug: 'autores', label: 'Autores', icon: UsersRound },
      { slug: 'paginas', label: 'Páginas', icon: File },
    ],
  },
  {
    label: 'Guías',
    items: [
      { slug: 'rocodromos', label: 'Rocódromos', icon: Mountain },
      { slug: 'resoladores', label: 'Resoladores', icon: Wrench },
      { slug: 'pies-de-gato', label: 'Pies de gato', icon: Footprints },
      { slug: 'criterios', label: 'Criterios de nota', icon: ListChecks },
    ],
  },
  {
    label: 'Comunidad',
    items: [
      { slug: 'opiniones', label: 'Opiniones', icon: MessageSquare },
      { slug: 'agenda', label: 'Agenda', icon: CalendarDays },
      { slug: 'suscriptores', label: 'Suscriptores', icon: Mail },
    ],
  },
  { label: 'Biblioteca', items: [{ slug: 'medios', label: 'Medios', icon: Image }] },
  {
    label: 'Datos',
    items: [
      { slug: 'estadisticas', label: 'Estadísticas', icon: ChartLine },
      { slug: 'actividad', label: 'Actividad', icon: History },
      { slug: 'ingesta', label: 'Ingesta', icon: Bot },
    ],
  },
]

export const ADMIN_SETTINGS: AdminNavItem = { slug: 'ajustes', label: 'Ajustes', icon: Settings }

/** Label for a known destination (placeholder pages); undefined = not a panel page (404). */
export function adminLabelFor(slug: string): string | undefined {
  return [...ADMIN_NAV.flatMap((g) => g.items), ADMIN_SETTINGS].find((i) => i.slug === slug)?.label
}
