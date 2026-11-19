import type { NewsLayout } from '~/utils/news-view'

/**
 * Grid/list switch of /noticias (§18.6). What is *seen* comes from `data-news-view` on <html> (CSS), so the server HTML is the
 * same for everyone; this state only feeds `aria-pressed`, which is corrected on mount from that attribute (never read in
 * the first render, to avoid a hydration mismatch).
 */
export function useNewsView() {
  const view = useState<NewsLayout>('news-view', () => 'grid')
  onMounted(() => {
    view.value = parseNewsView(document.documentElement.getAttribute('data-news-view')) ?? 'grid'
  })
  function setView(next: NewsLayout) {
    view.value = next
    rememberNewsView(next)
  }
  return { view, setView }
}
