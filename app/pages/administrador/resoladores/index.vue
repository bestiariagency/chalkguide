<script setup lang="ts">
/** Resolers list (F6.8) on the shared items list. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Resoladores')
</script>

<template>
  <AdminItemsList :info="RESOLER_INFO" />
</template>
