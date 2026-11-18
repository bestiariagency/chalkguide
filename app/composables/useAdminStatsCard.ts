import type { BucketView } from '~/utils/admin-stats-buckets'
import { statsAnnounce, statsTip, type StatsCardId } from '~/utils/admin-stats-series'

/** What every chart card shares: the active period, the keyboard hint of the label, the detail and the announcement. */
export function useAdminStatsCard(id: StatsCardId, buckets: () => BucketView[], subtitle: () => string, unit: () => string) {
  const active = ref<number | null>(null)
  const hint = computed(() => `${subtitle()}. Usa las flechas izquierda y derecha para recorrer cada ${unit()}.`)
  const at = (i: number | null) => (i === null ? undefined : buckets()[i])
  const tip = computed(() => {
    const b = at(active.value)
    return b ? statsTip(id, b) : null
  })
  const describe = (i: number) => {
    const b = at(i)
    return b ? statsAnnounce(id, b) : ''
  }
  watch(buckets, () => (active.value = null))
  return { active, hint, tip, describe }
}
