/**
 * Click-to-load video facade (D26). One delegated `click` listener on `document`. On a facade button
 * inside a `[data-prose]` or `[data-video-root]` root (news videos, FV2) it builds the player iframe with the DOM API only (never innerHTML) from the
 * canonical constants of `article-embeds.ts`. The ID is read from the facade and re-validated (D4). The
 * loading layer comes already rendered (hidden). No consent is remembered (D14).
 */
export default defineNuxtPlugin((nuxtApp) => {
  document.addEventListener('click', (event) => {
    const target = event.target
    if (!(target instanceof Element)) return
    const button = target.closest('button[data-video-play]')
    const figure = button?.closest('figure[data-video-facade]')
    if (!button || !figure || !figure.closest('[data-prose], [data-video-root]')) return

    const id = figure.getAttribute('data-video-facade') ?? ''
    const frame = figure.querySelector('[data-video-frame]')
    if (!YOUTUBE_ID.test(id) || !frame || frame.querySelector('iframe')) return

    const locale = String(unref(nuxtApp.$i18n.locale)) === 'en' ? 'en' : 'es'
    const iframe = document.createElement('iframe')
    iframe.setAttribute('src', videoPlayerSrc(id))
    // News videos carry their title (`data-video-title`, set by Vue): «{title} · YouTube».
    const caption = figure.getAttribute('data-video-title')?.slice(0, 200)
    iframe.setAttribute('title', caption ? `${caption} · YouTube` : VIDEO_TITLE[locale])
    iframe.setAttribute('allow', VIDEO_PLAYER_ALLOW)
    iframe.setAttribute('referrerpolicy', VIDEO_REFERRER_POLICY)
    iframe.setAttribute('sandbox', VIDEO_SANDBOX)
    iframe.setAttribute('allowfullscreen', '')

    frame.querySelector('[data-video-nojs]')?.remove()
    button.remove()
    frame.classList.add('photo-placeholder', 'overflow-hidden')
    frame.setAttribute('aria-busy', 'true')
    frame.querySelector('[data-video-loading]')?.removeAttribute('hidden')
    iframe.addEventListener('load', () => frame.removeAttribute('aria-busy'), { once: true })
    frame.append(iframe)
    iframe.focus()
  })
})
