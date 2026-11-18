import type { Component } from 'vue'
import { CalendarDays, FileText, Footprints, ImagePlus, Mountain, Newspaper, Wrench } from 'lucide-vue-next'

export interface AdminCreateItem {
  label: string
  description: string
  icon: Component
  /** Destination (editors arrive in later phases; today they land on the section placeholder). */
  to: string
}

/** Entries of the "Nuevo" sheet (docs/design/admin/README.md §3, bottom bar). */
export const ADMIN_CREATE: AdminCreateItem[] = [
  { label: 'Artículo', description: 'Escribir una pieza del blog', icon: FileText, to: adminPath('articulos/nuevo') },
  { label: 'Rocódromo', description: 'Nueva ficha con reseña', icon: Mountain, to: adminPath('rocodromos/nuevo') },
  { label: 'Resolador', description: 'Nueva ficha de taller', icon: Wrench, to: adminPath('resoladores/nuevo') },
  { label: 'Pie de gato', description: 'Ficha técnica y precio', icon: Footprints, to: adminPath('pies-de-gato/nuevo') },
  { label: 'Noticia', description: 'Escribir una noticia a mano', icon: Newspaper, to: `${adminPath('noticias')}?nuevo=1` },
  { label: 'Evento', description: 'Añadir a la agenda', icon: CalendarDays, to: `${adminPath('agenda')}?nuevo=1` },
  { label: 'Subir imágenes', description: 'A la biblioteca de medios', icon: ImagePlus, to: adminPath('medios') },
]
