import type { GuideEvent, GymSummary, MediaRef, ShoeSummary, ArticleSummary } from '~/types/domain'
import type { HeroCardData } from '~/types/ui'

interface HeroSources {
  photos: (MediaRef | null)[]
  shoes: ShoeSummary[]
  event: GuideEvent | null
  gyms: GymSummary[]
  article: ArticleSummary | null
}

/** Card ratio (about 0.74 wide/high) times the image's 118% width (hero.css .hero-img). */
const CARD_IMAGE_RATIO = 0.87

/**
 * The 8 cards of the home carousel in ring order (photo 1, shoe 1, event, gym 2, photo 2,
 * shoe 2, gym 1, article), never starting on a photo; whatever is missing is skipped.
 * Texts are built here, once.
 */
export function useHeroCards(sources: () => HeroSources) {
  const { t, locale } = useI18n()
  const mediaUrl = useMediaUrl()
  const image = (media: MediaRef | null, alt: string, ratio?: number) => {
    if (!media) return null
    const width = media.width ?? 1600
    const height = media.height ?? 1067
    // Landscape-only crop: ask the optimiser for the card's ratio (the face crops by height), so
    // srcset widths are real card widths instead of a wide frame cropped down.
    const crop = ratio && width / height > ratio
    return {
      src: mediaUrl(media.path),
      width: crop ? Math.round(height * ratio) : width,
      height,
      alt,
    }
  }

  return computed<HeroCardData[]>(() => {
    const { photos, shoes, event, gyms, article } = sources()
    const photo = (media: MediaRef | null, key: string): HeroCardData | null =>
      media
        ? {
            key,
            kind: 'photo',
            strong: false,
            to: null,
            label: media.alt ?? '',
            image: image(media, media.alt ?? ''),
          }
        : null

    const shoe = (item: ShoeSummary | undefined): HeroCardData | null => {
      if (!item) return null
      // "Reseña" only with a real author review and a note in this language.
      const reviewed = item.visitType !== null && !!item.authorSizeNote
      const price =
        item.priceMin === null || item.priceMax === null
          ? null
          : item.priceMin === item.priceMax
            ? t('home.hero.meta.shoePrice', { price: item.priceMin })
            : t('home.hero.meta.shoePriceRange', { min: item.priceMin, max: item.priceMax })
      return {
        key: `shoe-${item.id}`,
        kind: 'shoe',
        strong: false,
        to: { name: 'climbing-shoes-slug', params: { slug: item.slug } },
        label: item.name,
        image: image(item.cover, ''),
        eyebrow: t(reviewed ? 'home.hero.kind.review' : 'home.hero.kind.shoe'),
        title: item.name,
        note: reviewed ? `«${firstSentence(item.authorSizeNote ?? '')}»` : (price ?? undefined),
      }
    }

    const gym = (item: GymSummary | undefined): HeroCardData | null => {
      if (!item) return null
      const district = item.district ?? ''
      const price = item.priceMonthly
      const note =
        price === null
          ? t('home.hero.meta.gymNoPrice', { district })
          : item.hasLead && item.maxHeightM !== null
            ? t('home.hero.meta.gymLead', { district, price, height: item.maxHeightM })
            : item.hasBoulder && !item.hasLead
              ? t('home.hero.meta.gymBoulder', { district, price })
              : t('home.hero.meta.gymNoPrice', { district })
      return {
        key: `gym-${item.id}`,
        kind: 'gym',
        strong: true,
        to: { name: 'climbing-gyms-slug', params: { slug: item.slug } },
        label: item.name,
        image: image(item.cover, '', CARD_IMAGE_RATIO),
        eyebrow: t('home.hero.kind.gym'),
        title: item.name,
        note,
      }
    }

    const agenda = (item: GuideEvent | null): HeroCardData | null => {
      if (!item) return null
      const at = (options: Intl.DateTimeFormatOptions) =>
        formatDate(item.startsAt, locale.value, options)
      const weekday = capitalise(at({ weekday: 'long' }))
      return {
        key: `event-${item.id}`,
        kind: 'event',
        strong: false,
        to: { name: 'events' },
        label: item.title,
        image: null,
        eyebrow: t('home.hero.kind.event'),
        title: item.title,
        note: item.allDay ? weekday : `${weekday}, ${formatTime(item.startsAt, locale.value)}`,
        date: {
          day: at({ day: 'numeric' }),
          month: at({ month: 'short' }).replace('.', '').slice(0, 3),
        },
      }
    }

    const post = (item: ArticleSummary | null): HeroCardData | null =>
      item
        ? {
            key: `article-${item.id}`,
            kind: 'article',
            strong: true,
            to: { name: 'blog-slug', params: { slug: item.slug } },
            label: item.title,
            image: image(item.cover, '', CARD_IMAGE_RATIO),
            eyebrow: t('home.hero.kind.article'),
            title: item.title,
          }
        : null

    const [shoe1, shoe2] = shoes
    const [gym1, gym2] = gyms
    const cards = [
      photo(photos[0] ?? null, 'photo-1'),
      shoe(shoe1),
      agenda(event),
      gym(gym2),
      photo(photos[1] ?? null, 'photo-2'),
      shoe(shoe2),
      gym(gym1),
      post(article),
    ].filter((card): card is HeroCardData => card !== null)
    return startOffPhoto(cards)
  })
}
