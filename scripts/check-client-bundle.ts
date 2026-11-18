/**
 * Client bundle guard (D64, F6.19 C8): no chunk a public route preloads may contain the article
 * sanitizer. Run after `npm run build` (`npm run check:bundle`); exit code 1 on failure.
 *
 * Source of truth: Nuxt's own per-route `modulepreload` table (`precomputed.mjs`, written next to the
 * server bundle), i.e. exactly the chunks the SSR HTML preloads for each route plus the entry. Every
 * page except `pages/administrador/**` is public; the entry chunks are checked too, and an empty
 * table fails. The panel loads the sanitizer with a dynamic `import()`, which is not in that table. A chunk fails when it holds a marker string of
 * `sanitize-html` (`nonTextTags`) or of our allow-list. Also prints the gzip weight of the preload set
 * of `pages/blog/[slug].vue` (reference measure).
 */
import { existsSync, readFileSync } from 'node:fs'
import { join } from 'node:path'
import { gzipSync } from 'node:zlib'
import { pathToFileURL } from 'node:url'

const root = process.cwd()
const MARKERS = ['nonTextTags', 'ARTICLE_ALLOWED_TAGS', 'dropStrayBlocks']
const PANEL_PAGE = /^pages\/administrador\//
const TABLES = [
  '.netlify/functions-internal/server/chunks/virtual/precomputed.mjs',
  '.output/server/chunks/virtual/precomputed.mjs',
]
const CLIENT_DIRS = ['dist/_nuxt', '.output/public/_nuxt']

interface Resource {
  file: string
}
interface Table {
  dependencies: Record<string, { preload: Record<string, Resource> }>
  entrypoints: string[]
}

const tablePath = TABLES.map((p) => join(root, p)).find(existsSync)
const clientDir = CLIENT_DIRS.map((p) => join(root, p)).find(existsSync)
if (!tablePath || !clientDir) {
  console.error('check-client-bundle: build output not found. Run `npm run build` first.')
  process.exit(1)
}
const table = ((await import(pathToFileURL(tablePath).href)) as { default: Table }).default

const routes = Object.keys(table.dependencies).filter((key) => key.startsWith('pages/') && !PANEL_PAGE.test(key))
const files = new Set<string>()
const entries = (Array.isArray(table.entrypoints) ? table.entrypoints : []).filter((key) => table.dependencies[key])
for (const key of [...entries, ...routes]) for (const res of Object.values(table.dependencies[key]!.preload)) files.add(res.file)
if (!routes.length || !entries.length || !files.size) {
  console.error(`check-client-bundle: preload table looks empty (${routes.length} routes, ${entries.length} entries, ${files.size} files). Nuxt may have changed precomputed.mjs.`)
  process.exit(1)
}

let failed = 0
for (const file of [...files].filter((f) => f.endsWith('.js'))) {
  const code = readFileSync(join(clientDir, file), 'utf8')
  const hit = MARKERS.find((marker) => code.includes(marker))
  if (hit) {
    failed++
    const owners = [...entries, ...routes].filter((r) => Object.values(table.dependencies[r]!.preload).some((res) => res.file === file))
    console.error(`FAIL ${file} contains "${hit}" (preloaded by ${owners.slice(0, 3).join(', ')}${owners.length > 3 ? ', ...' : ''})`)
  }
}

const blog = table.dependencies['pages/blog/[slug].vue']
if (blog) {
  const js = Object.values(blog.preload).filter((res) => res.file.endsWith('.js'))
  const kb = js.reduce((sum, res) => sum + gzipSync(readFileSync(join(clientDir, res.file))).length, 0) / 1024
  console.log(`blog/[slug]: ${js.length} preloaded js chunks, ${kb.toFixed(1)} KB gzip`)
}
console.log(`check-client-bundle: ${entries.length} entry + ${routes.length} public routes, ${files.size} preloaded files, ${failed} with sanitizer`)
process.exit(failed ? 1 : 0)
