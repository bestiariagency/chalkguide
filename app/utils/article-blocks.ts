import type { Component } from 'vue'
import type { ChainedCommands } from '@tiptap/core'
import { Heading2, Heading3, ImageIcon, List, ListOrdered, MessageSquareQuote, Mountain, Pilcrow, Quote, Table2, Youtube } from 'lucide-vue-next'

/**
 * Blocks the author can insert or switch to, shared by the "Párrafo ▾" dropdown of the format bar and
 * the `/` menu. `dialog` ones need a picker (image, video, item card) and are opened by the toolbar.
 */
export type BlockKey = 'paragraph' | 'h2' | 'h3' | 'quote' | 'ul' | 'ol' | 'image' | 'table' | 'note' | 'video' | 'item'
export type DialogBlockKey = 'image' | 'video' | 'item'

export interface BlockDef {
  key: BlockKey
  label: string
  hint: string
  icon: Component
  /** Extra words the `/` filter matches (lower case, no accents). */
  keywords: string[]
  dialog?: boolean
}

export const BLOCKS: readonly BlockDef[] = [
  { key: 'paragraph', label: 'Párrafo', hint: 'Texto normal', icon: Pilcrow, keywords: ['parrafo', 'texto', 'normal'] },
  { key: 'h2', label: 'Título 2', hint: 'Título de sección (H2)', icon: Heading2, keywords: ['titulo', 'h2', 'seccion', 'encabezado'] },
  { key: 'h3', label: 'Título 3', hint: 'Subtítulo (H3)', icon: Heading3, keywords: ['titulo', 'h3', 'subtitulo', 'encabezado'] },
  { key: 'quote', label: 'Cita', hint: 'Frase destacada', icon: Quote, keywords: ['cita', 'quote', 'blockquote'] },
  { key: 'ul', label: 'Lista con viñetas', hint: 'Elementos sin orden', icon: List, keywords: ['lista', 'vinetas', 'bullets'] },
  { key: 'ol', label: 'Lista numerada', hint: 'Pasos u orden', icon: ListOrdered, keywords: ['lista', 'numerada', 'pasos'] },
  { key: 'image', label: 'Imagen con pie', hint: 'De la biblioteca de medios, con pie y ancho', icon: ImageIcon, keywords: ['imagen', 'foto', 'image', 'pie', 'figura'], dialog: true },
  { key: 'table', label: 'Tabla', hint: 'Hasta 5 columnas y 30 filas', icon: Table2, keywords: ['tabla', 'table', 'precios', 'comparar'] },
  { key: 'note', label: 'Nota del autor', hint: 'Aparte destacado con tu voz', icon: MessageSquareQuote, keywords: ['nota', 'autor', 'aparte', 'note'] },
  { key: 'video', label: 'Vídeo', hint: 'Enlace de YouTube', icon: Youtube, keywords: ['video', 'youtube', 'embed'], dialog: true },
  { key: 'item', label: 'Tarjeta de ficha', hint: 'Rocódromo, resolador o pie de gato', icon: Mountain, keywords: ['ficha', 'tarjeta', 'rocodromo', 'resolador', 'pie', 'gato', 'item'], dialog: true },
]

/** Blocks of the "Párrafo ▾" dropdown: switch the type of the current block. */
export const TURN_INTO: readonly BlockDef[] = BLOCKS.filter((block) => ['paragraph', 'h2', 'h3', 'quote'].includes(block.key))

const fold = (text: string) => text.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase()

/** Blocks whose label or keywords contain the typed text (accents and case ignored). */
export function filterBlocks(query: string, exclude: readonly BlockKey[] = []): BlockDef[] {
  const term = fold(query.trim())
  const pool = BLOCKS.filter((block) => !exclude.includes(block.key))
  if (!term) return pool
  return pool.filter((block) => fold(block.label).includes(term) || block.keywords.some((word) => word.includes(term)))
}

/** Blocks left out of text-only bodies (legal pages): media, cards, tables and notes. */
export const EMBED_BLOCKS: readonly BlockKey[] = ['image', 'table', 'note', 'video', 'item']

/** Applies a non-dialog block to the current selection (no `.run()`: the caller closes the chain). */
export function applyBlock(chain: ChainedCommands, key: Exclude<BlockKey, DialogBlockKey>): ChainedCommands {
  switch (key) {
    case 'paragraph':
      return chain.clearNodes()
    case 'h2':
      return chain.toggleHeading({ level: 2 })
    case 'h3':
      return chain.toggleHeading({ level: 3 })
    case 'quote':
      return chain.toggleBlockquote()
    case 'ul':
      return chain.toggleBulletList()
    case 'ol':
      return chain.toggleOrderedList()
    case 'table':
      return chain.insertTable({ rows: 3, cols: 3, withHeaderRow: true })
    case 'note':
      return chain.toggleWrap('authorNote')
  }
}

/** Which "Párrafo ▾" option is current for the given `isActive` lookup (`''` inside lists). */
export function currentBlock(isActive: (name: string, attrs?: Record<string, unknown>) => boolean): { value: string; label: string } {
  if (isActive('heading', { level: 2 })) return { value: 'h2', label: 'Título 2' }
  if (isActive('heading', { level: 3 })) return { value: 'h3', label: 'Título 3' }
  if (isActive('blockquote')) return { value: 'quote', label: 'Cita' }
  if (isActive('bulletList')) return { value: '', label: 'Lista' }
  if (isActive('orderedList')) return { value: '', label: 'Lista numerada' }
  return { value: 'paragraph', label: 'Párrafo' }
}
