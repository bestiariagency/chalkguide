<script setup lang="ts">
import type { BucketView } from '~/utils/admin-stats-buckets'
import type { StatsCol } from '~/utils/admin-stats-series'

/** «Ver como tabla»: the same series as numbers. It is the full accessible alternative (README §16.4). */
defineProps<{ buckets: BucketView[]; cols: StatsCol[]; caption: string; first: string }>()
</script>

<template>
  <div class="-mx-1 max-h-80 overflow-auto px-1" tabindex="0" role="region" :aria-label="caption">
    <table class="w-full text-[13px] tabular-nums">
      <caption class="sr-only">{{ caption }}</caption>
      <thead class="sticky top-0 bg-adm-elev">
        <tr>
          <th scope="col" class="border-b border-adm-line py-1.5 pr-2 text-left text-xs font-medium whitespace-nowrap text-adm-meta">{{ first }}</th>
          <th v-for="c in cols" :key="c.label" scope="col" class="border-b border-adm-line px-2 py-1.5 text-right text-xs font-medium whitespace-nowrap text-adm-meta">{{ c.label }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="b in buckets" :key="b.start" class="[&:not(:last-child)>*]:border-b [&>*]:border-adm-line">
          <th scope="row" class="py-1.5 pr-2 text-left font-normal">
            {{ b.full }}<span v-if="b.note" class="ml-1 text-xs text-adm-muted">({{ b.note }})</span>
          </th>
          <td v-for="c in cols" :key="c.label" class="px-2 py-1.5 text-right">{{ fmtNum(c.value(b)) }}</td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
