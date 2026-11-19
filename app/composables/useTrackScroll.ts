import type { Ref } from 'vue'

/** `scroll_75` (D69): once per page, when the reader passes 75 % of an article. */
export function useTrackScroll(progress: Readonly<Ref<number>>) {
  const { track } = useTrack()
  const route = useRoute()
  let sent = false
  watch(() => route.path, () => (sent = false))
  watch(progress, (value) => {
    if (sent || value < 0.75) return
    sent = true
    track('scroll_75')
  })
}
