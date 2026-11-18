<script setup lang="ts">
/**
 * Loading placeholder of `AdminDataTable`: `rows` bars inside a `<tbody>` (`columns` = colspan) or,
 * under 768, a list of cards. Occupies its space from the start; `visible` (delayed by the table)
 * avoids a flash on fast loads. Pulse stops with reduced motion.
 */
defineProps<{ kind: 'table' | 'cards'; columns?: number; visible: boolean }>()
</script>

<template>
  <tbody v-if="kind === 'table'" aria-hidden="true" :class="!visible && 'invisible'">
    <tr v-for="n in 6" :key="n">
      <td :colspan="columns" class="h-10 border-b border-adm-line px-3">
        <div class="h-3 animate-pulse rounded bg-adm-subtle motion-reduce:animate-none" :style="{ width: `${90 - n * 8}%` }" />
      </td>
    </tr>
  </tbody>
  <ul v-else aria-hidden="true" :class="!visible && 'invisible'">
    <li v-for="n in 4" :key="n" class="space-y-2 border-b border-adm-line p-3">
      <div class="h-4 w-3/4 animate-pulse rounded bg-adm-line motion-reduce:animate-none" />
      <div class="h-3 w-1/2 animate-pulse rounded bg-adm-subtle motion-reduce:animate-none" />
    </li>
  </ul>
</template>
