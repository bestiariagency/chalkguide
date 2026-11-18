import type { Locale, SiteSettings } from '~/types/domain'
import { type GuideClient, one, pick, unwrap } from './client'
import { MEDIA_COLUMNS, toMediaRef } from './media'
import { cleanText, parseAuthorStats } from '~/utils/author'

export async function getSiteSettings(db: GuideClient, locale: Locale): Promise<SiteSettings> {
  const row = unwrap(
    await db
      .from('site_settings')
      .select(
        `tagline_es, tagline_en, contact_email, social_links, newsletter_title_es,
        newsletter_title_en, newsletter_body_es, newsletter_body_en, newsletter_consent_text_es,
        newsletter_consent_text_en, consent_version, related_consent_text_es, related_consent_text_en,
        min_user_reviews_for_average,
        author_name, author_role_es, author_role_en, author_lede_es, author_lede_en,
        author_bio_es, author_bio_en, author_stats,
        author_photo:media!site_settings_author_photo_media_id_fkey(${MEDIA_COLUMNS}),
        hero_photo_1:media!site_settings_hero_photo_1_media_id_fkey(${MEDIA_COLUMNS}),
        hero_photo_2:media!site_settings_hero_photo_2_media_id_fkey(${MEDIA_COLUMNS})`,
      )
      .eq('id', 1)
      .single(),
  )
  const links = row.social_links
  return {
    author: {
      name: cleanText(row.author_name),
      role: cleanText(pick(locale, row.author_role_es, row.author_role_en)),
      lede: cleanText(pick(locale, row.author_lede_es, row.author_lede_en)),
      bio: cleanText(pick(locale, row.author_bio_es, row.author_bio_en)),
      photo: toMediaRef(one(row.author_photo as Parameters<typeof toMediaRef>[0]), locale),
      stats: parseAuthorStats(row.author_stats, locale),
    },
    tagline: pick(locale, row.tagline_es, row.tagline_en),
    contactEmail: row.contact_email,
    socialLinks:
      links && typeof links === 'object' && !Array.isArray(links)
        ? (Object.fromEntries(
            Object.entries(links).filter(([, v]) => typeof v === 'string'),
          ) as Record<string, string>)
        : {},
    newsletterTitle: pick(locale, row.newsletter_title_es, row.newsletter_title_en),
    newsletterBody: pick(locale, row.newsletter_body_es, row.newsletter_body_en),
    // The legal consent text may lack an English version: fall back to Spanish, flagged by
    // `newsletterConsentLocale` so the UI marks it lang="es".
    newsletterConsentText:
      pick(locale, row.newsletter_consent_text_es, row.newsletter_consent_text_en) ??
      row.newsletter_consent_text_es,
    newsletterConsentLocale:
      locale === 'en' && !row.newsletter_consent_text_en ? 'es' : locale,
    consentVersion: row.consent_version,
    relatedConsentText:
      cleanText(pick(locale, row.related_consent_text_es, row.related_consent_text_en)) ??
      cleanText(row.related_consent_text_es),
    relatedConsentLocale:
      locale === 'en' && !cleanText(row.related_consent_text_en) ? 'es' : locale,
    minUserReviewsForAverage: row.min_user_reviews_for_average,
    heroPhotos: [row.hero_photo_1, row.hero_photo_2].map((media) =>
      toMediaRef(one(media as Parameters<typeof toMediaRef>[0]), locale),
    ),
  }
}
