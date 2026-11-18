<script setup lang="ts">
/** Shoes list (F6.9) on the shared items list. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Pies de gato')
</script>

<template>
  <AdminItemsList :info="SHOE_INFO" />
</template>
