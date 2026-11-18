<script setup lang="ts">
/**
 * `/administrador/rocodromos/[id]`: gym editor (F6.7), on the shared item editor. Nine tabs, a
 * publication column; published gyms are edited on a draft of changes (D23).
 */
definePageMeta({ layout: 'admin', i18n: false, adminEditor: true })
const id = String(useRoute().params.id)
</script>

<template>
  <AdminItemsEditor :id="id" :spec="GYM_SPEC">
    <template #panel="{ tab }"><AdminGymsPanels :tab="tab" /></template>
  </AdminItemsEditor>
</template>
