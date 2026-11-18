<script setup lang="ts">
const { t } = useI18n()
const { page, error, refresh } = await useEditorialPage('privacy')
</script>

<template>
  <PageEditorial :page="page" :title="t('footer.privacy')" :error="error" :on-retry="refresh" robots="noindex, follow" />
</template>
