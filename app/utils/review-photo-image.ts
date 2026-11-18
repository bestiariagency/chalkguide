import { decodeImage } from '~/utils/media-image'

/**
 * Browser-side re-encoding of reader photos (client only): applies the EXIF orientation, caps the
 * long side and re-encodes through a canvas, which drops EXIF/GPS. WebP when the browser can encode
 * it, JPEG otherwise (Safari). Also used by the panel to publish the approved copy.
 */
export const REVIEW_PHOTO_MAX_SIDE = 1600
export const REVIEW_PHOTO_MAX_BYTES = 2 * 1024 * 1024
const START_QUALITY = 0.82
const MIN_QUALITY = 0.5

export interface ProcessedPhoto {
  blob: Blob
  mime: 'image/webp' | 'image/jpeg'
  ext: 'webp' | 'jpg'
  width: number
  height: number
}

function encode(canvas: HTMLCanvasElement, mime: string, quality: number): Promise<Blob | null> {
  return new Promise((resolve) => canvas.toBlob(resolve, mime, quality))
}

export async function processReviewPhoto(source: Blob): Promise<ProcessedPhoto> {
  const bitmap = await decodeImage(source)
  try {
    let scale = Math.min(1, REVIEW_PHOTO_MAX_SIDE / Math.max(bitmap.width, bitmap.height))
    let mime: ProcessedPhoto['mime'] | null = null
    for (let attempt = 0; attempt < 4; attempt++, scale *= 0.8) {
      const width = Math.max(1, Math.round(bitmap.width * scale))
      const height = Math.max(1, Math.round(bitmap.height * scale))
      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext('2d')
      if (!ctx) throw new Error('canvas')
      ctx.fillStyle = '#fff'
      ctx.fillRect(0, 0, width, height)
      ctx.drawImage(bitmap, 0, 0, width, height)
      if (!mime) mime = (await encode(canvas, 'image/webp', START_QUALITY))?.type === 'image/webp' ? 'image/webp' : 'image/jpeg'
      for (let quality = START_QUALITY; quality >= MIN_QUALITY - 0.001; quality -= 0.1) {
        const blob = await encode(canvas, mime, quality)
        if (blob && blob.type === mime && blob.size <= REVIEW_PHOTO_MAX_BYTES) return { blob, mime, ext: mime === 'image/webp' ? 'webp' : 'jpg', width, height }
      }
    }
    throw new Error('too_big')
  } finally {
    bitmap.close()
  }
}
