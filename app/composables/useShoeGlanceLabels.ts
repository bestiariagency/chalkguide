import type { ShoeSummary } from '~/types/domain'

/** Text helpers shared by the landing's shoe table (md+) and cards (< md). */
export function useShoeGlanceLabels() {
  const { t, locale } = useI18n()

  const price = (shoe: ShoeSummary) =>
    formatEurRange(shoe.priceMin, shoe.priceMax, locale.value) ?? t('common.priceUnavailable')
  const stiffnessWord = (shoe: ShoeSummary) => {
    const group = stiffnessGroup(shoe.stiffness)
    return group ? t(`shoes.stiffnessGroup.${group}`) : null
  }
  const closure = (shoe: ShoeSummary) =>
    shoe.closure ? t(`shoes.closure.${shoe.closure}`) : t('common.noData')
  const profile = (shoe: ShoeSummary) =>
    shoe.profile ? t(`shoes.profile.${shoe.profile}`) : t('common.noData')

  return { price, stiffnessWord, closure, profile }
}
