<script setup lang="ts">
import type { LocaleRouteTo } from '~/types/ui'
import { ExternalLink } from 'lucide-vue-next'

const props = withDefaults(
  defineProps<{
    /** Internal route (NuxtLinkLocale). */
    to?: LocaleRouteTo
    /** Force a locale (e.g. a Spanish-only page linked from /en) plus hreflang; under /en it appends the "(in Spanish)" hint. */
    locale?: 'es' | 'en'
    hreflang?: string
    /** External URL. */
    href?: string
    variant?: 'default' | 'accent'
    /** Affiliate link: rel="sponsored nofollow noopener" (the visible badge goes next to it). */
    sponsored?: boolean
    /** Opens in a new tab and shows the external icon. */
    external?: boolean
  }>(),
  { to: undefined, href: undefined, variant: 'default', locale: undefined, hreflang: undefined },
)

const { t } = useI18n()
const inSpanish = useSpanishHint(() => props.locale)

const rel = computed(() => {
  if (props.sponsored) return 'sponsored nofollow noopener'
  if (props.external) return 'noopener'
  return undefined
})
</script>

<template>
  <NuxtLinkLocale
    v-if="to"
    :to="to"
    :locale="locale"
    :hreflang="hreflang"
    class="relative link-underline after:absolute after:inset-x-0 after:-inset-y-3.5"
    :class="
      variant === 'accent' ? 'text-accent [--link-base:color-mix(in_oklab,var(--color-accent)_35%,transparent)]' : 'text-foreground'
    "
  >
    <slot />
    <template v-if="inSpanish"> {{ t('common.inSpanish') }}</template>
  </NuxtLinkLocale>
  <a
    v-else
    :href="href"
    :rel="rel"
    :target="external ? '_blank' : undefined"
    class="relative link-underline after:absolute after:inset-x-0 after:-inset-y-3.5"
    :class="[
      variant === 'accent' ? 'text-accent [--link-base:color-mix(in_oklab,var(--color-accent)_35%,transparent)]' : 'text-foreground',
      external && 'inline-flex items-center gap-1',
    ]"
  >
    <slot />
    <ExternalLink v-if="external" :size="16" aria-hidden="true" />
  </a>
</template>
