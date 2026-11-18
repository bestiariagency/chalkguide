// Generates app/types/database.types.ts for the `guide` schema, in the same shape as
// `supabase gen types typescript`. The Supabase MCP generator only emits `public`, so this
// reads the JSON produced by scripts/guide-types-meta.sql instead.
//
// Usage: node scripts/gen-guide-types.mjs <meta.json> [out.ts]
// <meta.json> may be the raw JSON result or an MCP tool-result file that wraps it.
import { readFileSync, writeFileSync } from 'node:fs'

const [input, output = 'app/types/database.types.ts'] = process.argv.slice(2)
if (!input) {
  console.error('Usage: node scripts/gen-guide-types.mjs <meta.json> [out.ts]')
  process.exit(1)
}

const meta = parseMeta(readFileSync(input, 'utf8'))
const enums = meta.enums ?? {}
const domains = meta.doms ?? {}

const SCALARS = {
  string: [
    'text',
    'varchar',
    'bpchar',
    'uuid',
    'citext',
    'date',
    'timestamptz',
    'timestamp',
    'time',
    'timetz',
    'interval',
    'inet',
    'cidr',
    'bytea',
    'tsvector',
    'name',
  ],
  number: ['int2', 'int4', 'int8', 'numeric', 'float4', 'float8', 'oid'],
  boolean: ['bool'],
  Json: ['json', 'jsonb'],
}

function parseMeta(raw) {
  const start = raw.indexOf('[{')
  let text = raw
  if (!raw.trimStart().startsWith('{"meta"') && start !== -1) {
    // MCP tool-result file: JSON-encoded string with the rows inside untrusted-data tags.
    const outer = JSON.parse(raw).result
    text = outer.slice(outer.indexOf('[{'), outer.lastIndexOf('}]') + 2)
  }
  const parsed = JSON.parse(text)
  return Array.isArray(parsed) ? parsed[0].meta : (parsed.meta ?? parsed)
}

function pgToTs(udt) {
  if (udt.startsWith('_')) return `${pgToTs(udt.slice(1))}[]`
  if (enums[udt]) return `Database["guide"]["Enums"]["${udt}"]`
  if (domains[udt]) return pgToTs(domains[udt])
  for (const [ts, names] of Object.entries(SCALARS)) if (names.includes(udt)) return ts
  return 'unknown'
}

// Maps a type as written by pg_get_function_* (e.g. "text", "guide.slug", "uuid[]").
function sqlTypeToTs(sqlType) {
  const t = sqlType.trim().replace(/^guide\./, '')
  if (t.endsWith('[]')) return `${sqlTypeToTs(t.slice(0, -2))}[]`
  const alias = {
    text: 'text',
    'character varying': 'varchar',
    uuid: 'uuid',
    integer: 'int4',
    bigint: 'int8',
    smallint: 'int2',
    numeric: 'numeric',
    boolean: 'bool',
    jsonb: 'jsonb',
    json: 'json',
    date: 'date',
    'timestamp with time zone': 'timestamptz',
    'timestamp without time zone': 'timestamp',
    'double precision': 'float8',
    real: 'float4',
    citext: 'citext',
    inet: 'inet',
  }
  return pgToTs(alias[t] ?? t)
}

const columnsByRel = {}
for (const c of meta.cols) (columnsByRel[c.table_name] ??= []).push(c)

const relKinds = Object.fromEntries(meta.rels.map((r) => [r.relname, r.relkind]))
const tableNames = Object.keys(relKinds)
  .filter((n) => relKinds[n] === 'r')
  .sort()
const viewNames = Object.keys(relKinds)
  .filter((n) => relKinds[n] !== 'r')
  .sort()

function colType(c) {
  return c.data_type === 'ARRAY' ? pgToTs(c.udt_name) : pgToTs(c.udt_name)
}

function relationships(rel) {
  const fks = (meta.fks ?? [])
    .filter((f) => f.tbl === rel)
    .sort((a, b) => a.conname.localeCompare(b.conname))
  if (!fks.length) return '[]'
  const items = fks.map(
    (f) => `          {
            foreignKeyName: "${f.conname}"
            columns: [${f.cols.map((c) => `"${c}"`).join(', ')}]
            isOneToOne: false
            referencedRelation: "${f.ref}"
            referencedColumns: [${f.refcols.map((c) => `"${c}"`).join(', ')}]
          },`,
  )
  return `[\n${items.join('\n')}\n        ]`
}

