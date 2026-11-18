<script setup lang="ts">
/** `/administrador/pies-de-gato/importar`: importer of pies de gato (F6.15b, D50). */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Importar pies de gato')
</script>

<template>
  <AdminImportPage :info="SHOE_INFO" />
</template>
