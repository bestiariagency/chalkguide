/** Same set as the `shoes_brand_trimmed` / `shoes_model_trimmed` CHECKs (migration 20261112225647): spaces and invisible characters. */
const EDGE = '[\\s\\u00A0\\u00AD\\u034F\\u061C\\u115F-\\u1160\\u1680\\u17B4-\\u17B5\\u180B-\\u180E\\u2000-\\u200F\\u2028-\\u202F\\u205F-\\u2064\\u2066-\\u2069\\u3000\\u3164\\uFEFF\\uFFA0\\u{E0000}-\\u{E007F}]'
// U+034F is a combining mark on purpose: the CHECK lists it.
// eslint-disable-next-line no-misleading-character-class
const EDGES = new RegExp(`^${EDGE}+|${EDGE}+$`, 'gu')

/** Text without spaces or invisible characters at both ends. */
export const trimInvisible = (text: string): string => text.replace(EDGES, '')
