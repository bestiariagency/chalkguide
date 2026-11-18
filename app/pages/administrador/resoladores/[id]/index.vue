<script setup lang="ts">
/**
 * `/administrador/resoladores/[id]`: resoler editor (F6.8), on the shared item editor. Seven tabs;
 * published resolers are edited on a draft of changes (D23).
 */
definePageMeta({ layout: 'admin', i18n: false, adminEditor: true })
const id = String(useRoute().params.id)
</script>

<template>
  <AdminItemsEditor :id="id" :spec="RESOLER_SPEC">
    <template #panel="{ tab }"><AdminResolersPanels :tab="tab" /></template>
  </AdminItemsEditor>
</template>
