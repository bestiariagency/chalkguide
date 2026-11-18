<script setup lang="ts">
import type { Component } from 'vue'
import type { LocaleRouteTo } from '~/types/ui'
import { ArrowRight } from 'lucide-vue-next'

type Variant = 'primary' | 'ghost' | 'quiet' | 'inline' | 'ink'

const props = withDefaults(
  defineProps<{
    variant?: Variant
    /** Internal route: rendered as NuxtLinkLocale. */
    to?: LocaleRouteTo
    /** External URL: rendered as <a>. */
    href?: string
    type?: 'button' | 'submit' | 'reset'
    loading?: boolean
    disabled?: boolean
    /** Trailing arrow that moves 3px on hover (primary CTA). */
    arrow?: boolean
    /** Leading Lucide icon (inline variant uses 16px). */
    icon?: Component
  }>(),
  { variant: 'primary', type: 'button', to: undefined, href: undefined, icon: undefined },
)

const isInline = computed(() => props.variant === 'inline')
const inactive = computed(() => props.disabled || props.loading)

const tag = computed(() => {
  if (props.disabled) return 'button'
  if (props.to) return resolveComponent('NuxtLinkLocale')
  if (props.href) return 'a'
  return 'button'
})

const attrs = computed(() => {
  if (props.disabled) return { type: 'button', disabled: true }
  if (props.to) return { to: props.to, 'aria-busy': props.loading || undefined }
  if (props.href) return { href: props.href, 'aria-busy': props.loading || undefined }
  return { type: props.type, 'aria-busy': props.loading || undefined }
})

function onClick(event: MouseEvent) {
  // Loading blocks double submit / navigation without changing the width.
  if (props.loading) event.preventDefault()
}

const base =
  'group/btn relative isolate inline-flex items-center justify-center font-medium select-none ' +
  'transition-[color,background-color,border-color,transform] duration-200 ease-standard ' +
  'disabled:cursor-not-allowed aria-busy:cursor-progress'

const variants: Record<Variant, string> = {
  primary:
    'min-h-11 gap-2 overflow-hidden rounded-md px-[1.1rem] text-body-sm bg-accent-fill text-on-accent ' +
    // Hover: accent-hover sweeps left → right (300ms).
    'before:absolute before:inset-0 before:-z-10 before:origin-right before:scale-x-0 before:bg-accent-hover ' +
    'before:transition-transform before:duration-300 before:ease-out ' +
    'not-disabled:hover:before:origin-left not-disabled:hover:before:scale-x-100 ' +
    'disabled:bg-elevated disabled:text-muted disabled:before:hidden',
  ghost:
    'min-h-11 gap-2 overflow-hidden rounded-md px-[1.1rem] text-body-sm border border-control text-foreground ' +
    'active:bg-elevated not-disabled:hover:bg-elevated not-disabled:hover:border-meta ' +
    'disabled:border-line-strong disabled:text-muted',
  // Ink: black button for the paper slab inside the orange field (an orange primary would read as a hole).
  ink:
    'min-h-[52px] gap-2 rounded-md px-[1.1rem] text-body-sm bg-[#1c1a17] text-[#fbf9f5] ' +
    'not-disabled:hover:bg-black disabled:bg-[#d8d2c6] disabled:text-[#6b6559]',
  quiet:
    'min-h-11 gap-2 overflow-hidden rounded-md px-[1.1rem] text-body-sm bg-accent-muted text-accent ' +
    'not-disabled:hover:bg-elevated disabled:bg-elevated disabled:text-muted',
  inline:
    // Visual 36px; ::after extends the touch target to 44px.
    'min-h-9 gap-1.5 rounded-md px-3 text-note bg-accent-muted text-accent ' +
    'after:absolute after:-inset-1 not-disabled:hover:bg-elevated disabled:bg-elevated disabled:text-muted',
}

const classes = computed(() => [
  base,
  variants[props.variant],
  !inactive.value && 'active:scale-[.98]',
])
</script>

<template>
  <component :is="tag" v-bind="attrs" :class="classes" @click="onClick">
    <span
      v-if="loading && !isInline"
      class="absolute size-4 animate-spin rounded-full border-2 border-current border-r-transparent motion-reduce:animate-none motion-reduce:border-r-current motion-reduce:opacity-60"
      aria-hidden="true"
    />
    <component
      :is="icon"
      v-if="icon"
      :size="isInline ? 16 : 20"
      aria-hidden="true"
      :class="loading && !isInline && 'opacity-0'"
    />
    <span :class="loading && !isInline && 'opacity-0'"><slot /></span>
    <ArrowRight
      v-if="arrow && !disabled"
      :size="16"
      aria-hidden="true"
      class="transition-transform duration-200 ease-out group-hover/btn:translate-x-[3px]"
      :class="loading && 'opacity-0'"
    />
  </component>
</template>
