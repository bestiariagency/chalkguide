<script setup lang="ts">
/** `/administrador/resoladores/importar`: importer of resoladores (F6.15b, D50). */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Importar resoladores')
</script>

<template>
  <AdminImportPage :info="RESOLER_INFO" />
</template>
