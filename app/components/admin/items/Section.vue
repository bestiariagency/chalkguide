<script setup lang="ts">
/** Block of a tab: optional title and description, fields below. Blocks after the first get a top rule. */
const props = defineProps<{ title?: string; description?: string; titleId?: string }>()
const auto = useId()
const id = computed(() => props.titleId ?? auto)
</script>

<template>
  <section :aria-labelledby="title ? id : undefined" class="mt-6 space-y-4 border-t border-adm-line pt-6 first:mt-0 first:border-0 first:pt-0">
    <div v-if="title">
      <h3 :id="id" class="text-sm font-semibold">{{ title }}</h3>
      <p v-if="description" class="mt-0.5 text-xs text-adm-meta">{{ description }}</p>
    </div>
    <slot />
  </section>
</template>
