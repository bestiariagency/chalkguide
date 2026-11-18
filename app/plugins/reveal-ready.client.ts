/** Enables the section reveal's hidden state only once the app is hydrated and can reveal it. */
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.hook('app:mounted', () => {
    if ('IntersectionObserver' in window) document.documentElement.classList.add('reveal-ready')
  })
})
