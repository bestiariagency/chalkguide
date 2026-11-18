/**
 * Word and screen-reader text of a descriptive scale (grading, style): shared by the listing
 * card and the detail page. Without a valid value, `word` is null (the caller writes "no data").
 */
export function useGymScale(kind: GymScaleKind, value: MaybeRefOrGetter<number | null>) {
  const { t } = useI18n()
  const word = computed(() => {
    const key = gymScaleWordKey(kind, toValue(value))
    return key ? t(key) : null
  })
  const srText = computed(() =>
    word.value
      ? t('gyms.scale.srValue', {
          value: word.value,
          n: toValue(value),
          low: t(`gyms.${kind}.low`).toLowerCase(),
          high: t(`gyms.${kind}.high`).toLowerCase(),
        })
      : null,
  )
  return { word, srText }
}
