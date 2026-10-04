<script setup lang="ts">
const { t } = useI18n()
</script>

<template>
  <section class="space-y-4">
    <h1 class="font-display text-4xl font-bold tracking-tight text-brand">
      {{ t('home.title') }}
    </h1>
    <p class="text-lg text-ink-muted">
      {{ t('home.intro') }}
    </p>
  </section>
</template>
