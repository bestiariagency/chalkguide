/** Pointer / trackpad travel (in card widths) that moves the ring by one card. */
export const DRAG_CARD_SPAN = 1.16
/** Share of the remaining distance covered per frame (ease-out chase of `target`). */
export const CHASE_RATE = 0.11
/** Horizontal pointer travel (px) before a press becomes a drag. */
export const DRAG_THRESHOLD_PX = 6

export interface RingGeometry {
  cardW: number
  cardH: number
  radius: number
  /** Angle (rad) between two neighbour cards. */
  step: number
  /** Perspective distance (px). */
  perspective: number
}

/** Card size and cylinder radius for a ring box of `W`×`H` px (phones get bigger, tighter cards). */
export function ringGeometry(W: number, H: number): RingGeometry {
  const phone = W < 900
  const cardW = Math.round(phone ? Math.min(W * (W < 600 ? 0.74 : 0.46), H * 0.94 * 0.76) : Math.min(W * 0.21, H * 0.96 * 0.74))
  const gap = cardW * (phone ? 0.1 : 0.09)
  const radius = Math.max(W * (phone ? 1.05 : 0.85), cardW * 2.4)
  return {
    cardW,
    cardH: Math.round(cardW / (phone ? 0.76 : 0.74)),
    radius,
    step: (cardW + gap) / radius,
    perspective: Math.round(radius * (phone ? 1.05 : 0.95)),
  }
}
