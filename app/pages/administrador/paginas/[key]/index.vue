<script setup lang="ts">
import { isPageKey } from '~/utils/admin-pages'

/** `/administrador/paginas/[key]` (F6.13, D34): editor of one of the five fixed pages. */
definePageMeta({ layout: 'admin', i18n: false, adminEditor: true })
const key = computed(() => String(useRoute().params.key))
</script>

<template>
  <AdminPagesEditor v-if="isPageKey(key)" :key="key" :page-key="key" />
  <div v-else class="px-4 py-6 md:px-6">
    <AdminStateBlock kind="empty" title="Esta página no existe" description="Las páginas fijas son: Sobre mí, Transparencia, Aviso legal, Privacidad y Cookies.">
      <NuxtLink :to="adminPath('paginas')" :class="admBtnGhost">Volver a páginas</NuxtLink>
    </AdminStateBlock>
  </div>
</template>
