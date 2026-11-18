<script setup lang="ts">
import type { ActivityDay, ActivityRecord } from '~/utils/admin-activity'

/** Entries grouped by day (newest first), one card per day. */
defineProps<{ days: ActivityDay[] }>()
defineEmits<{ detail: [entry: ActivityRecord] }>()
</script>

<template>
  <div>
    <section v-for="day in days" :key="day.key" class="mb-6" :aria-labelledby="`act-day-${day.key}`">
      <h2 :id="`act-day-${day.key}`" :class="[admGroupLabel, 'mb-2']">{{ day.label }}</h2>
      <ol :class="[admCard, 'divide-y divide-adm-line']">
        <AdminActivityRow v-for="entry in day.entries" :key="entry.id" :entry="entry" @detail="$emit('detail', entry)" />
      </ol>
    </section>
  </div>
</template>
