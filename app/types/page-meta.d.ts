declare module '#app' {
  interface PageMeta {
    /** false hides the newsletter block above the footer (e.g. newsletter pages). */
    newsletterBlock?: boolean
    /** Panel article editor: no bottom navigation bar (it has its own fixed action bar). */
    adminEditor?: boolean
  }
}

export {}
