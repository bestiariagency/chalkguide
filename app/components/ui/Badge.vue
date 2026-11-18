<script setup lang="ts">
import type { Component } from 'vue'
import { BadgeCheck, Clock, Gift, Link as LinkIcon } from 'lucide-vue-next'

/**
 * Non-interactive label. Transparency kinds always use the muted-accent tone.
 * If a badge needs an explanation, link to /transparencia from text next to it.
 */
type Kind = 'neutral' | 'author' | 'guest-visit' | 'affiliate' | 'verified' | 'stale'

const props = withDefaults(defineProps<{ kind?: Kind; icon?: Component }>(), {
  kind: 'neutral',
  icon: undefined,
})

const presetIcon: Partial<Record<Kind, Component>> = {
  'guest-visit': Gift,
  affiliate: LinkIcon,
  verified: BadgeCheck,
  stale: Clock,
}

const resolvedIcon = computed(() => props.icon ?? presetIcon[props.kind])

const tone = computed(() => {
  switch (props.kind) {
    case 'author':
    case 'guest-visit':
    case 'affiliate':
      return 'bg-accent-muted text-accent'
    case 'stale':
      return 'border border-dashed border-control text-meta'
    default:
      return 'bg-elevated text-meta'
  }
})
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 rounded-sm px-2 py-1.25 text-micro leading-[1.35] font-medium"
    :class="tone"
  >
    <component
      :is="resolvedIcon"
      v-if="resolvedIcon"
      :size="14"
      aria-hidden="true"
      :class="kind === 'verified' && 'text-success-text'"
    />
    <slot />
  </span>
</template>
