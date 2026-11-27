<script setup lang="ts">
/**
 * Self-hosted ALTCHA proof of work (F4.6 B7): no third party, no cookies. Invisible: it starts solving the
 * challenge when the form gets focus and `verify()` hands the payload to the submit. The element is built in
 * `onMounted` (client only), so without JS the form simply has no widget and uses the no-JS path.
 * The challenge comes from our own `/api/newsletter/challenge` relay. Also carries the honeypot (`website`).
 */
const host = ref<HTMLElement | null>(null)
const website = defineModel<string>('website', { default: '' })

interface AltchaElement extends HTMLElement {
  verify: () => Promise<{ payload: string } | null>
  reset: () => void
}
let widget: AltchaElement | null = null
let payload: string | null = null

onMounted(async () => {
  await import('altcha')
  if (!host.value) return
  const el = document.createElement('altcha-widget') as AltchaElement
  el.setAttribute('challenge', '/api/newsletter/challenge')
  el.setAttribute('name', 'altcha')
  el.setAttribute('display', 'invisible')
  el.setAttribute('auto', 'onfocus')
  el.addEventListener('verified', (ev) => (payload = (ev as CustomEvent<{ payload: string }>).detail.payload))
  el.addEventListener('expired', () => (payload = null))
  host.value.appendChild(el)
  widget = el
})

/** Payload of the solved challenge, solving it now if needed. Null if the widget is missing or fails. */
async function verify(): Promise<string | null> {
  if (payload) return payload
  if (!widget) return null
  try {
    return (await widget.verify())?.payload ?? null
  } catch {
    return null
  }
}

/** A challenge is single-use: call after every attempt, successful or not. */
function reset() {
  payload = null
  widget?.reset()
}

onBeforeUnmount(() => widget?.remove())
defineExpose({ verify, reset })
</script>

<template>
  <!-- Out of the form's grid flow (no empty row) and out of sight. -->
  <div ref="host" class="absolute size-px overflow-hidden">
    <!-- Honeypot (B7): hidden from sighted users and screen readers; bots fill it. -->
    <div aria-hidden="true" class="sr-only pointer-events-none">
      <input v-model="website" type="text" name="website" tabindex="-1" autocomplete="off" />
    </div>
  </div>
</template>
