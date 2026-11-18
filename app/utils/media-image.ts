/**
 * Browser-side image preparation before upload (client only; uses canvas):
 * - reads width/height,
 * - re-encodes JPEG/PNG/WebP through a canvas, which drops EXIF/GPS and applies the orientation,
 * - caps the long side at `MAX_SIDE` px (the design shows 2400 × 1600),
 * - computes the dominant colour (#rrggbb).
 * GIF (animation) and AVIF (no canvas encoder) are uploaded untouched, only measured.
 */
export const MAX_SIDE = 2400
const REENCODE = ['image/jpeg', 'image/png', 'image/webp']
const QUALITY = 0.88

export interface PreparedImage {
  blob: Blob
  mime: string
  width: number
  height: number
  color: string
  /** True when EXIF/GPS were removed by re-encoding. */
  stripped: boolean
}

const hex = (n: number) => Math.round(n).toString(16).padStart(2, '0')

/** Most populated 4-bit-per-channel bucket of a 48 px thumbnail, as the mean colour of that bucket. */
export function dominantColor(bitmap: ImageBitmap): string {
  const size = 48
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = size
  const ctx = canvas.getContext('2d', { willReadFrequently: true })
  if (!ctx) return '#808080'
  ctx.drawImage(bitmap, 0, 0, size, size)
  const { data } = ctx.getImageData(0, 0, size, size)
  const buckets = new Map<number, { n: number; r: number; g: number; b: number }>()
  for (let i = 0; i < data.length; i += 4) {
    if (data[i + 3]! < 128) continue
    const r = data[i]!, g = data[i + 1]!, b = data[i + 2]!
    const key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4)
    const bucket = buckets.get(key) ?? { n: 0, r: 0, g: 0, b: 0 }
    bucket.n++
    bucket.r += r
    bucket.g += g
    bucket.b += b
    buckets.set(key, bucket)
  }
  const top = [...buckets.values()].sort((a, b) => b.n - a.n)[0]
  return top ? `#${hex(top.r / top.n)}${hex(top.g / top.n)}${hex(top.b / top.n)}` : '#808080'
}

export async function decodeImage(source: Blob): Promise<ImageBitmap> {
  try {
    return await createImageBitmap(source, { imageOrientation: 'from-image' })
  } catch {
    throw new Error('No se ha podido leer la imagen. Puede estar dañada.')
  }
}

function toBlob(canvas: HTMLCanvasElement, mime: string): Promise<Blob> {
  return new Promise((resolve, reject) =>
    canvas.toBlob((blob) => (blob?.type === mime ? resolve(blob) : reject(new Error('Tu navegador no puede procesar este formato.'))), mime, QUALITY),
  )
}

export async function prepareImage(file: File): Promise<PreparedImage> {
  const bitmap = await decodeImage(file)
  try {
    const color = dominantColor(bitmap)
    if (!REENCODE.includes(file.type)) return { blob: file, mime: file.type, width: bitmap.width, height: bitmap.height, color, stripped: false }
    const scale = Math.min(1, MAX_SIDE / Math.max(bitmap.width, bitmap.height))
    const width = Math.max(1, Math.round(bitmap.width * scale))
    const height = Math.max(1, Math.round(bitmap.height * scale))
    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    const ctx = canvas.getContext('2d')
    if (!ctx) throw new Error('No se ha podido procesar la imagen.')
    ctx.drawImage(bitmap, 0, 0, width, height)
    const blob = await toBlob(canvas, file.type)
    return { blob, mime: file.type, width, height, color, stripped: true }
  } finally {
    bitmap.close()
  }
}
