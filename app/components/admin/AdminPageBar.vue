<script setup lang="ts">
/**
 * Top bar of a panel screen: title, optional count and chips (`meta` slot), actions (default slot).
 * The title is the page `h1` and the bar shows at every width. With `desktop-only` (screens whose own
 * `h1` lives in the body; the mobile bar takes over under 768) it is a plain label shown from 768.
 * `count` stays hidden while it is `undefined`/`null` (still loading).
 */
defineProps<{ title: string; count?: number | null; desktopOnly?: boolean; titleId?: string }>()
</script>

<template>
  <header :class="['h-12 flex-none items-center gap-2 border-b border-adm-line px-4 text-sm md:px-6', desktopOnly ? 'hidden md:flex' : 'flex']">
    <span v-if="desktopOnly" class="font-medium">{{ title }}</span>
    <h1 v-else :id="titleId" class="font-medium">
      {{ title }} <span v-if="count != null" class="ml-1 font-normal text-adm-meta tabular-nums">{{ count }}</span>
    </h1>
    <slot name="meta" />
    <div v-if="$slots.default" class="ml-auto flex items-center gap-2"><slot /></div>
  </header>
</template>
