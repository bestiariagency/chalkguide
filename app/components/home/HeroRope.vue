<script setup lang="ts">
/** The rope: cord from under the centre card and the carabiner that jumps to the next section. */
const { t } = useI18n()
</script>

<template>
  <i class="hero-rope-cord absolute top-0 bottom-14 left-[-2.5px] block w-[5px] rounded-[3px]" />
  <a
    href="#paths"
    :aria-label="t('home.hero.ropeLabel')"
    class="hero-rope-end pointer-events-auto absolute bottom-0 left-[-22px] block h-16 w-11 text-accent"
  >
    <svg
      viewBox="0 0 44 64"
      fill="none"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="block h-16 w-11"
      aria-hidden="true"
    >
      <path stroke="var(--color-rope-shade)" stroke-width="6" d="M18 6h7c9 0 14 7 13 15l-3 28c-1 6-6 10-12 10h-3c-6 0-11-5-11-11V15c0-5 4-9 9-9Z" />
      <path
        stroke="currentColor"
        stroke-width="3.6"
        d="M18 6h7c9 0 14 7 13 15l-3 28c-1 6-6 10-12 10h-3c-6 0-11-5-11-11V15c0-5 4-9 9-9Z"
      />
      <path stroke="var(--color-rope-shade)" stroke-width="3.6" d="m38 21-3 28" />
      <path
        fill="currentColor"
        stroke="currentColor"
        stroke-width="1"
        d="m34.6 33 4.6.5-1.2 11.6-4.6-.5z"
      />
    </svg>
  </a>
</template>
