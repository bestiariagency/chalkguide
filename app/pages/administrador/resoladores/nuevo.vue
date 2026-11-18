<script setup lang="ts">
/** `/administrador/resoladores/nuevo`: creates a minimal unpublished resoler and replaces itself with its editor. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Nuevo resolador')
</script>

<template>
  <AdminItemsNew :info="RESOLER_INFO" />
</template>
