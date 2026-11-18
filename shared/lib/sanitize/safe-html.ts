/**
 * HTML produced by `sanitizeArticleHtml` (shared/lib/sanitize) and nothing else. `UiProse` only accepts
 * this type, so typecheck rejects raw strings. The brand is a type-level fence, not a runtime check.
 */
export type SafeHtml = string & { readonly __brand: 'SafeHtml' }
