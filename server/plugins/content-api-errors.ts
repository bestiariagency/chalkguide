/**
 * `/api/content/**` runs under `isr` (Netlify Durable Cache). An error response (400/404/502) must
 * not be stored for the TTL: a transient Supabase 502 would otherwise stay up to 1 h. The route
 * rules put the ISR cache headers on every response of the route, errors included, so they are
 * replaced here with `no-store` (browser + Netlify CDN + Durable Cache). F4.1, leona-lia D64 obs 2.
 */
export default defineNitroPlugin((nitroApp) => {
  nitroApp.hooks.hook('error', (_error, context) => {
    const event = context?.event
    if (!event?.path.startsWith('/api/content/')) return
    setResponseHeaders(event, {
      'cache-control': 'no-store',
      'netlify-cdn-cache-control': 'no-store',
    })
  })
})
