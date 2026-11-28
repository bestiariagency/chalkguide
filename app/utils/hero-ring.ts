/** Pointer / trackpad travel (in card widths) that moves the ring by one card. */
export const DRAG_CARD_SPAN = 0.9
/** Time constant (ms) of the ease-out chase of `target`: settles in about 4x this, at any frame rate. */
export const CHASE_MS = 90
/** Throw (ms of release velocity) added when a drag ends. */
export const THROW_MS = 240
/** Horizontal pointer travel (px) before a press becomes a drag. */
export const DRAG_THRESHOLD_PX = 6
/** From this viewport width the hero is the ring; below it, a flat scroll-snap carousel (same cut as the CSS). */
export const HERO_RING_MIN_WIDTH = 900

export interface RingGeometry {
  cardW: number
  cardH: number
  radius: number
  /** Angle (rad) between two neighbour cards. */
  step: number
  /** Perspective distance (px). */
  perspective: number
}

/** Card size and cylinder radius for a ring box of `W`×`H` px (the ring only runs from 900px up). */
export function ringGeometry(W: number, H: number): RingGeometry {
  const cardW = Math.round(Math.min(W * 0.21, H * 0.96 * 0.74))
  const gap = cardW * 0.09
  const radius = Math.max(W * 0.85, cardW * 2.4)
  return {
    cardW,
    cardH: Math.round(cardW / 0.74),
    radius,
    step: (cardW + gap) / radius,
    perspective: Math.round(radius * 0.95),
  }
}
