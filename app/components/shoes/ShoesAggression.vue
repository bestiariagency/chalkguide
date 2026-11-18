<script setup lang="ts">
import type { ShoeSummary } from '~/types/domain'

/** Three bars: how aggressive the profile is (decorative; the profile name is always next to it). */
const props = defineProps<{ profile: ShoeSummary['profile'] }>()
const level = computed(() => aggressionLevel(props.profile))
</script>

<template>
  <span v-if="level" class="inline-flex shrink-0 gap-0.5" aria-hidden="true">
    <span
      v-for="bar in 3"
      :key="bar"
      class="h-1 w-3 rounded-full"
      :class="bar <= level ? 'bg-chalk' : 'bg-(--bar-track)'"
    />
  </span>
</template>
