<script setup lang="ts">
/**
 * Intro overlay: the logo mark and a grade counter under four orange pills.
 * Hidden by CSS unless <html> has `has-intro` (set before first paint by the head script).
 */
defineProps<{ up: boolean; open: boolean; grade: string }>()
defineEmits<{ skip: [] }>()
</script>

<template>
  <div class="hero-intro" :class="{ 'is-up': up, 'is-open': open }" aria-hidden="true" @pointerdown="$emit('skip')">
    <div
      class="hero-intro-mark absolute inset-0 grid content-center justify-items-center gap-3.5 text-foreground transition-opacity duration-150"
    >
      <img src="/brand/iso-chalk-white.svg" alt="" width="56" height="56" class="block size-14" />
      <span class="min-w-[3ch] text-center font-mono text-[22px]/none font-medium tabular-nums">
        {{ grade }}
      </span>
    </div>
    <div class="hero-intro-pills absolute inset-0 grid grid-cols-4">
      <i /><i /><i /><i />
    </div>
  </div>
</template>
