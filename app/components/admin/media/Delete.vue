<script setup lang="ts">
import { usageToAdmin, type AdminMediaItem, type MediaUsageRow } from '~/utils/admin-media-library'

/** Delete: blocked while the file is in use (lists where, offers to replace it instead), simple otherwise. */
const props = defineProps<{ media: AdminMediaItem; usage: readonly MediaUsageRow[]; busy: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: []; replace: [] }>()
const inUse = computed(() => props.usage.length > 0)
</script>

<template>
  <AdminConfirmDelete
    v-model:open="open"
    :level="inUse ? 'in-use' : 'simple'"
    :title="inUse ? `No se puede eliminar «${media.original_filename}»` : `¿Eliminar «${media.original_filename}»?`"
    :description="inUse ? `Está en uso en ${usage.length} ${usage.length === 1 ? 'sitio' : 'sitios'}. Quítala de ahí primero o reemplaza el archivo en su lugar.` : 'Se borran el archivo y sus textos (alternativo, pie y crédito). No se puede deshacer.'"
    confirm-label="Eliminar imagen"
    alternative-label="Reemplazar archivo en su lugar"
    :usages="usage.map(usageToAdmin)"
    :busy="busy"
    stacked
    @confirm="emit('confirm')"
    @alternative="emit('replace')"
  />
</template>
