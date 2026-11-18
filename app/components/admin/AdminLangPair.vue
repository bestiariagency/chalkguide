<script setup lang="ts">
/**
 * ES / EN pair of short fields (forms: sheets, media, categories, settings). Side by side when the
 * container is at least 42rem wide (container query, so a 440 px drawer stays stacked), stacked below with each field's language tag. Pass the two fields in the `es` and `en`
 * slots (each field should set its own `lang`).
 */
defineProps<{ legend?: string }>()
</script>

<template>
  <fieldset class="@container min-w-0">
    <legend v-if="legend" class="sr-only">{{ legend }}</legend>
    <div class="grid gap-4 @2xl:grid-cols-2">
      <div><slot name="es" /></div>
      <div><slot name="en" /></div>
    </div>
  </fieldset>
</template>
