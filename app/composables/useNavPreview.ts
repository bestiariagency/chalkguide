import type { NavCard, NavPreviewSource } from '~/types/nav-preview'
import { fetchNavPreviewSource } from '~/services/nav-preview'
import { capitalise } from '~/utils/hero'
import { summariseGyms, summariseResolers, summariseShoes } from '~/utils/nav-preview'

/** Requests in flight, shared by the header and the compact bar (one fetch per locale). */
const inflight = new Map<string, Promise<void>>()

/**
 * Data of the desktop nav preview cards. `load()` is called the first time someone hovers or
 * focuses the nav (never on page load, never on touch); the result is cached per locale.
 */
export function useNavPreview() {
  const { t, locale } = useI18n()
  const db = useGuideClient()
  const guideLocale = useGuideLocale()
  const mediaUrl = useMediaUrl()
  const cache = useState<Record<string, NavPreviewSource | undefined>>('nav-preview', () => ({}))

  async function load() {
    const key = guideLocale.value
    if (cache.value[key] || inflight.has(key)) return
    const request = fetchNavPreviewSource(db, key)
      .then((source) => {
        if (source) cache.value = { ...cache.value, [key]: source }
      })
      .catch(() => undefined)
      .finally(() => inflight.delete(key))
    inflight.set(key, request)
    await request
  }

  const number = (value: number) =>
    new Intl.NumberFormat(intlLocale(locale.value), { maximumFractionDigits: 2 }).format(value)

  const cards = computed<NavCard[]>(() => {
    const source = cache.value[guideLocale.value]
    if (!source) return []
    const list: (NavCard | null)[] = []
    const image = (
      media: { path: string; width: number | null; height: number | null },
      kind: 'photo' | 'shoe',
    ) => ({
      kind,
      src: mediaUrl(media.path),
      width: media.width ?? 1600,
      height: media.height ?? 1067,
    })

    const gyms = summariseGyms(source.gyms)
    list.push(
      gyms && {
        name: 'climbing-gyms',
        tile: gyms.cover ? image(gyms.cover, 'photo') : { kind: 'num', text: String(gyms.count) },
        title:
          gyms.min === gyms.max
            ? t('nav.preview.gyms.price', { price: number(gyms.min) })
            : t('nav.preview.gyms.range', { min: number(gyms.min), max: number(gyms.max) }),
        note: t('nav.preview.gyms.note', { n: gyms.count, name: gyms.cheapest }, gyms.count),
      },
    )

    const shoes = summariseShoes(source.shoes)
    list.push(
      shoes && {
        name: 'climbing-shoes',
        tile: shoes.cover ? image(shoes.cover, 'shoe') : { kind: 'num', text: String(shoes.count) },
        title: t('nav.preview.shoes.from', { price: number(shoes.from) }),
        note: t('nav.preview.shoes.note', { n: shoes.count }, shoes.count),
      },
    )

    const resolers = summariseResolers(source.resolers)
    if (resolers) {
      const { price, days } = resolers
      const count = resolers.count
      const note = days
        ? days.min === days.max
          ? t(
              days.min === 1 ? 'nav.preview.resoling.noteOneDay' : 'nav.preview.resoling.noteDay',
              { n: count, days: days.min },
              count,
            )
          : t('nav.preview.resoling.note', { n: count, min: days.min, max: days.max }, count)
        : t('nav.preview.resoling.noteCount', { n: count }, count)
      list.push({
        name: 'climbing-shoe-resoling',
        tile: { kind: 'num', text: String(count) },
        title:
          price.min === price.max
            ? t('nav.preview.resoling.price', { price: number(price.min) })
            : t('nav.preview.resoling.range', { min: number(price.min), max: number(price.max) }),
        note,
      })
    }

    const article = source.article
    list.push(
      article?.cover
        ? {
            name: 'blog',
            tile: image(article.cover, 'photo'),
            title: article.title,
            note: t('nav.preview.blog.latest'),
            tight: true,
          }
        : null,
    )

    const event = source.events.find((item) => !item.cancelled)
    if (event) {
      const at = (options: Intl.DateTimeFormatOptions) =>
        formatDate(event.startsAt, locale.value, options)
      const weekday = capitalise(at({ weekday: 'long' }))
      list.push({
        name: 'events',
        tile: {
          kind: 'date',
          day: at({ day: 'numeric' }),
          month: at({ month: 'short' }).replace('.', '').slice(0, 3),
        },
        title: event.title,
        note: event.allDay ? weekday : `${weekday}, ${formatTime(event.startsAt, locale.value)}`,
        tight: true,
      })
    }
    return list.filter((card): card is NavCard => card !== null)
  })

  return { cards, load }
}
