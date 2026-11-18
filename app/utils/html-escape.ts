/**
 * HTML helpers shared by the string renderers that run AFTER the sanitizer (item cards, video
 * facades). Everything interpolated into their markup goes through `escapeHtml`.
 */
export const escapeHtml = (text: string) => text.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`)

/** Reads a double-quoted attribute from the attribute string of a canonical (sanitized) tag. */
export const htmlAttr = (name: string) => new RegExp(`\\s${name}="([^"]*)"`, 'i')
