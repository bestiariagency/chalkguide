<script setup lang="ts">
/** ES / EN pills. Never links to a missing translation (D3): falls back or disables. */
withDefaults(defineProps<{ size?: 'sm' | 'md' }>(), { size: 'sm' })
const { t } = useI18n()
const { options } = useLanguageSwitch()
</script>

<template>
  <nav :aria-label="t('nav.language')" class="flex gap-1 font-mono text-caption">
    <template v-for="option in options" :key="option.code">
      <span
        v-if="option.isCurrent"
        aria-current="true"
        :aria-label="option.label"
        class="inline-flex min-h-11 min-w-11 items-center justify-center rounded-sm bg-elevated"
        :class="size === 'md' ? 'px-3' : 'px-2.5'"
      >
        {{ option.short }}
      </span>
      <NuxtLink
        v-else-if="option.to"
        :to="option.to"
        :lang="option.code"
        :hreflang="option.code"
        :aria-label="option.label"
        class="inline-flex min-h-11 min-w-11 items-center justify-center text-meta transition-colors duration-150 hover:text-foreground"
        :class="size === 'md' ? 'px-3' : 'px-2.5'"
      >
        {{ option.short }}
      </NuxtLink>
      <span
        v-else
        role="link"
        aria-disabled="true"
        :lang="option.code"
        :aria-label="option.label"
        class="inline-flex min-h-11 cursor-not-allowed items-center text-muted"
        :class="size === 'md' ? 'px-3' : 'px-2.5'"
      >
        {{ option.short }}
      </span>
    </template>
  </nav>
</template>
