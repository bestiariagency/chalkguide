<script setup lang="ts">
import type { SwatchKind } from '~/utils/admin-stats-series'

/** Legend / detail key of a series. The pattern kinds (hidden, partial) are not only colour (README §16.4). */
defineProps<{ kind: SwatchKind }>()

const classes: Record<SwatchKind, string> = {
  line: 'h-0.5 w-3.5 rounded-[1px] bg-adm-acc',
  acc: 'size-2.5 rounded-xs bg-adm-acc',
  muted: 'size-2.5 rounded-xs bg-adm-muted',
  base: 'size-2.5 rounded-xs bg-adm-line-strong',
  hidden: 'size-2.5 rounded-xs bg-[repeating-linear-gradient(45deg,var(--adm-st-hidden)_0_1.5px,var(--adm-subtle)_1.5px_4px)] inset-ring inset-ring-adm-st-hidden',
  partial: 'size-2.5 rounded-xs bg-[repeating-linear-gradient(90deg,var(--adm-acc-soft)_0_3px,transparent_3px_5px)] inset-ring inset-ring-adm-acc',
}
</script>

<template>
  <i :class="['inline-block flex-none', classes[kind]]" aria-hidden="true" />
</template>
