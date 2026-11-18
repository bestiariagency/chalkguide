import { BLOCKER_TEXT } from '~/utils/item-blockers'
import type { AdminItemRow } from '~/utils/admin-items'

/** Column "Para publicar" and batch publishing (README §13.7). The blockers come from the server (`admin_item_publish_blockers`). */
export type Readiness =
  | { kind: 'ready' }
  | { kind: 'blocked'; blockers: string[] }
  | { kind: 'hidden' }
  | { kind: 'changes' }
  | { kind: 'live' }
  | { kind: 'unknown' }

/** Unpublished with a publication date = hidden by the author (not a new draft). */
const isHidden = (row: AdminItemRow) => !row.published && !!row.published_at

export function readinessOf(row: AdminItemRow, blockers: ReadonlyMap<string, string[]> | undefined): Readiness {
  if (row.published) return row.changes > 0 ? { kind: 'changes' } : { kind: 'live' }
  if (isHidden(row)) return { kind: 'hidden' }
  const found = blockers?.get(row.id)
  if (!blockers || found === undefined) return blockers ? { kind: 'ready' } : { kind: 'unknown' }
  return found.length ? { kind: 'blocked', blockers: found } : { kind: 'ready' }
}

export const readyText = (blockers: readonly string[]) => (blockers.length === 1 && blockers[0] === 'cover' ? 'Falta portada' : `Falta ${BLOCKER_TEXT[blockers[0] ?? ''] ?? 'un requisito'}`)

export interface PublishPlan {
  ready: AdminItemRow[]
  blocked: { row: AdminItemRow; blockers: string[] }[]
  hidden: AdminItemRow[]
  /** Published with a draft of changes: the batch applies each draft with `publish_draft` (no force), without the diff (D23). */
  changes: AdminItemRow[]
  /** Published without changes: not part of the batch. */
  live: AdminItemRow[]
}

export function planPublish(rows: readonly AdminItemRow[], blockers: ReadonlyMap<string, string[]> | undefined): PublishPlan {
  const plan: PublishPlan = { ready: [], blocked: [], hidden: [], changes: [], live: [] }
  for (const row of rows) {
    const state = readinessOf(row, blockers)
    if (state.kind === 'ready' || state.kind === 'unknown') plan.ready.push(row)
    else if (state.kind === 'blocked') plan.blocked.push({ row, blockers: state.blockers })
    else if (state.kind === 'hidden') plan.hidden.push(row)
    else if (state.kind === 'changes') plan.changes.push(row)
    else plan.live.push(row)
  }
  return plan
}

/** Reason why the draft of changes of a published item was not applied (`publish_draft` without force). */
export const draftFailureText = (code: string | undefined) =>
  code === 'PT409' ? 'otra edición ha chocado con sus cambios: revísala y publícala desde su ficha' : 'no se han podido publicar sus cambios: inténtalo desde su ficha'

/** Reason of a failed item of `publish_items`. */
export function publishFailureText(code: string | undefined, blockers?: readonly string[]): string {
  switch (code) {
    case 'blocked': return `le falta ${(blockers ?? []).map((b) => BLOCKER_TEXT[b] ?? b).join('; ') || 'algún requisito'}`
    case 'hidden': return 'está oculta: publícala desde su ficha'
    case 'already_published': return 'ya estaba publicada'
    case 'not_found': return 'ya no existe'
    default: return 'el servidor no la ha publicado'
  }
}
