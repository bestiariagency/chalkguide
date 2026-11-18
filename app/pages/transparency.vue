<script setup lang="ts">
const { t } = useI18n()
const { page, error, refresh } = await useEditorialPage('transparency')
</script>

<template>
  <PageEditorial :page="page" :title="t('footer.transparency')" :error="error" :on-retry="refresh" />
</template>
