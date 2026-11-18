import type { PageContent } from '~/types/domain'
import { getSiteSettings } from '~/services/site-settings'
import { getAboutNumbers } from '~/services/about'

export function useSiteSettings() {
  return useGuideData('site-settings', getSiteSettings)
}

export function usePageContent(key: string) {
  return useContentData<PageContent>(`page:${key}`, `/api/content/page/${encodeURIComponent(key)}`)
}

/** Author data of site_settings (name falls back to the brand author name). */
export function useAuthor() {
  const { t } = useI18n()
  const { data } = useSiteSettings()
  const author = computed(() => data.value?.author ?? null)
  return {
    author,
    name: computed(() => author.value?.name ?? t('blog.author.name')),
  }
}

export function useAboutNumbers() {
  return useGuideData('about-numbers', getAboutNumbers)
}
