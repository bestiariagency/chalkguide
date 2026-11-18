<script setup lang="ts">
import { CircleAlert, Info, TriangleAlert } from 'lucide-vue-next'
import type { Component } from 'vue'

/**
 * Inline banner (design system «banner»): `info` (neutral), `warn` and `err` (`role="alert"`). The text goes in the default
 * slot, buttons in `actions`. Never colour alone: every kind has its icon.
 */
const props = defineProps<{ kind?: 'info' | 'warn' | 'err'; icon?: Component }>()
const tones = {
  info: 'bg-adm-subtle text-adm-fg [&_svg]:text-adm-meta',
  warn: 'bg-adm-warn-soft text-adm-warn [&_svg]:text-adm-warn',
  err: 'bg-adm-danger-soft text-adm-fg [&_svg]:text-adm-danger',
}
const kind = computed(() => props.kind ?? 'info')
const icon = computed(() => props.icon ?? { info: Info, warn: TriangleAlert, err: CircleAlert }[kind.value])
</script>

<template>
  <div :class="['flex items-start gap-2 rounded-lg px-3 py-2 text-[13px] leading-5', tones[kind]]" :role="kind === 'err' ? 'alert' : undefined">
    <component :is="icon" class="mt-0.5 size-4 flex-none" aria-hidden="true" />
    <div class="min-w-0 flex-1"><slot /><div v-if="$slots.actions" class="mt-2 flex flex-wrap gap-2"><slot name="actions" /></div></div>
  </div>
</template>
