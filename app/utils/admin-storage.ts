/** localStorage that never throws (private mode, quota, blocked storage): the preference is simply not kept. */
export function readStorage(key: string): string | null {
  try {
    return globalThis.localStorage?.getItem(key) ?? null
  } catch {
    return null
  }
}

export function writeStorage(key: string, value: string): void {
  try {
    globalThis.localStorage?.setItem(key, value)
  } catch {
    /* not kept */
  }
}

export function removeStorage(key: string): void {
  try {
    globalThis.localStorage?.removeItem(key)
  } catch {
    /* nothing to remove */
  }
}
