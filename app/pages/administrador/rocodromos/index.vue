<script setup lang="ts">
/** Gyms list (F6.7) on the shared items list. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Rocódromos')
</script>

<template>
  <AdminItemsList :info="GYM_INFO" />
</template>
