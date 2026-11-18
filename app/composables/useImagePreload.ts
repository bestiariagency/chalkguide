interface PreloadSource {
  src: string | null | undefined
  width?: number | null
  height?: number | null
  sizes?: string
}

/**
 * `<link rel="preload" as="image">` for the page's LCP image, emitted in the SSR `<head>` so the
 * browser fetches it before parsing the body. It asks `@nuxt/image` for the same `srcset`/`sizes`
 * the `<NuxtImg>` renders (same width/height modifiers), so both URLs match and nothing is
 * downloaded twice. Call it only for the first image of a page.
 */
export function useImagePreload(source: () => PreloadSource) {
  const img = useImage()
  useHead({
    link: () => {
      const { src, width, height, sizes } = source()
      if (!src) return []
      const modifiers = { ...(width ? { width } : {}), ...(height ? { height } : {}) }
      const image = img.getSizes(src, { sizes, modifiers })
      return [
        {
          key: `preload-image-${src}`,
          rel: 'preload',
          as: 'image',
          href: image.src,
          imagesrcset: image.srcset,
          imagesizes: image.sizes,
          fetchpriority: 'high',
        },
      ]
    },
  })
}
