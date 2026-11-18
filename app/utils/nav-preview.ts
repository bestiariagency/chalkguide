import type { MediaRef } from '~/types/domain'
import type { NavPreviewSource } from '~/types/nav-preview'

/** Newest first; equal dates break by name so the pick is stable. */
const byRecent = <T extends { updatedAt: string }>(a: T, b: T) =>
  Date.parse(b.updatedAt) - Date.parse(a.updatedAt)

const range = (values: number[]) => ({ min: Math.min(...values), max: Math.max(...values) })

/** Gyms card: count, monthly price range, cheapest gym and the most recently edited cover. */
export function summariseGyms(gyms: NavPreviewSource['gyms']) {
  const priced = gyms.filter((gym) => gym.priceMonthly !== null)
  const [cheapest] = [...priced].sort(
    (a, b) => a.priceMonthly! - b.priceMonthly! || a.name.localeCompare(b.name),
  )
  if (!cheapest) return null
  const cover: MediaRef | null =
    [...gyms].filter((gym) => gym.cover).sort(byRecent)[0]?.cover ?? null
  return {
    // Only gyms with a monthly price: the figure must match the range and the lowest fee shown.
    count: priced.length,
    ...range(priced.map((gym) => gym.priceMonthly!)),
    cheapest: cheapest.name,
    cover,
  }
}

/** Shoes card: model count, cheapest beginner model and the latest edited cover. */
export function summariseShoes(shoes: NavPreviewSource['shoes']) {
  const prices = shoes
    .filter((shoe) => shoe.levels.includes('beginner') && shoe.priceMin !== null)
    .map((shoe) => shoe.priceMin!)
  if (!prices.length) return null
  const cover: MediaRef | null =
    [...shoes].filter((shoe) => shoe.cover).sort(byRecent)[0]?.cover ?? null
  return { count: shoes.length, from: Math.min(...prices), cover }
}

/** Resoling card: workshop count, price per pair range and turnaround range (when known). */
export function summariseResolers(resolers: NavPreviewSource['resolers']) {
  const prices = resolers.flatMap((r) => (r.pricePerPair === null ? [] : [r.pricePerPair]))
  if (!prices.length) return null
  const mins = resolers.flatMap((r) => (r.turnaroundMin === null ? [] : [r.turnaroundMin]))
  const maxs = resolers.flatMap((r) => (r.turnaroundMax === null ? [] : [r.turnaroundMax]))
  return {
    // Only workshops with a price, so the figure matches the price range shown.
    count: prices.length,
    price: range(prices),
    days: mins.length && maxs.length ? { min: Math.min(...mins), max: Math.max(...maxs) } : null,
  }
}
