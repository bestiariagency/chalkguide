import type { SafeHtml } from '~~/shared/lib/sanitize/safe-html'
import type { ItemExtras } from '~/types/item-detail'
import type { OpeningHours } from '~/utils/opening-hours'

export interface GymDetail<H extends string = SafeHtml> extends ItemExtras<H> {
  address: string | null
  city: string
  postalCode: string | null
  metroStations: string[]
  openingHours: OpeningHours
  openingHoursNote: string | null
  websiteUrl: string | null
  prices: {
    registration: number | null
    day: number | null
    pass10: number | null
    monthly: number | null
    discounts: string | null
    verifiedAt: string | null
  }
  facilities: {
    surfaceM2: number | null
    maxHeightM: number | null
    routesCount: number | null
    autobelaysCount: number | null
    hasLead: boolean | null
    hasBoulder: boolean | null
    hasTrainingArea: boolean | null
    belayTestRequired: boolean | null
    gearRental: boolean | null
    hasBeginnerCourses: boolean | null
    hasCafe: boolean | null
    servesBeer: boolean | null
    hasKidsArea: boolean | null
    kidsMinAge: number | null
    hasShowers: boolean | null
    hasWifi: boolean | null
  }
}
