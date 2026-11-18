<script setup lang="ts">
/** 1–5 score as five bars + number (never colour alone: low scores also read "de 5"). `dim` fades only the bars. */
defineProps<{ score: number, dim?: boolean }>()
</script>

<template>
  <span class="inline-flex items-center gap-2">
    <span :class="['inline-flex gap-0.5', dim && 'opacity-50']" aria-hidden="true">
      <i v-for="n in 5" :key="n" :class="['h-1.5 w-2.5 rounded-[2px]', n <= score ? 'bg-adm-fg' : 'bg-adm-line-strong']" />
    </span>
    <span :class="['text-xs tabular-nums', score <= 2 && 'font-medium text-adm-danger']">{{ score }}<span class="sr-only"> de 5</span></span>
  </span>
</template>
