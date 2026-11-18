<script setup lang="ts">
import type { Component } from 'vue'

/**
 * Always says what happens, why and what you can do (never a bare "0").
 * variant="board": chalkboard texture + handwritten heading (e.g. "Pizarra limpia").
 * The action goes in the #action slot (usually a ghost UiButton).
 */
withDefaults(
  defineProps<{
    title: string
    body?: string
    variant?: 'board' | 'plain'
    /** Short handwritten heading (board variant). */
    handTitle?: string
    icon?: Component
  }>(),
  { variant: 'plain', body: undefined, handTitle: undefined, icon: undefined },
)
</script>

<template>
  <div
    class="rounded-lg border-[0.5px] border-line-strong p-8 text-center"
    :class="variant === 'board' ? 'board-tex' : 'bg-board'"
  >
    <p v-if="handTitle" class="-rotate-1 font-hand text-[32px] leading-[1.15] text-meta">
      {{ handTitle }}
    </p>
    <component
      :is="icon"
      v-else-if="icon"
      :size="24"
      class="mx-auto text-meta"
      aria-hidden="true"
    />
    <p class="font-medium" :class="handTitle ? 'mt-2' : 'mt-3'">{{ title }}</p>
    <p v-if="body" class="mx-auto mt-1 max-w-[36ch] text-caption text-meta">{{ body }}</p>
    <div v-if="$slots.action" class="mt-5"><slot name="action" /></div>
  </div>
</template>
