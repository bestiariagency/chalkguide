// Checks i18n/locales/{es,en}.json: same key set in both, and every static `t('a.b')` /
// literal key used under app/ exists. Dynamic keys (t(`x.${y}`)) are listed for manual review.
// Usage: node scripts/check-i18n.mjs   (exit code 1 on any problem)
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

const load = (locale) => JSON.parse(readFileSync(`i18n/locales/${locale}.json`, 'utf8'))
const es = load('es')
const en = load('en')

const flatten = (obj, prefix = '') =>
  Object.entries(obj).flatMap(([k, v]) =>
    v && typeof v === 'object' ? flatten(v, `${prefix}${k}.`) : [`${prefix}${k}`],
  )
const get = (obj, path) => path.split('.').reduce((acc, k) => acc?.[k], obj)

const esKeys = new Set(flatten(es))
const enKeys = new Set(flatten(en))
const onlyEs = [...esKeys].filter((k) => !enKeys.has(k))
const onlyEn = [...enKeys].filter((k) => !esKeys.has(k))

function* walk(dir) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name)
    if (statSync(path).isDirectory()) yield* walk(path)
    else if (/\.(vue|ts)$/.test(name)) yield path
  }
}

const namespaces = new Set(Object.keys(es))
const used = new Set()
const dynamic = new Set()
for (const file of walk('app')) {
  const src = readFileSync(file, 'utf8')
  for (const [, key] of src.matchAll(/(?<![=\w])['"]([a-zA-Z]+(?:\.[a-zA-Z0-9_]+)+)['"]/g)) {
    if (namespaces.has(key.split('.')[0])) used.add(key)
  }
  // Explicit t('…') calls count even when their namespace does not exist yet.
  for (const [, key] of src.matchAll(/\bt\(\s*['"]([a-zA-Z0-9_.]+)['"]/g)) used.add(key)
  for (const [, key] of src.matchAll(/\bt\(`([^`]*\$\{[^`]*)`/g)) dynamic.add(`${file}: ${key}`)
}
// Leaf keys only: a literal that resolves to an object (a namespace prefix) is not a missing key.
const missing = [...used].filter((k) => get(es, k) === undefined || get(en, k) === undefined)

console.log(`keys: es ${esKeys.size}, en ${enKeys.size}; literal keys used: ${used.size}`)
if (onlyEs.length) console.log('only in es:', onlyEs)
if (onlyEn.length) console.log('only in en:', onlyEn)
if (missing.length) console.log('used but missing (may include non-i18n literals):', missing)
if (dynamic.size) console.log('dynamic keys to review by hand:\n  ' + [...dynamic].join('\n  '))
process.exit(onlyEs.length || onlyEn.length || missing.length ? 1 : 0)
