<script setup lang="ts">
/** Key-value list (design system `.dl-data`): label left, tabular mono value right. */
import type { DataRow } from '~/types/ui'

defineProps<{ rows: DataRow[] }>()
const { t } = useI18n()
</script>

<template>
  <dl class="grid grid-cols-[minmax(0,1fr)_auto] tabular-nums">
    <div v-for="row in rows" :key="row.label" class="contents">
      <dt class="border-b-[0.5px] border-line py-[.7rem] text-body-sm text-meta [div:last-child>&]:border-b-0">
        {{ row.label }}
      </dt>
      <dd
        class="border-b-[0.5px] border-line py-[.7rem] pl-4 text-right font-mono text-data [div:last-child>&]:border-b-0"
        :class="row.tone === 'accent' ? 'text-accent' : row.tone === 'muted' ? 'text-meta' : ''"
      >
        {{ row.value ?? t('common.noData') }}
      </dd>
    </div>
  </dl>
</template>
