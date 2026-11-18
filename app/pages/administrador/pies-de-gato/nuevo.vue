<script setup lang="ts">
/** `/administrador/pies-de-gato/nuevo`: creates a minimal unpublished shoe and replaces itself with its editor. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Nuevo pie de gato')
</script>

<template>
  <AdminItemsNew :info="SHOE_INFO" />
</template>
