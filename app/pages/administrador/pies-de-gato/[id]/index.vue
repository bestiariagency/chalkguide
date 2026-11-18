<script setup lang="ts">
/**
 * `/administrador/pies-de-gato/[id]`: shoe editor (F6.9), on the shared item editor. Six tabs;
 * published shoes are edited on a draft of changes (D23).
 */
definePageMeta({ layout: 'admin', i18n: false, adminEditor: true })
const id = String(useRoute().params.id)
</script>

<template>
  <AdminItemsEditor :id="id" :spec="SHOE_SPEC">
    <template #panel="{ tab }"><AdminShoesPanels :tab="tab" /></template>
  </AdminItemsEditor>
</template>
