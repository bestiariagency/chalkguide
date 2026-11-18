<script setup lang="ts">
/**
 * "Despublicar" confirmation, shared by the editor and the articles list. Names the object and the
 * consequence; `changes` > 0 adds that unpublished changes stay in the draft.
 */
defineProps<{ title: string; changes?: number; busy?: boolean }>()
const open = defineModel<boolean>('open', { default: false })
defineEmits<{ confirm: [] }>()
</script>

<template>
  <AdminConfirmDelete
    v-model:open="open"
    level="simple"
    :title="`¿Despublicar «${title || 'Sin título'}»?`"
    :description="changes ? 'El artículo dejará de verse en el sitio y pasará a borrador con los cambios que tenías sin publicar. Podrás volver a publicarlo cuando quieras.' : 'El artículo dejará de verse en el sitio y pasará a borrador. Podrás volver a publicarlo cuando quieras.'"
    confirm-label="Despublicar"
    :busy="busy"
    @confirm="$emit('confirm')"
  />
</template>
