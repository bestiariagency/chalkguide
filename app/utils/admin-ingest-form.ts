import type { AdminSource, IngestKind } from '~/utils/admin-ingest'
import type { NewsScope } from '~/utils/admin-news'
import { SOURCE_DOMAIN_MESSAGES, sourceDomainProblem } from '~/utils/admin-source-domain'

export interface SourceForm {
  name: string
  /** Address of the page to read, without the scheme (the field has the `https://` affix). */
  url: string
  kind: IngestKind
  scope: NewsScope
  lang: string
  instructions: string
  trusted: boolean
  active: boolean
}
export type SourceField = 'name' | 'url' | 'instructions'
export type SourceErrors = Partial<Record<SourceField, string>>

export const INSTRUCTIONS_MAX = 280

export const emptySourceForm = (): SourceForm => ({ name: '', url: '', kind: 'both', scope: 'cat', lang: '', instructions: '', trusted: false, active: true })

export function sourceToForm(s: AdminSource): SourceForm {
  return { name: s.name, url: s.url.replace(/^https:\/\//, ''), kind: s.kind, scope: s.scope, lang: s.lang ?? '', instructions: s.instructions ?? '', trusted: s.trusted, active: s.active }
}

/** Same rule as the CHECK of `news_sources.url`: https, no credentials or port. */
const SOURCE_PAGE = /^https:\/\/[^\s/?#"<>\\@:]+([/?#][^\s"<>\\]*)?$/
const fullUrl = (v: string) => (/^https?:\/\//i.test(v.trim()) ? v.trim() : `https://${v.trim()}`)

export function validateSource(form: SourceForm): SourceErrors {
  const e: SourceErrors = {}
  if (!form.name.trim()) e.name = 'Falta el nombre.'
  else if (form.name.trim().length > 120) e.name = 'El nombre pasa de 120 caracteres.'
  if (!form.url.trim()) e.url = 'Falta la web.'
  else if (!SOURCE_PAGE.test(fullUrl(form.url)) || !sourceDomain(fullUrl(form.url)).includes('.')) e.url = 'Debe ser una dirección https:// sin usuario ni puerto.'
  else {
    const problem = sourceDomainProblem(sourceDomain(fullUrl(form.url)))
    if (problem) e.url = SOURCE_DOMAIN_MESSAGES[problem]
  }
  if (form.instructions.length > INSTRUCTIONS_MAX) e.instructions = `Pasa de ${INSTRUCTIONS_MAX} caracteres.`
  else if (/https?:\/\/|@|\bwww\./i.test(form.instructions)) e.instructions = 'Nunca enlaces ni datos personales: la rutina las lee como instrucciones.'
  return e
}

/** Columns written to `news_sources`; the domain is the host of the page without `www.` (subdomains are accepted by the allowlist). */
export function sourceWrite(form: SourceForm) {
  const url = fullUrl(form.url)
  return {
    name: form.name.trim(),
    url,
    domain: sourceDomain(url),
    kind: form.kind,
    scope: form.scope,
    lang: form.lang || null,
    instructions: form.instructions.trim() || null,
    trusted: form.trusted,
    active: form.active,
  }
}

/** Database errors of the source and token writes in the words of the panel. */
export function ingestError(error: unknown): string {
  const e = error as { code?: string; message?: string } | null
  const code = e?.code
  const message = e?.message ?? ''
  if (code === '23505') return 'Ya hay una fuente con ese dominio.'
  if (code === '23514') return 'Algún dato no cumple las reglas (formato o longitud). Revisa los campos.'
  if (code === '23503') return 'La fuente tiene noticias: no se elimina, se desactiva.'
  if (code === '55000') return 'Ya hay 2 tokens activos. Revoca uno antes de crear otro.'
  if (code === '42501') return 'No tienes permiso para hacer esto. Vuelve a entrar en el panel.'
  if (/fetch|network|failed to load/i.test(message)) return 'No hay conexión con el servidor. Comprueba la red e inténtalo de nuevo.'
  return 'No se ha podido completar la acción. Inténtalo de nuevo; si sigue, mira el estado de Supabase.'
}
