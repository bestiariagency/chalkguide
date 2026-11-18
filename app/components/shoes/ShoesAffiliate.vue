<script setup lang="ts">
import { ExternalLink, Link as LinkIcon } from 'lucide-vue-next'
import type { ShoeSummary } from '~/types/domain'

/**
 * Affiliate button + its mark, always together (project rule): `rel="sponsored nofollow
 * noopener"`, a visible badge/note next to the link, and the note linked through
 * aria-describedby. Ghost button: buying never outranks the review. Renders nothing without a
 * valid http(s) URL.
 */
const props = defineProps<{ shoe: ShoeSummary; variant: 'hero' | 'box' }>()
const { t } = useI18n()
const { linkFor } = usePageLinks()
const noteId = useId()
const label = computed(() =>
  props.shoe.affiliateProgram
    ? t('shoes.detail.seePriceAt', { shop: props.shoe.affiliateProgram })
    : t('shoes.compare.seePrice'),
)
</script>

<template>
  <div v-if="shoe.isAffiliate && isHttpUrl(shoe.affiliateUrl)">
    <UiButton
      variant="ghost"
      :href="shoe.affiliateUrl"
      :icon="ExternalLink"
      target="_blank"
      rel="sponsored nofollow noopener"
      :aria-describedby="noteId"
      :class="variant === 'box' && 'w-full'"
    >
      {{ label }}
    </UiButton>
    <p
      v-if="variant === 'hero'"
      :id="noteId"
      class="mt-3 flex max-w-[52ch] flex-wrap items-start gap-x-2 gap-y-1 text-note text-meta"
    >
      <UiBadge kind="affiliate" class="shrink-0">{{ t('transparency.affiliate') }}</UiBadge>
      <span>
        {{ t('transparency.affiliateHint') }}
        <UiTextLink :to="{ name: 'transparency' }" v-bind="linkFor('transparency')">{{ t('transparency.learnMore') }}</UiTextLink>
      </span>
    </p>
    <p v-else :id="noteId" class="mt-3 flex gap-2 text-note text-meta">
      <LinkIcon :size="16" aria-hidden="true" class="mt-0.5 shrink-0 text-accent" />
      <span>
        <span class="text-foreground">{{ t('transparency.affiliate') }}.</span>
        {{ t('transparency.affiliateHint') }}
      </span>
    </p>
  </div>
</template>
