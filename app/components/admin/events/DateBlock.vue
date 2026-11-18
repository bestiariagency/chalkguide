<script setup lang="ts">
import { dateBlock } from '~/utils/admin-madrid'

/** Day block of lists and previews: weekday (mono), day number and month; "hoy" in the accent colour. */
const props = defineProps<{ iso: string }>()
const block = computed(() => dateBlock(props.iso))
</script>

<template>
  <span class="w-11 flex-none text-center leading-none" aria-hidden="true">
    <span :class="['block font-mono text-[11px] tracking-[0.08em] uppercase', block.today ? 'text-adm-acc' : 'text-adm-meta']">{{ block.weekday }}</span>
    <span class="mt-[3px] block text-xl font-semibold tabular-nums">{{ block.day }}</span>
    <span class="mt-0.5 block text-[11px] text-adm-meta">{{ block.month }}</span>
  </span>
</template>
