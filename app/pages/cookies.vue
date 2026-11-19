<script setup lang="ts">
const { t } = useI18n()
const { page, error, refresh } = await useEditorialPage('cookies')
</script>

<template>
  <PageEditorial :page="page" :title="t('footer.cookies')" :error="error" :on-retry="refresh" robots="noindex, follow">
    <template #before><CookiesChoice /></template>
  </PageEditorial>
</template>
