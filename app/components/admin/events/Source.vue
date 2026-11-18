<script setup lang="ts">
import { ExternalLink } from 'lucide-vue-next'

/**
 * Domain of the source of an event as a link (README §19.5): only the domain, without `www.`, in clear, with the safe `rel` of F3. It
 * goes outside the row button (no nested interactives): 24 px high, 44 on touch or under 768. Nothing is drawn without a valid URL.
 */
const props = defineProps<{ url: string | null; title: string }>()
const href = computed(() => safeHref(props.url))
const domain = computed(() => sourceDomain(props.url))
</script>

<template>
  <a v-if="href && domain" :href="href" target="_blank" :rel="SOURCE_LINK_REL" class="inline-flex min-h-6 items-center gap-1 font-mono text-xs text-adm-meta underline decoration-adm-line-strong underline-offset-2 hover:text-adm-fg hover:decoration-current max-md:min-h-11 [@media(pointer:coarse)]:min-h-11">
    {{ domain }}<ExternalLink class="size-3" aria-hidden="true" /><span class="sr-only">Fuente de «{{ title }}», se abre en otra pestaña</span>
  </a>
</template>
