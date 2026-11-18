<script setup lang="ts">
/** `/administrador/rocodromos/importar`: importer of rocódromos (F6.15b, D50). */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Importar rocódromos')
</script>

<template>
  <AdminImportPage :info="GYM_INFO" />
</template>
