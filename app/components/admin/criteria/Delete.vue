<script setup lang="ts">
import type { AdminCriterion } from '~/utils/admin-criteria'

/** Delete (only reachable without any note: the button of the drawer is disabled otherwise). */
defineProps<{ criterion: AdminCriterion; categoryLabel: string; busy: boolean; stacked?: boolean }>()
const open = defineModel<boolean>('open', { default: true })
const emit = defineEmits<{ confirm: [] }>()
</script>

<template>
  <AdminConfirmDelete
    v-model:open="open"
    level="simple"
    :stacked="stacked"
    :title="`¿Eliminar «${criterion.name_es}»?`"
    :description="`No tiene notas guardadas, así que no cambia ninguna media. Se quita de ${categoryLabel} y la clave «${criterion.key}» queda libre.`"
    confirm-label="Eliminar criterio"
    :busy="busy"
    @confirm="emit('confirm')"
  />
</template>
