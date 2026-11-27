/** ALTCHA challenge: relays the EF reply untouched (F4.6 §15.1). */
export default defineEventHandler(async (event) => {
  guardNewsletterRequest(event, false)
  const { secret, url } = newsletterRelay(event)
  const res = await $fetch.raw<Record<string, unknown>>(url, {
    method: 'GET',
    headers: { 'x-cg-relay': secret },
    ignoreResponseError: true,
    timeout: 8000,
    retry: 0,
  }).catch(() => null)
  if (!res || res.status !== 200) throw createError({ statusCode: 502, statusMessage: 'Bad gateway' })
  return res._data
})
