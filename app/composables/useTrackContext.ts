import { normalizePath, type TrackContext } from '~/utils/track'

/** The context of one page: it only counts while the address bar still shows that page. */
export interface PageTrackContext extends TrackContext {
  path: string
}

/**
 * What the current page is, for the analytics events (D69). A page calls `setTrackContext` in its
 * setup. The context is tied to the page's path, so a stale one is never used on another page and
 * nothing has to be cleared. In articles `contentSlug` and `pillar` are always `slug_es`, also
 * under /en (data-model, D69 veto).
 */
export function useTrackContext() {
  const state = useState<PageTrackContext | null>('track:context', () => null)
  const route = useRoute()

  function setTrackContext(value: TrackContext) {
    // Client only: the server render sends no events, and this keeps the SSR payload free of it.
    if (import.meta.client) state.value = { ...value, path: normalizePath(route.path) }
  }

  /** The context of the page shown now, or an empty one. */
  function currentContext(): TrackContext {
    if (!import.meta.client || !state.value) return {}
    const { path, ...rest } = state.value
    return path === normalizePath(window.location.pathname) ? rest : {}
  }

  return { setTrackContext, currentContext }
}
