import type { Locale } from '~/types/domain'
import type { GymDetail } from '~/types/gym-detail'
import { parseOpeningHours } from '~/utils/opening-hours'
import { getItemExtras } from './item-detail'
import { type GuideClient, pick, unwrapMaybe } from './client'

const GYM_COLUMNS = `address, city, postal_code, metro_stations, opening_hours,
  opening_hours_note_es, opening_hours_note_en, website_url, price_registration_eur,
  price_day_eur, price_10_pass_eur, price_monthly_eur, discounts_es, discounts_en,
  prices_verified_at, surface_m2, max_height_m, has_lead, has_boulder, routes_count,
  autobelays_count, has_training_area, belay_test_required, gear_rental, has_beginner_courses,
  has_cafe, serves_beer, has_kids_area, kids_min_age, has_showers, has_wifi`

const num = (value: number | string | null) => (value === null ? null : Number(value))

/** Everything the gym page needs beyond the summary: 4 independent queries, in parallel. */
export async function getGymDetail(
  db: GuideClient,
  locale: Locale,
  itemId: string,
): Promise<GymDetail<string> | null> {
  const [gym, extras] = await Promise.all([
    db
      .from('gyms')
      .select(GYM_COLUMNS)
      .eq('item_id', itemId)
      .maybeSingle()
      .then(unwrapMaybe),
    getItemExtras(db, locale, itemId),
  ])
  if (!gym) return null
  return {
    address: gym.address,
    city: gym.city,
    postalCode: gym.postal_code,
    metroStations: gym.metro_stations,
    openingHours: parseOpeningHours(gym.opening_hours),
    openingHoursNote: pick(locale, gym.opening_hours_note_es, gym.opening_hours_note_en),
    websiteUrl: gym.website_url,
    prices: {
      registration: num(gym.price_registration_eur),
      day: num(gym.price_day_eur),
      pass10: num(gym.price_10_pass_eur),
      monthly: num(gym.price_monthly_eur),
      discounts: pick(locale, gym.discounts_es, gym.discounts_en),
      verifiedAt: gym.prices_verified_at,
    },
    facilities: {
      surfaceM2: num(gym.surface_m2),
      maxHeightM: num(gym.max_height_m),
      routesCount: gym.routes_count,
      autobelaysCount: gym.autobelays_count,
      hasLead: gym.has_lead,
      hasBoulder: gym.has_boulder,
      hasTrainingArea: gym.has_training_area,
      belayTestRequired: gym.belay_test_required,
      gearRental: gym.gear_rental,
      hasBeginnerCourses: gym.has_beginner_courses,
      hasCafe: gym.has_cafe,
      servesBeer: gym.serves_beer,
      hasKidsArea: gym.has_kids_area,
      kidsMinAge: gym.kids_min_age,
      hasShowers: gym.has_showers,
      hasWifi: gym.has_wifi,
    },
    ...extras,
  }
}
