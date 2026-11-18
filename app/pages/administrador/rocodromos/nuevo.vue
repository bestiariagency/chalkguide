<script setup lang="ts">
/** `/administrador/rocodromos/nuevo`: creates a minimal unpublished gym and replaces itself with its editor. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Nuevo rocódromo')
</script>

<template>
  <AdminItemsNew :info="GYM_INFO" />
</template>