function tableBlock(name) {
  const cols = columnsByRel[name] ?? []
  const row = cols.map(
    (c) => `          ${c.column_name}: ${colType(c)}${c.is_nullable === 'YES' ? ' | null' : ''}`,
  )
  const write = (mode) =>
    cols.map((c) => {
      if (c.is_generated === 'ALWAYS') return `          ${c.column_name}?: never`
      const optional =
        mode === 'update' ||
        c.is_nullable === 'YES' ||
        c.column_default !== null ||
        c.is_identity === 'YES'
      return `          ${c.column_name}${optional ? '?' : ''}: ${colType(c)}${c.is_nullable === 'YES' ? ' | null' : ''}`
    })
  return `      ${name}: {
        Row: {
${row.join('\n')}
        }
        Insert: {
${write('insert').join('\n')}
        }
        Update: {
${write('update').join('\n')}
        }
        Relationships: ${relationships(name)}
      }`
}

function viewBlock(name) {
  const cols = columnsByRel[name] ?? []
  const row = cols.map((c) => `          ${c.column_name}: ${colType(c)} | null`)
  return `      ${name}: {
        Row: {
${row.join('\n')}
        }
        Relationships: []
      }`
}

function splitTopLevel(s) {
  const parts = []
  let depth = 0
  let cur = ''
  for (const ch of s) {
    if (ch === '(') depth++
    if (ch === ')') depth--
    if (ch === ',' && depth === 0) {
      parts.push(cur)
      cur = ''
    } else cur += ch
  }
  if (cur.trim()) parts.push(cur)
  return parts.map((p) => p.trim())
}

function functionArgs(args) {
  if (!args.trim()) return 'never'
  const fields = splitTopLevel(args).map((a) => {
    const hasDefault = /\sDEFAULT\s/i.test(a)
    const decl = a.replace(/\sDEFAULT\s.*$/i, '').replace(/^(IN|INOUT|VARIADIC)\s+/i, '')
    const [argName, ...type] = decl.split(/\s+/)
    return `${argName}${hasDefault ? '?' : ''}: ${sqlTypeToTs(type.join(' '))}`
  })
  return `{ ${fields.join('; ')} }`
}

function functionReturns(result) {
  const r = result.trim()
  if (r === 'void') return 'undefined'
  const table = r.match(/^TABLE\((.*)\)$/s)
  if (table) {
    const fields = splitTopLevel(table[1]).map((f) => {
      const [col, ...type] = f.split(/\s+/)
      return `${col}: ${sqlTypeToTs(type.join(' '))}`
    })
    return `{ ${fields.join('; ')} }[]`
  }
  const setof = r.match(/^SETOF\s+(.*)$/)
  const base = (setof ? setof[1] : r).replace(/^guide\./, '')
  const rowRef = relKinds[base]
    ? `Database["guide"]["${relKinds[base] === 'r' ? 'Tables' : 'Views'}"]["${base}"]["Row"]`
    : sqlTypeToTs(base)
  return setof ? `${rowRef}[]` : rowRef
}

function functionsBlock() {
  const byName = {}
  for (const f of meta.funcs ?? []) (byName[f.proname] ??= []).push(f)
  return Object.keys(byName)
    .sort()
    .map((name) => {
      const sigs = byName[name].map(
        (f) => `{ Args: ${functionArgs(f.args)}; Returns: ${functionReturns(f.result)} }`,
      )
      return `      ${name}: ${sigs.join('\n        | ')}`
    })
    .join('\n')
}

function enumsBlock() {
  const names = Object.keys(enums).sort()
  if (!names.length) return '      [_ in never]: never'
  return names.map((n) => `      ${n}: ${enums[n].map((v) => `"${v}"`).join(' | ')}`).join('\n')
}

const out = `// GENERATED by scripts/gen-guide-types.mjs from the live \`guide\` schema. Do not edit by hand.
// Regenerate after every migration (see the header of that script).

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  guide: {
    Tables: {
${tableNames.map(tableBlock).join('\n')}
    }
    Views: {
${viewNames.length ? viewNames.map(viewBlock).join('\n') : '      [_ in never]: never'}
    }
    Functions: {
${functionsBlock() || '      [_ in never]: never'}
    }
    Enums: {
${enumsBlock()}
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type GuideSchema = Database["guide"]

export type Tables<T extends keyof GuideSchema["Tables"] | keyof GuideSchema["Views"]> =
  (GuideSchema["Tables"] & GuideSchema["Views"])[T] extends { Row: infer R } ? R : never

export type TablesInsert<T extends keyof GuideSchema["Tables"]> = GuideSchema["Tables"][T]["Insert"]

export type TablesUpdate<T extends keyof GuideSchema["Tables"]> = GuideSchema["Tables"][T]["Update"]

export type Enums<T extends keyof GuideSchema["Enums"]> = GuideSchema["Enums"][T]

export const Constants = {
  guide: {
    Enums: {
${Object.keys(enums)
  .sort()
  .map((n) => `      ${n}: [${enums[n].map((v) => `"${v}"`).join(', ')}],`)
  .join('\n')}
    },
  },
} as const
`

writeFileSync(output, out)
console.log(
  `Wrote ${output}: ${tableNames.length} tables, ${viewNames.length} views, ${Object.keys(enums).length} enums, ${(meta.funcs ?? []).length} functions`,
)
