<script setup lang="ts">
import { Loader2 } from 'lucide-vue-next'
import type { ItemInfo } from '~/utils/item-spec'

/** Creates a minimal unpublished item and replaces this page with its editor. */
const props = defineProps<{ info: ItemInfo }>()
const { create, busy } = useAdminItems(props.info)
const failed = ref(false)
async function start() {
  failed.value = false
  failed.value = !(await create({ replace: true }))
}
onMounted(start)
</script>

<template>
  <div class="px-4 py-6 md:px-6">
    <AdminStateBlock v-if="failed" kind="error" title="No se ha podido crear la ficha" description="Inténtalo de nuevo; si sigue fallando, mira el estado de Supabase." @retry="start" />
    <p v-else class="flex items-center gap-2 text-sm text-adm-meta" role="status" :aria-busy="busy">
      <Loader2 class="size-4 animate-adm-spin" aria-hidden="true" />Creando la ficha…
    </p>
  </div>
</template>
