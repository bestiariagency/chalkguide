/** Saves text as a file download (browser only). */
export function saveTextFile(name: string, content: string, mime = 'text/csv') {
  const url = URL.createObjectURL(new Blob([content], { type: `${mime};charset=utf-8` }))
  const link = Object.assign(document.createElement('a'), { href: url, download: name })
  document.body.append(link)
  link.click()
  link.remove()
  setTimeout(() => URL.revokeObjectURL(url), 10_000)
}
