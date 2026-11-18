<script setup lang="ts">
import { Download } from 'lucide-vue-next'
import type { ExportInitial, ExportTarget } from '~/utils/admin-export'

/**
 * «Exportar» button of a listing plus its modal (F6.15). `?exportar=1` (⌘K command) opens it and is cleaned from the URL.
 * `initial` is read when the modal opens: the status and filters of the view at that moment.
 */
defineProps<{ target: ExportTarget; initial?: ExportInitial; categoryOptions?: readonly AdminOption[] }>()
const open = ref(false)
const trigger = ref<HTMLButtonElement>()
const route = useRoute()
const { setQuery } = useAdminUrlQuery()

watch(
  () => route.query.exportar,
  (flag) => {
    if (flag !== '1') return
    open.value = true
    void setQuery({ exportar: undefined })
  },
  { immediate: true },
)
watch(open, (value) => {
  if (!value) void nextTick(() => trigger.value?.focus())
})
</script>

<template>
  <button ref="trigger" type="button" :class="[admBtnGhost, 'max-sm:w-11 max-sm:px-0']" aria-label="Exportar" aria-haspopup="dialog" @click="open = true">
    <Download aria-hidden="true" /><span class="max-sm:hidden">Exportar</span>
  </button>
  <AdminExportsModal v-if="open" v-model:open="open" :target="target" :initial="initial" :category-options="categoryOptions" />
</template>
