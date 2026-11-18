import type { AdminMedia } from '~/utils/admin-media'
import type { ChangeEntry } from '~/utils/article-changes'
import type { ChecklistItem } from '~/utils/article-form'
import type { AltIssue } from '~/utils/content-alt'
import { formFromRows, sectionsOf, type GymForm } from '~/utils/gym-fields'
import { gymChecklist } from '~/utils/gym-checklist'
import { describeGymChanges, gymChangedIds, validateGym } from '~/utils/gym-patch'
import { GYM_TABS } from '~/utils/gym-tabs'
import type { Columns, ItemForm, Sections } from '~/utils/item-fields'
import type { ItemErrors } from '~/utils/item-patch'
import type { ItemTab } from '~/utils/item-tabs'
import { shoeChecklist } from '~/utils/shoe-checklist'
import { shoeFromRows, shoeSections, type ShoeForm } from '~/utils/shoe-fields'
import { describeShoeChanges, shoeChangedIds, validateShoe } from '~/utils/shoe-patch'
import { SHOE_TABS } from '~/utils/shoe-tabs'
import { resolerChecklist } from '~/utils/resoler-checklist'
import { resolerSections, resolerFromRows, type ResolerForm } from '~/utils/resoler-fields'
import { describeResolerChanges, resolerChangedIds, validateResoler } from '~/utils/resoler-patch'
import { RESOLER_TABS } from '~/utils/resoler-tabs'

export type ItemCategory = 'gym' | 'resoler' | 'shoe'

/** Words and routes of an item category in the panel (the editor and the list are shared). */
export interface ItemInfo {
  category: ItemCategory
  /** Detail table of the category. */
  table: 'gyms' | 'resolers' | 'shoes'
  /** Panel route segment (`/administrador/<route>`). */
  route: string
  /** Public path in Spanish. */
  publicPath: string
  noun: string
  /** Header of the list column that holds the place (district) or, for shoes, the brand. */
  placeLabel: string
  nouns: string
  title: string
  newLabel: string
  slugBase: string
  featuredHelp: string
  /** Title the SEO fields fall back to (ES / EN), for the placeholders. */
  seoTitleEs: (name: string) => string
  seoTitleEn: (name: string) => string
  /** Toast after publishing / deleting. */
  publishedToast: string
  removedToast: string
  removedManyToast: (count: number) => string
}

export interface ItemSpec<F extends ItemForm = ItemForm> extends ItemInfo {
  tabs: readonly ItemTab[]
  fromRows(rows: { item: Columns; detail: Columns; review: Columns | null }, scores: Record<string, number>, gallery: string[]): F
  sectionsOf(form: F, clean: (html: string) => string, skip?: ReadonlySet<string>, fallback?: Sections): Sections
  /** `live`: the item is published (shoes then keep brand and model). */
  validate(form: F, taken: ReadonlySet<string>, live?: boolean): ItemErrors
  checklist(form: F, errors: ItemErrors, mediaOf: (id: string | null) => AdminMedia | null, alt: AltIssue[], altEn: { required: AltIssue[]; advisory: AltIssue[] }): ChecklistItem[]
  changedIds(current: F, base: F): string[]
  describe(base: F, current: F, criteria: Map<string, string>): ChangeEntry[]
}

export const GYM_INFO: ItemInfo = {
  category: 'gym',
  table: 'gyms',
  route: 'rocodromos',
  publicPath: '/rocodromos',
  noun: 'rocódromo',
  placeLabel: 'Barrio',
  nouns: 'rocódromos',
  title: 'Rocódromos',
  newLabel: 'Nuevo rocódromo',
  slugBase: 'rocodromo',
  featuredHelp: 'Sale arriba en /rocodromos.',
  seoTitleEs: (name) => `${name}: precios, horarios y opinión`,
  seoTitleEn: (name) => `${name}: prices, hours and review`,
  publishedToast: 'Rocódromo publicado',
  removedToast: 'Rocódromo eliminado',
  removedManyToast: (count) => `${count} rocódromos eliminados`,
}

export const RESOLER_INFO: ItemInfo = {
  category: 'resoler',
  table: 'resolers',
  route: 'resoladores',
  publicPath: '/resolar-pies-de-gato',
  noun: 'resolador',
  placeLabel: 'Barrio',
  nouns: 'resoladores',
  title: 'Resoladores',
  newLabel: 'Nuevo resolador',
  slugBase: 'resolador',
  featuredHelp: 'Sale arriba en /resolar-pies-de-gato.',
  seoTitleEs: (name) => `Resolar pies de gato en ${name}: precio y plazo`,
  seoTitleEn: (name) => `Resole climbing shoes at ${name}: price and time`,
  publishedToast: 'Resolador publicado',
  removedToast: 'Resolador eliminado',
  removedManyToast: (count) => `${count} resoladores eliminados`,
}

export const SHOE_INFO: ItemInfo = {
  category: 'shoe',
  table: 'shoes',
  route: 'pies-de-gato',
  publicPath: '/pies-de-gato',
  noun: 'pie de gato',
  placeLabel: 'Marca',
  nouns: 'pies de gato',
  title: 'Pies de gato',
  newLabel: 'Nuevo pie de gato',
  slugBase: 'pie-de-gato',
  featuredHelp: 'Sale destacado como «pie de gato del mes».',
  seoTitleEs: (name) => `${name}: opinión, ficha técnica y precio`,
  seoTitleEn: (name) => `${name}: review, specs and price`,
  publishedToast: 'Pie de gato publicado',
  removedToast: 'Pie de gato eliminado',
  removedManyToast: (count) => `${count} pies de gato eliminados`,
}

export const GYM_SPEC: ItemSpec<GymForm> = {
  ...GYM_INFO,
  tabs: GYM_TABS,
  fromRows: formFromRows,
  sectionsOf,
  validate: validateGym,
  checklist: gymChecklist,
  changedIds: gymChangedIds,
  describe: describeGymChanges,
}

export const RESOLER_SPEC: ItemSpec<ResolerForm> = {
  ...RESOLER_INFO,
  tabs: RESOLER_TABS,
  fromRows: resolerFromRows,
  sectionsOf: resolerSections,
  validate: validateResoler,
  checklist: resolerChecklist,
  changedIds: resolerChangedIds,
  describe: describeResolerChanges,
}

export const SHOE_SPEC: ItemSpec<ShoeForm> = {
  ...SHOE_INFO,
  tabs: SHOE_TABS,
  fromRows: shoeFromRows,
  sectionsOf: shoeSections,
  validate: validateShoe,
  checklist: shoeChecklist,
  changedIds: shoeChangedIds,
  describe: describeShoeChanges,
}
