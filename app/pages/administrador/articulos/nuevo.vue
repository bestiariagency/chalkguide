<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'

/** `/administrador/articulos/nuevo`: creates a minimal draft and replaces itself with its editor. */
definePageMeta({ layout: 'admin', i18n: false })
useAdminHead('Nuevo artículo')

const { create, busy } = useAdminArticles()
const title = useRoute().query.titulo
const failed = ref(false)
async function start() {
  failed.value = false
  failed.value = !(await create({ replace: true, title: typeof title === 'string' ? title : undefined }))
}
onMounted(start)
</script>

<template>
  <div class="px-4 py-6 md:px-6">
    <AdminStateBlock v-if="failed" kind="error" title="No se ha podido crear el borrador" description="Comprueba que existe al menos una categoría e inténtalo de nuevo." @retry="start" />
    <p v-else class="flex items-center gap-2 text-sm text-adm-meta" role="status" :aria-busy="busy">
      <Loader2 class="size-4 animate-adm-spin" aria-hidden="true" />Creando el borrador…
    </p>
  </div>
</template>
