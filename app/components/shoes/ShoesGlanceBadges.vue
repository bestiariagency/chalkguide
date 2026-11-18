<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/** "los uso" (own experience) before "afiliado": which models carry a link. Outside the link. */
defineProps<{ shoe: Pick<ShoeSummary, 'ownedByAuthor' | 'isAffiliate'> }>()
const { t } = useI18n()
</script>

<template>
  <span v-if="shoe.ownedByAuthor || shoe.isAffiliate" class="flex flex-wrap gap-1.5">
    <UiBadge v-if="shoe.ownedByAuthor" kind="author">{{ t('shoes.usedBadge') }}</UiBadge>
    <UiBadge v-if="shoe.isAffiliate" kind="affiliate">{{ t('shoes.affiliateBadge') }}</UiBadge>
  </span>
</template>
