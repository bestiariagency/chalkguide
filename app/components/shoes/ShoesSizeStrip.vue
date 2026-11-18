<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/**
 * "Mi talla · De calle · Diferencia" (D21, README §9.9.4). Only inside the author review and
 * only when both sizes exist; the difference is computed, never stored. Optional fitting note.
 */
const props = defineProps<{ shoe: ShoeSummary }>()
const { t, locale } = useI18n()
const cells = computed(() => [
  { key: 'mine', value: formatSize(props.shoe.authorSizeEu, locale.value), accent: false },
  { key: 'street', value: formatSize(props.shoe.authorStreetSizeEu, locale.value), accent: false },
  {
    key: 'difference',
    value: formatSizeDifference(props.shoe.authorSizeEu, props.shoe.authorStreetSizeEu, locale.value),
    accent: true,
  },
])
</script>

<template>
  <dl
    v-if="hasSizes(shoe)"
    class="mt-5 grid max-w-read grid-cols-3 gap-x-4 gap-y-3 rounded-xl border-[0.5px] border-line-strong bg-board p-4 tabular-nums"
    :aria-label="t('shoes.detail.size.label')"
  >
    <div v-for="cell in cells" :key="cell.key">
      <dt class="text-caption text-meta">{{ t(`shoes.detail.size.${cell.key}`) }}</dt>
      <dd class="mt-1 font-mono text-[22px] leading-none" :class="cell.accent ? 'text-accent' : 'text-foreground'">
        {{ cell.value }}
      </dd>
    </div>
    <div v-if="shoe.authorSizeNote" class="col-span-3 border-t-[0.5px] border-line pt-3">
      <dt class="sr-only">{{ t('shoes.detail.size.note') }}</dt>
      <dd class="text-body-sm text-meta">{{ shoe.authorSizeNote }}</dd>
    </div>
  </dl>
</template>
