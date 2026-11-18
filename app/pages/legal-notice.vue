<script setup lang="ts">
const { t } = useI18n()
const { page, error, refresh } = await useEditorialPage('legal_notice')
</script>

<template>
  <PageEditorial :page="page" :title="t('footer.legalNotice')" :error="error" :on-retry="refresh" robots="noindex, follow" />
</template>
