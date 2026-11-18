<script setup lang="ts" generic="F extends string">
/** Filter chips (all must match) as a labelled group; the parent owns the state in the URL. */
defineProps<{
  /** Unique id for the group label (the chips can appear twice: bar and sheet). */
  labelId: string
  label: string
  filterKeys: readonly F[]
  filterLabel: (key: F) => string
  active: F[]
  /** Hide the visible label (the sheet already has its own title). */
  hideLabel?: boolean
}>()
const emit = defineEmits<{ toggle: [key: F] }>()
</script>

<template>
  <div>
    <p :id="labelId" class="label-mini mb-3" :class="hideLabel && 'sr-only'">{{ label }}</p>
    <div class="flex flex-wrap gap-2" role="group" :aria-labelledby="labelId">
      <UiChip
        v-for="key in filterKeys"
        :key="key"
        :pressed="active.includes(key)"
        @update:pressed="emit('toggle', key)"
      >
        {{ filterLabel(key) }}
      </UiChip>
    </div>
  </div>
</template>
