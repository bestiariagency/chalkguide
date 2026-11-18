import { decodeImage, dominantColor } from '~/utils/media-image'

/** Recomputes the dominant colour of an already uploaded image (public bucket, read by URL). */
export function useMediaDominantColor() {
  const busy = ref(false)
  async function compute(url: string): Promise<string | undefined> {
    busy.value = true
    try {
      const response = await fetch(url)
      if (!response.ok) return undefined
      const bitmap = await decodeImage(await response.blob())
      try {
        return dominantColor(bitmap)
      } finally {
        bitmap.close()
      }
    } catch {
      return undefined
    } finally {
      busy.value = false
    }
  }
  return { busy, compute }
}
