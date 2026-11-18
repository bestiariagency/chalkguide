import type { SafeHtml } from '~~/shared/lib/sanitize/safe-html'
import type { ItemExtras } from '~/types/item-detail'

export interface ResolerDetail<H extends string = SafeHtml> extends ItemExtras<H> {
  address: string | null
  city: string
  postalCode: string | null
  websiteUrl: string | null
}
