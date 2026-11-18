<script setup lang="ts">
import type { LocaleRouteTo } from '~/types/ui'

/** Nav link: meta → foreground, accent underline draws on hover and stays when current. */
const props = defineProps<{
  to: LocaleRouteTo
  ariaCurrent?: 'page' | 'true'
  /** Force a locale (e.g. a Spanish-only page linked from /en) plus hreflang; under /en it appends the "(in Spanish)" hint. */
  locale?: 'es' | 'en'
  hreflang?: string
}>()
const { t } = useI18n()
const inSpanish = useSpanishHint(() => props.locale)
</script>

<template>
  <NuxtLinkLocale
    :to="to"
    :locale="locale"
    :hreflang="hreflang"
    :aria-current="ariaCurrent"
    class="relative inline-flex min-h-11 items-center text-meta transition-colors duration-150 ease-standard after:absolute after:inset-x-0 after:bottom-2 after:h-[1.5px] after:origin-right after:scale-x-0 after:bg-accent after:transition-transform after:duration-200 after:ease-out hover:text-foreground hover:after:origin-left hover:after:scale-x-100 aria-[current]:text-foreground aria-[current]:after:scale-x-100"
  >
    <slot />
    <template v-if="inSpanish"> {{ t('common.inSpanish') }}</template>
  </NuxtLinkLocale>
</template>
